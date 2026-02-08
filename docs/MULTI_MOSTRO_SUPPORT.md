# Multi-Mostro Instance Support

## Overview

Multi-Mostro support allows users to connect to multiple Mostro instances (nodes) from a single app installation. Users can switch between trusted (hardcoded) and custom (user-added) nodes, each with their own order books and trading sessions.

### Relay Management Per Node

Relay lists are **not** stored per-node. Instead, the existing relay system handles this automatically:

- When the active node changes via `SettingsNotifier.updateMostroInstance()`, blacklisted relays and user relays are reset
- `RelaysNotifier` subscribes to the active node's kind 10002 events and syncs relay lists in real-time
- Default relays from `Config.nostrRelays` serve as fallback for any node
- This means relay state is always derived from the currently active node, not stored alongside it

## Architecture

### Core Concept

The app maintains a registry of known Mostro nodes. Each node is identified by its Nostr public key (hex). Nodes are categorized as:

- **Trusted nodes**: Hardcoded in `Config.trustedMostroNodes`, cannot be removed
- **Custom nodes**: Added by users, persisted in SharedPreferences, can be removed

The existing `Settings.mostroPublicKey` field remains the single source of truth for which node is currently active. All downstream systems (relay sync, subscriptions, order management) already react to changes in this field via Riverpod.

### Data Flow

```
Config.trustedMostroNodes ──┐
                             ├──▶ MostroNodesNotifier ──▶ UI (Node Selector)
SharedPreferences (custom) ──┘           │
                                         │ selectNode()
                                         ▼
                               SettingsNotifier.updateMostroInstance()
                                         │
                                         ▼
                               Settings.mostroPublicKey changes
                                         │
                              ┌──────────┼──────────┐
                              ▼          ▼          ▼
                         RelaysNotifier  NostrService  SubscriptionManager
                         (relay sync)   (reconnect)    (resubscribe)
```

## Implementation Phases

### Phase 1: Data Model, Trusted Nodes Registry + Documentation

**Goal**: Establish the data layer for managing multiple Mostro nodes.

**Files Created**:
- `lib/features/mostro/mostro_node.dart` — MostroNode model with JSON serialization
- `lib/features/mostro/mostro_nodes_notifier.dart` — StateNotifier managing trusted + custom nodes
- `lib/features/mostro/mostro_nodes_provider.dart` — Riverpod provider
- `test/features/mostro/mostro_node_test.dart` — Model serialization tests
- `test/features/mostro/mostro_nodes_notifier_test.dart` — Notifier CRUD + backward compat tests
- `docs/MULTI_MOSTRO_SUPPORT.md` — This document

**Files Modified**:
- `lib/core/config.dart` — Add `trustedMostroNodes` list constant
- `lib/data/models/enums/storage_keys.dart` — Add `mostroCustomNodes` enum value (stored as `mostro_custom_nodes`)
- `lib/shared/providers/app_init_provider.dart` — Initialize `MostroNodesNotifier` during startup

**Key Decisions**:
- `MostroNode` equality based on `pubkey` only
- Custom nodes stored in `SharedPreferencesKeys.mostroCustomNodes` (separate from settings)
- Backward compatibility: unrecognized `mostroPublicKey` auto-imported as custom node (only if valid 64-char hex)
- Pubkey validation: `addCustomNode` rejects pubkeys that don't match 64-char hex regex (`^[0-9a-fA-F]{64}$`)
- Resilient error handling: both `_loadCustomNodes` and `_saveCustomNodes` catch errors and log without rethrowing, preventing app crashes on persistence failures
- Persist-before-state pattern: write operations (`addCustomNode`, `removeCustomNode`, `updateCustomNodeName`) only update in-memory state after successful disk save, preventing memory/disk divergence
- No changes to `Settings`, `SettingsNotifier`, or `NostrService`

**Test Coverage** (22 tests):
- `mostro_node_test.dart` (14 tests): Serialization round-trips, optional field handling, `displayName`/`truncatedPubkey`, `withMetadata` copy semantics, pubkey-based equality/hashCode, `toJson`/`fromJson`
- `mostro_nodes_notifier_test.dart` (18 tests): Init with trusted/custom/merged nodes, auto-import of unrecognized pubkeys (valid and invalid), `selectedNode` lookup, CRUD operations (`addCustomNode` with validation/duplicates/persistence, `removeCustomNode` with guards, `updateCustomNodeName`), metadata updates, `isTrustedNode` queries, corrupt SharedPreferences handling, `selectNode` delegation

### Phase 2: Kind 0 Metadata Fetching

**Goal**: Fetch and display Nostr profile metadata (name, picture, about) for each node.

**Files Created**:
- `lib/features/mostro/mostro_metadata_provider.dart` — Fire-and-forget metadata fetcher

**Files Modified**:
- `lib/services/nostr_service.dart` — Add `fetchKind0Metadata(pubkey)` method
- `lib/shared/providers/app_init_provider.dart` — Trigger metadata fetch after init

**Key Decisions**:
- Metadata fetched asynchronously, never blocks app startup
- Errors logged but never propagated
- Both batch fetch (all nodes) and per-node refresh providers
- Metadata stored in-memory on `MostroNode` objects (not persisted)

