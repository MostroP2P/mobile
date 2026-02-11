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

```text
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

### Phase 1: Data Model, Trusted Nodes Registry + Documentation — Completed

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

### Phase 2: Kind 0 Metadata Fetching — Completed

**Goal**: Fetch and display Nostr profile metadata (name, picture, about) for each node.

**Files Modified**:
- `lib/features/mostro/mostro_node.dart` — Added `MostroNode.clear` sentinel for explicit field clearing in `withMetadata()`
- `lib/features/mostro/mostro_nodes_notifier.dart` — Added `fetchAllNodeMetadata()`, `fetchNodeMetadata()`, `_applyMetadataFromEvent()`, `_sanitizeUrl()` methods
- `lib/shared/providers/app_init_provider.dart` — Fire-and-forget metadata fetch via `unawaited()` after `init()`
- `test/features/mostro/mostro_node_test.dart` — Added 1 test for `MostroNode.clear` sentinel
- `test/features/mostro/mostro_nodes_notifier_test.dart` — Added 11 metadata fetch tests

**Key Decisions**:
- **No changes to `NostrService`**: `fetchEvents(filter)` already handles one-shot fetching with timeout; no wrapper needed
- **Fetch logic in `MostroNodesNotifier`**: Keeps all node logic co-located; notifier has `_ref` to access `nostrServiceProvider`
- **Batch fetch**: Single `NostrFilter(kinds: [0], authors: allPubkeys)` request — one round trip instead of N
- **Deduplication**: Both `fetchAllNodeMetadata()` and `fetchNodeMetadata()` deduplicate across relays, keeping only the most recent event per pubkey (highest `createdAt`). `limit: 1` is a relay hint, not a guarantee, so single-node fetch also deduplicates
- **Signature verification**: `_applyMetadataFromEvent()` calls `event.isVerified()` before applying metadata; forged events with invalid signatures are logged and silently skipped
- **URL sanitization**: `picture` and `website` fields are validated via `_sanitizeUrl()` — only `https://` URLs pass through; `javascript:`, `http://`, `data:`, and other schemes are rejected (set to `null`)
- **Mounted guard**: Both fetch methods check `mounted` after the async `fetchEvents` gap to avoid setting state on a disposed notifier
- **In-memory only**: Metadata NOT persisted to disk; fetched fresh each app launch; `updateNodeMetadata()` updates state but doesn't call `_saveCustomNodes()`
- **Fire-and-forget**: Metadata fetch triggered after `init()` via `unawaited()` — doesn't block app startup; UI updates reactively when state changes
- **Resilient**: All errors caught and logged, never propagated; missing/malformed metadata silently skipped
- **Explicit field clearing**: `MostroNode.withMetadata()` supports a `MostroNode.clear` sentinel to explicitly set fields to `null`, while omitting a field preserves the existing value

**Test Coverage** (46 tests total across Phase 1 + Phase 2):
- `mostro_node_test.dart` (12 tests): Serialization round-trips, optional field handling, `displayName`, `withMetadata` copy semantics including `MostroNode.clear`, pubkey-based equality/hashCode, `toJson`/`fromJson`
- `mostro_nodes_notifier_test.dart` (34 tests): Phase 1 tests (23) + metadata fetching tests (11): batch fetch with kind 0 events, deduplication keeping latest, URL sanitization (rejects non-https, accepts https), empty event list handling, malformed JSON content, network error resilience, unverified event rejection, single-node fetch deduplication across relays, single-node fetch, non-map JSON content

### Phase 3: UI — Node Selector + Add Custom Node — Completed

**Goal**: Allow users to browse, select, and manage Mostro nodes from the UI.

**Files Created**:
- `lib/features/mostro/widgets/mostro_node_selector.dart` — Bottom sheet widget (`ConsumerStatefulWidget`) for browsing and selecting Mostro nodes. Shows trusted and custom node sections, avatar with kind 0 picture or `NymAvatar` fallback, trusted badge, checkmark for active node, delete for custom nodes, and "Add Custom Node" button. Uses `_isSwitching` flag to prevent rapid taps during node switch.
- `lib/features/mostro/widgets/add_custom_node_dialog.dart` — `AlertDialog` (via `StatefulBuilder`) for adding custom nodes. Accepts hex (64 chars) or npub1 format with auto-conversion via `NostrUtils.decodeBech32()`. Optional name field. Inline validation with duplicate check and format validation. Fire-and-forget metadata fetch after successful add.

