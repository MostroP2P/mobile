# Multi-Mostro Instance Support

## Overview

Multi-Mostro support allows users to connect to multiple Mostro instances (nodes) from a single app installation. Users can switch between trusted (hardcoded) and custom (user-added) nodes, each with their own relay lists, order books, and trading sessions.

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
- `lib/data/models/enums/storage_keys.dart` — Add `mostroCustomNodes` key
- `lib/shared/providers/app_init_provider.dart` — Initialize `MostroNodesNotifier` during startup

**Key Decisions**:
- `MostroNode` equality based on `pubkey` only
- Custom nodes stored in `SharedPreferencesKeys.mostroCustomNodes` (separate from settings)
- Backward compatibility: unrecognized `mostroPublicKey` auto-imported as custom node
- No changes to `Settings`, `SettingsNotifier`, or `NostrService`

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
- Validate custom node pubkey format (64 hex chars)
- Handle race conditions during rapid node switching
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

### Storage

| Data | Storage Location | Key |
|------|-----------------|-----|
| Trusted nodes | `Config.trustedMostroNodes` (hardcoded) | N/A |
| Custom nodes | SharedPreferences | `mostro_custom_nodes` |
| Active node | Settings (SharedPreferences) | `mostroPublicKey` |
| Node metadata | In-memory only | N/A |

## Backward Compatibility

The implementation maintains full backward compatibility:

1. **Existing users**: Their saved `mostroPublicKey` continues to work. If it matches a trusted node, it's recognized automatically. If not, it's auto-imported as a custom node.
2. **Environment variable**: `MOSTRO_PUB_KEY` environment variable override continues to work via `Config.mostroPubKey`.
3. **No migration needed**: The system is additive — no existing data is modified or removed.
4. **Settings model unchanged**: `Settings.mostroPublicKey` remains the single source of truth for the active node.