### Phase 3: UI — Node Selector + Add Custom Node

**Goal**: Allow users to browse, select, and manage Mostro nodes from the UI.

**Files Created**:
- `lib/features/mostro/widgets/mostro_node_selector.dart` — Node selection bottom sheet
- `lib/features/mostro/widgets/add_custom_node_dialog.dart` — Dialog to add custom nodes

**Files Modified**:
- `lib/features/settings/settings_screen.dart` — Replace pubkey text field with node selector
- `lib/l10n/intl_en.arb` — English localization keys
- `lib/l10n/intl_es.arb` — Spanish localization keys
- `lib/l10n/intl_it.arb` — Italian localization keys

**Key Decisions**:
- Bottom sheet for node selection (consistent with relay selector pattern)
- Trusted nodes shown with badge/indicator
- Custom nodes show delete option (if not currently active)
- Node avatar shows `picture` from kind 0 metadata when available
- Validate custom node pubkey format (64 hex chars) in the Add Custom Node dialog
- Debounce node switching to prevent race conditions during rapid selection changes

### Phase 4: Integration Testing

**Goal**: Verify end-to-end flows for node switching and management.

**Files Created**:
- `test/features/mostro/mostro_integration_test.dart` — Integration tests

**Test Scenarios**:
- Switch between trusted nodes
- Add and select a custom node
- Remove a custom node
- Backward compatibility (unrecognized pubkey auto-import)
- Relay reconnection after node switch
- Settings persistence across app restart

### Phase 5: Polish + Edge Cases

**Goal**: Handle edge cases, improve UX, and finalize documentation.

**Work Items**:
- Handle offline metadata fetch gracefully
- Add loading indicators during node switch
- Update CLAUDE.md with multi-Mostro architecture notes
- Performance testing with many custom nodes

## Model Reference

### MostroNode

```dart
class MostroNode {
  final String pubkey;       // Nostr hex public key (node identity)
  String? name;              // From kind 0 or user-provided
  String? picture;           // From kind 0 metadata
  String? website;           // From kind 0 metadata
  String? about;             // From kind 0 metadata
  final bool isTrusted;      // true = hardcoded, false = custom
  final DateTime? addedAt;   // null for trusted, timestamp for custom
}
```

### MostroNodesNotifier API

```dart
// Lifecycle
Future<void> init();                                        // Load trusted + custom nodes, auto-import unrecognized pubkey

// Selection
MostroNode? get selectedNode;                               // Currently active node based on settings
Future<void> selectNode(String pubkey);                     // Switch active node via SettingsNotifier

// CRUD (custom nodes only)
Future<bool> addCustomNode(String pubkey, {String? name});  // Add with validation (64-hex, no duplicates)
Future<bool> removeCustomNode(String pubkey);               // Remove non-active, non-trusted node
Future<bool> updateCustomNodeName(String pubkey, String newName); // Rename custom node

// Metadata (in-memory only, for kind 0 data)
void updateNodeMetadata(String pubkey, {String? name, ...});

// Queries
bool isTrustedNode(String pubkey);
List<MostroNode> get trustedNodes;
List<MostroNode> get customNodes;
```

All write operations return `false` on persistence failure without updating in-memory state.

### Storage

| Data | Storage Location | Key |
|------|-----------------|-----|
| Trusted nodes | `Config.trustedMostroNodes` (hardcoded) | N/A |
| Custom nodes | SharedPreferences | `mostro_custom_nodes` |
| Active node | Settings (SharedPreferences) | `mostroPublicKey` |
| Node metadata | In-memory only | N/A |

## Error Handling Strategy

The notifier uses a **resilient approach** — persistence failures are logged but never crash the app:

| Method | On error | Behavior |
|--------|----------|----------|
| `_loadCustomNodes()` | Returns `[]` | Callers silently degrade to trusted-only nodes |
| `_saveCustomNodes()` | Returns `false` | Callers check result before updating state |
| `addCustomNode()` | Returns `false` | Node not added to memory if disk save fails |
| `removeCustomNode()` | Returns `false` | Node stays in memory if disk save fails |
| `updateCustomNodeName()` | Returns `false` | Name unchanged in memory if disk save fails |
| `init()` auto-import save | Ignored | Imported node appears in memory for current session but won't persist |

This ensures in-memory state never diverges from disk state during write operations, while keeping the app functional even when SharedPreferences fails.

## Backward Compatibility

The implementation maintains full backward compatibility:

1. **Existing users**: Their saved `mostroPublicKey` continues to work. If it matches a trusted node, it's recognized automatically. If it's a valid 64-character hex key that doesn't match any trusted node, it's auto-imported as a custom node. Malformed or corrupted pubkeys are silently skipped.
2. **Environment variable**: `MOSTRO_PUB_KEY` environment variable override continues to work via `Config.mostroPubKey`.
3. **No migration needed**: The system is additive — no existing data is modified or removed.
4. **Settings model unchanged**: `Settings.mostroPublicKey` remains the single source of truth for the active node.