**Files Modified**:
- `lib/features/settings/settings_screen.dart` — Replaced `_buildMostroCard` content: removed `TextEditingController`, debounce timer, `_pubkeyError`, `_isValidPubkey()`, and `_convertToHex()`. New card shows currently selected node with avatar, display name, truncated pubkey, trusted badge, and dropdown arrow. Tapping opens `MostroNodeSelector.show(context)`. Watches `mostroNodesProvider` for reactive updates.
- `lib/l10n/intl_en.arb` — Added 25 new localization keys for node selector UI
- `lib/l10n/intl_es.arb` — Spanish translations for all new keys
- `lib/l10n/intl_it.arb` — Italian translations for all new keys

**Key Decisions**:
- **Bottom sheet** for node selection (first bottom sheet in the app — new UX pattern via `showModalBottomSheet`)
- **`Image.network`** for node avatars with `NymAvatar` fallback — no new dependencies
- **Restore triggered** on node switch (consistent with previous text field behavior) — called in `MostroNodeSelector._onNodeTap()`
- **npub support** in Add Custom Node dialog — auto-converts to hex via `NostrUtils.decodeBech32()`
- **`_isSwitching` flag** prevents rapid taps: disables all list items and add button during switch, bottom sheet closes after completion
- **No metadata fetching in bottom sheet**: metadata is already fetched at app startup; new custom nodes get fire-and-forget metadata fetch after adding
- **Confirmation dialog** for custom node deletion (consistent with relay deletion pattern)
- **Cannot delete active node**: shows SnackBar message instead
- **Async-safe SnackBars**: captures `ScaffoldMessengerState` and `MediaQuery` values before async gaps

**Widget Structure**:
```
Settings Screen
  └── _buildMostroCard()
        └── InkWell → MostroNodeSelector.show()
              └── MostroNodeSelector (Bottom Sheet)
                    ├── Trusted Nodes Section
                    │     └── _buildNodeItem() × N
                    ├── Custom Nodes Section
                    │     └── _buildNodeItem() × N (or "No custom nodes" text)
                    └── "Add Custom Node" button
                          └── AddCustomNodeDialog.show()
```

**Localization Keys Added** (25 keys across 3 languages):
- `selectMostroNode`, `mostroNodeDescription`, `trustedNodesSection`, `customNodesSection`
- `addCustomNode`, `addCustomNodeTitle`, `enterNodePubkey`, `enterNodeName`
- `pubkeyHint`, `nodeNameHint`, `nodeAlreadyExists`, `invalidPubkeyFormat`
- `nodeAddedSuccess`, `nodeRemovedSuccess`, `cannotRemoveActiveNode`
- `deleteCustomNodeTitle`, `deleteCustomNodeMessage`, `deleteCustomNodeConfirm`, `deleteCustomNodeCancel`
- `switchingToNode` (parameterized), `nodeSwitchedSuccess` (parameterized)
- `trusted`, `noCustomNodesYet`, `pubkeyRequired`, `tapToSelectNode`

### Phase 4: Integration Testing — Completed

**Goal**: Verify cross-component end-to-end flows — how `MostroNodesNotifier` and `SettingsNotifier` work together for node switching, persistence round-trips, and relay-reset behavior.

**Files Created**:
- `test/features/mostro/mostro_integration_test.dart` — 23 integration tests in 7 groups

**Test Groups**:

| Group | Tests | What it verifies |
|-------|-------|-----------------|
| Node switching flows | 4 | Relay reset on switch, relay preservation on same-node select, unknown pubkey no-op |
| Custom node lifecycle | 4 | Add → select → verify, add → remove, active node removal rejection, duplicate rejection |
| Backward compatibility | 4 | Auto-import unrecognized pubkey, malformed pubkey ignored, trusted pubkey not duplicated, empty pubkey gives null selectedNode |
| Settings persistence across restart | 3 | Custom nodes survive restart, selectNode updates state, corrupt prefs handled |
| Relay reconnection after node switch | 4 | Blacklisted relays cleared, user relays cleared, main relays list preserved, same-node preserves relays |
| Pubkey case normalization | 2 | Verifies lowercase normalization in addCustomNode and selectNode |
| Multi-step end-to-end flows | 2 | Complex multi-node lifecycle with switching and removal, persistence round-trip across 3 sessions |

