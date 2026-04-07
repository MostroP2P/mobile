# Community Discovery: Node Selector on First Launch

**Issue:** [#563](https://github.com/MostroP2P/mobile/issues/563)
**Reference:** [mostro.community](https://github.com/MostroP2P/community)

## Overview

Community Discovery allows new users to choose a trusted Mostro community/node on their first launch, before reaching the home screen. The feature mirrors the [mostro.community](https://mostro.community) website pattern: trusted node pubkeys are hardcoded, and community metadata (name, avatar, description, currencies, fee) is fetched from Nostr kind 0 and kind 38385 events.

Existing users are never interrupted. The selector is shown only once after the walkthrough.

## User Flow

### New User

```text
App install -> Walkthrough (complete or skip) -> Community Selector -> Home
```

### Existing User (upgrade)

```text
App launch -> Home (auto-migrated, no interruption)
```

### Returning to Community Selection

```text
Home -> Settings -> Mostro Card -> Node Selector (existing feature)
```

## Trusted Communities

Mirrored from [mostro.community](https://github.com/MostroP2P/community). Defined in `lib/core/config/communities.dart`:

| Region | Pubkey (truncated) | Social |
|--------|-------------------|--------|
| Cuba | `00000235a3e9...1366a` | [Telegram](https://t.me/Cuba_Bitcoin), [Website](https://cubabitcoin.org/kmbalache/) |
| Spain | `0000cc02101e...36b40` | [Telegram](https://t.me/nostromostro) |
| Colombia | `00000978acc5...8441b` | [Telegram](https://t.me/ColombiaP2P), [X](https://x.com/ColombiaP2P) |
| Bolivia | `00007cb3305f...3f91` | [Telegram](https://t.me/btcxbolivia), [X](https://x.com/btcxbolivia), [Instagram](https://www.instagram.com/btcxbolivia) |
| Default | `82fa8cb978b4...8390` | (fallback when user skips) |

**Single source of truth:** `Config.trustedMostroNodes` is derived from `trustedCommunities` at runtime, eliminating duplication between the node system and community config.

## Architecture

### Data Flow

```text
trustedCommunities (static config)
        |
        v
CommunityRepository.fetchCommunityMetadata(pubkeys)
        |   WebSocket -> Config.nostrRelays (with fallback)
        |   REQ kind 0 (profile: name, about, picture)
        |   REQ kind 38385 (trade info: currencies, fee, min/max)
        |   Timeout: 10s, partial data OK
        v
communityListProvider (FutureProvider)
        |   Merges static config + fetched metadata
        v
CommunitySelectorScreen
        |   User selects community -> selectNode() + markCommunitySelected()
        v
Home Screen
```

### Layer Responsibilities

| Layer | Component | Responsibility |
|-------|-----------|---------------|
| Config | `communities.dart` | `CommunityConfig`, `SocialLink`, `trustedCommunities`, `defaultMostroPubkey` |
| Data | `community_repository.dart` | `CommunityRepository` (WebSocket fetch), `CommunityMetadata` (parsed event data) |
| Domain | `community.dart` | `Community` model combining static config + dynamic metadata |
| State | `community_selector_provider.dart` | `communitySelectedProvider` (persistence), `communityRepositoryProvider` (DI), `communityListProvider` (fetch + enrich) |
| UI | `community_selector_screen.dart` | Full-screen selector with search, loading skeleton, error state |
| UI | `community_card.dart` | Card widget: avatar, name, region, about, currencies, fee/range, social links |

### File Structure

```text
lib/
  core/
    config/
      communities.dart              # Trusted pubkeys, SocialLink, CommunityConfig
    config.dart                      # Config.trustedMostroNodes (derived)
  data/
    models/enums/
      storage_keys.dart              # + communitySelected key
    repositories/
      community_repository.dart      # WebSocket fetcher + CommunityMetadata
  features/
    community/
      community.dart                 # Community model
      providers/
        community_selector_provider.dart  # Riverpod providers
      screens/
        community_selector_screen.dart    # Main screen
      widgets/
        community_card.dart               # Card widget
    walkthrough/
      screens/
        walkthrough_screen.dart      # Modified: navigates to /community_selector
```

## Nostr Event Fetching

### CommunityRepository

Located at `lib/data/repositories/community_repository.dart`. Uses a standalone `dart:io` WebSocket connection, independent of the app's `NostrService`, so it works before full app initialization.

**Connection:** `wss://relay.mostro.network`
**Timeout:** 10 seconds
**Error handling:** Errors propagate to `communityListProvider` which shows the error state with retry.

### Subscriptions

Two concurrent REQ messages on a single WebSocket:

```json
// Kind 0: Nostr profile metadata
["REQ", "<subId>", {"kinds": [0], "authors": ["<pubkey1>", "<pubkey2>", ...]}]

// Kind 38385: Mostro trade information
["REQ", "<subId>", {"kinds": [38385], "authors": ["<pubkey1>", ...], "#y": ["mostro"]}]
```

Waits for both EOSE responses (or timeout), then closes subscriptions and WebSocket.

### Event Deduplication

For both kinds, keeps only the event with the highest `created_at` per pubkey. This handles multiple relays returning the same event.

### Kind 0 Fields Extracted

| Field | JSON key | Usage |
|-------|----------|-------|
| Name | `name` | Display name (fallback: region from config) |
| About | `about` | Description text on card |
| Picture | `picture` | Avatar (HTTPS only, NymAvatar fallback) |

### Kind 38385 Tags Extracted

| Tag | Usage |
|-----|-------|
| `fiat_currencies_accepted` | Comma-separated currency codes displayed as tags |
| `fee` | Trading fee percentage |
| `min_order_amount` | Minimum order in sats |
| `max_order_amount` | Maximum order in sats |

### "All Currencies" Logic

When kind 38385 event exists (`hasTradeInfo = true`) but `fiat_currencies_accepted` is empty or absent, the card displays a localized "All currencies" tag. This mirrors the behavior of [mostro.community](https://mostro.community).

## Navigation Integration

### GoRouter Redirect Chain

In `lib/core/app_routes.dart`, the redirect logic evaluates two providers sequentially:

```text
1. firstRunProvider:
   - loading -> redirect to /walkthrough
   - data(isFirstRun=true) -> redirect to /walkthrough
   - data(isFirstRun=false) -> proceed to step 2

2. communitySelectedProvider:
   - loading -> no redirect (wait for provider to resolve; router refreshes on change)
   - data(false) -> redirect to /community_selector
   - data(true) -> no redirect (proceed to requested route)
   - error -> no redirect (don't block on errors)
```

### Route Definition

```dart
GoRoute(
  path: '/community_selector',
  pageBuilder: (context, state) => buildPageWithDefaultTransition<void>(
    context: context,
    state: state,
    child: const CommunitySelectorScreen(),
  ),
),
```

### Walkthrough Integration

`WalkthroughScreen._onIntroEnd()` navigates to `/community_selector` instead of `/`. The GoRouter redirect handles the rest.

## Backward Compatibility

### Existing Users Auto-Migration

`CommunitySelectedNotifier._init()` checks:

1. If `communitySelected` is already `true` in SharedPreferences -> done.
2. If `firstRunComplete` is `true` (existing user who completed onboarding before this feature) -> auto-sets `communitySelected = true` and skips the selector.
3. Otherwise -> `false` (new user, show selector).

This ensures users who upgrade from a version without community discovery are never interrupted.

### Config.trustedMostroNodes

Previously hardcoded as a single entry (`Mostro P2P`). Now derived from `trustedCommunities`, which contains all 5 community entries. The `MostroNodesNotifier` initializes from this list, so all communities appear as trusted nodes in the existing node selector (Settings -> Mostro).

## State Management

### communitySelectedProvider

`StateNotifierProvider<CommunitySelectedNotifier, AsyncValue<bool>>`

- **Storage:** `SharedPreferencesKeys.communitySelected` (`'community_selected'`)
- **Loading:** Reads SharedPreferences asynchronously
- **Mounted checks:** All async `state =` assignments guarded by `if (!mounted) return`
- **Methods:** `markCommunitySelected()` — persists selection and updates state

### communityListProvider

`FutureProvider<List<Community>>`

1. Creates `Community.fromConfig()` for each `trustedCommunities` entry
2. Calls `CommunityRepository.fetchCommunityMetadata()` with all pubkeys
3. Enriches communities with fetched metadata via `copyWith()`
4. Returns enriched list (partial data is fine — missing metadata fields stay null)

### communityRepositoryProvider

`Provider<CommunityRepository>` — simple factory for dependency injection.

## Community Selector Screen

### UI Layout

```text
+-----------------------------+
|  bolt  Choose your community |  <- Title with bolt icon
|  [search icon] Search...     |  <- Search bar (filters by name, region, currency, about)
|                               |
|  +-------------------------+  |
|  | Avatar  Name      check |  |  <- CommunityCard (selected state)
|  | Region                   |  |
|  | Description text...      |  |
|  | [USD] [EUR] [CUP]       |  |  <- Currency tags (or "All currencies")
|  | % Fee 1.0%  | Range ... |  |  <- Fee and sats range
|  | tg  x  ig               |  |  <- Social link icons
|  +-------------------------+  |
|  [more cards...]              |
|                               |
|  gear  Use a custom node      |  <- Opens AddCustomNodeDialog
|  [========= Done =========]  |  <- Confirm button (visible after selection)
|       Skip for now            |  <- Uses defaultMostroPubkey
+-----------------------------+
```

### States

| State | Behavior |
|-------|----------|
| **Loading** | Skeleton placeholders (same count as `trustedCommunities`) |
| **Error** | Cloud-off icon + error message + retry button (invalidates `communityListProvider`) |
| **Data (empty search)** | "No communities found" centered text |
| **Data** | Scrollable list of `CommunityCard` widgets |
| **Selecting** | Loading spinner on confirm button, all interactions disabled |

### User Actions

| Action | Behavior |
|--------|----------|
| **Tap card** | Sets `_selectedPubkey`, shows confirm button |
| **Confirm** | `_selectAndProceed()`: ensures node exists, selects it, marks community selected, navigates to `/` |
| **Skip** | Same as confirm but uses `defaultMostroPubkey` |
| **Use custom node** | Opens `AddCustomNodeDialog`; if a node was added (detected via set-diff on pubkeys), auto-selects it and proceeds |

### _selectAndProceed() Flow

```dart
1. _ensureNodeExists(pubkey)    // Adds as custom node if not already known (awaited)
2. nodesNotifier.selectNode()   // Calls settingsNotifier.updateMostroInstance()
3. markCommunitySelected()      // Persists to SharedPreferences
4. context.go('/')              // Navigate to home (if still mounted)
```

## CommunityCard Widget

`StatelessWidget` displaying a single community entry.

### Sections (conditional)

1. **Header:** Avatar (network image with NymAvatar fallback + loading placeholder) + display name + region + check icon (if selected)
2. **About:** Description text, max 3 lines with ellipsis
3. **Currencies:** Green tags showing accepted fiat codes, or "All currencies" if `hasTradeInfo && currencies.isEmpty`
4. **Stats:** Fee percentage + sats range (formatted as K/M)
5. **Social:** Tappable icons for Telegram, X, Instagram, etc.

### Visual Design

- Uses `AppTheme` constants consistently (backgroundCard, activeColor, textPrimary, textSecondary)
- `AnimatedContainer` with 200ms transition for selection state
- Selected state: green border (alpha 0.5) + green background tint (alpha 0.1) + check icon
- Currency tags: green background (alpha 0.15) + green text

## Internationalization

All user-facing strings use `S.of(context)!.keyName`. Keys added across all 5 locales:

| Key | EN | ES | IT | DE | FR |
|-----|----|----|----|----|-----|
| `chooseYourCommunity` | Choose your community | Elige tu comunidad | Scegli la tua comunita | Wahle deine Community | Choisissez votre communaute |
| `communitySearchHint` | Search communities... | Buscar comunidades... | Cerca comunita... | Communities suchen... | Rechercher des communautes... |
| `communityFee` | Fee | Comision | Commissione | Gebuhr | Frais |
| `communityRange` | Range | Rango | Intervallo | Bereich | Plage |
| `useCustomNode` | Use a custom node | Usar un nodo personalizado | Usa un nodo personalizzato | Eigenen Knoten verwenden | Utiliser un noeud personnalise |
| `communityLoadingError` | Could not load community data | No se pudieron cargar... | Impossibile caricare... | ...konnten nicht geladen werden | Impossible de charger... |
| `communityRetry` | Retry | Reintentar | Riprova | Erneut versuchen | Reessayer |
| `noCommunityResults` | No communities found | No se encontraron... | Nessuna comunita trovata | Keine Communities gefunden | Aucune communaute trouvee |
| `communityFormatSats` | {amount} sats | {amount} sats | {amount} sats | {amount} sats | {amount} sats |
| `communityAllCurrencies` | All currencies | Todas las monedas | Tutte le valute | Alle Wahrungen | Toutes les devises |

The existing `skipForNow` and `done` keys are reused from prior translations.

## Ancillary Changes

### Dependency Conflict Resolution

Removed `riverpod_generator` and `riverpod_annotation` dev dependencies that conflicted with Flutter 3.41.6's `analyzer` requirement. The 3 files using `@riverpod` annotations were converted to manual providers matching the rest of the codebase:

| File | Change |
|------|--------|
| `lib/services/event_bus.dart` | `@riverpod` -> `AutoDisposeProvider` |
| `lib/shared/providers/mostro_service_provider.dart` | `@Riverpod(keepAlive: true)` -> `Provider` |
| `lib/features/order/providers/order_notifier_provider.dart` | `@riverpod class OrderTypeNotifier` -> `StateNotifier` + `AutoDisposeStateNotifierProvider` |

### google_fonts Upgrade

Upgraded `google_fonts` from 6.2.1 to 6.3.3 (within existing `^6.2.1` constraint) to fix `FontWeight` constant evaluation error on Flutter 3.41.6.

### MostroService.init() Idempotency

Added `_ordersSubscription?.cancel()` at the start of `MostroService.init()` to prevent subscription leaks when called from `LifecycleManager.onResumed()`.

## Out of Scope (v1)

- Decentralized community discovery via NIP
- Real-time updates when community changes their kind 38385
- User-created communities (curated list only)
- Settings screen community section (uses existing Mostro node selector)