**Key Decisions**:
- **Unit-level integration tests**: Tests run in-process using real `MockSettingsNotifier` (extends `SettingsNotifier`) so `updateMostroInstance()` actually executes relay-reset logic, verifying the full `selectNode() → updateMostroInstance() → state.blacklistedRelays/userRelays cleared` chain
- **In-memory SharedPreferences**: `MockSharedPreferencesAsync` backed by a `Map<String, String>` enables persistence round-trip testing — add nodes in one notifier instance, verify they load in a fresh instance with the same backing store
- **Dynamic mock ref**: `when(mockRef.read(settingsProvider)).thenAnswer((_) => mockSettingsNotifier.state)` ensures `selectedNode` and `removeCustomNode` always see the latest settings state after `updateMostroInstance()` modifies it
- **No new mocks**: Reuses existing `MockSharedPreferencesAsync`, `MockRef`, and `MockSettingsNotifier` from `test/mocks.dart`

**Test Coverage Summary** (69 total across Phases 1-4):
- `mostro_node_test.dart`: 12 tests (model serialization, equality, metadata)
- `mostro_nodes_notifier_test.dart`: 34 tests (CRUD, backward compat, metadata fetching)
- `mostro_integration_test.dart`: 23 tests (cross-component flows, persistence, relay reset, edge cases)

### Phase 5: Polish + Edge Cases — Completed

**Goal**: Handle edge cases, improve UX, finalize documentation, and add performance stress tests.

**Work Items Analysis**:

| Work Item | Status | Notes |
|-----------|--------|-------|
| Handle offline metadata fetch gracefully | Done in Phase 3 | `MostroNodeAvatar` uses `Image.network` with loading spinner + `NymAvatar` fallback on error. `fetchAllNodeMetadata()` catches all errors and logs. Fire-and-forget at startup. |
| Add loading indicators during node switch | Done in Phase 3 | `_isSwitching` flag + per-node `CircularProgressIndicator` in `MostroNodeSelector`. Disables all interactions during switch. Error/revert handling with SnackBars. |
| Update CLAUDE.md with multi-Mostro architecture notes | Done in Phase 5 | Added "Multi-Mostro Instance Support" section under Architecture Overview |
| Performance testing with many custom nodes | Done in Phase 5 | 5 stress tests with 50 custom nodes |

**Files Created**:
- `test/features/mostro/mostro_nodes_performance_test.dart` — 5 performance/stress tests

**Files Modified**:
- `CLAUDE.md` — Added "Multi-Mostro Instance Support" subsection under Architecture Overview (10 bullet points covering node types, core files, UI components, kind 0 metadata, storage, node switching, backward compatibility, error resilience)
- `docs/MULTI_MOSTRO_SUPPORT.md` — This section (Phase 5 expanded and marked completed)

**Performance Test Details** (5 tests):

| Test | What it verifies |
|------|-----------------|
| Add 50 custom nodes and verify all persisted | All 50 added, state length = trusted + 50, persistence round-trip with fresh notifier |
| selectedNode lookup with last node in large list | Correct node returned when active node is the last in a list of 50+ |
| Remove node from middle of large list | List integrity after removing node 25/50, surrounding nodes intact, removal persisted |
| Batch metadata update for all nodes | `updateNodeMetadata()` for all 50+ nodes, all fields updated correctly |
| Init with 50 pre-existing nodes completes promptly | `init()` loads 50 nodes from storage in under 1 second |

**Test Coverage Summary** (74 total across Phases 1-5):
- `mostro_node_test.dart`: 12 tests (model serialization, equality, metadata)
- `mostro_nodes_notifier_test.dart`: 34 tests (CRUD, backward compat, metadata fetching)
- `mostro_integration_test.dart`: 23 tests (cross-component flows, persistence, relay reset, edge cases)
- `mostro_nodes_performance_test.dart`: 5 tests (stress testing with 50 custom nodes)

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
Future<void> fetchAllNodeMetadata();                        // Batch fetch kind 0 for all nodes (deduplicates, verifies, sanitizes)
Future<void> fetchNodeMetadata(String pubkey);              // Single-node kind 0 fetch (deduplicates, verifies, sanitizes)

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
