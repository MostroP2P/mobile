# dart_nostr Upgrade: Parallel Relay Connections with Per-Relay Timeout

## Table of Contents

1. [Overview](#1-overview)
2. [The Problem: Relay Connection Blocking Bug](#2-the-problem-relay-connection-blocking-bug)
3. [The Fix: PR #19 to dart_nostr](#3-the-fix-pr-19-to-dart_nostr)
4. [Upgrade Strategy](#4-upgrade-strategy)
5. [Dependency Impact Analysis](#5-dependency-impact-analysis)
6. [All Changes Between 9.1.1 and Main](#6-all-changes-between-911-and-main)
7. [Risk Assessment Summary](#7-risk-assessment-summary)
8. [Implementation](#8-implementation)
9. [Reverting to pub.dev](#9-reverting-to-pubdev)

**Status:** In progress  
**Date:** April 2026  
**Branch:** `feat/upgrade-dart-nostr-parallel-relay-connections`  
**Related:** [RELAY_CONNECTION_BLOCKING_BUG.md](RELAY_CONNECTION_BLOCKING_BUG.md) — full root cause analysis  
**Upstream PR:** https://github.com/anasfik/nostr/pull/19  
**Note:** File and line number references throughout this document are accurate as of the branch and date listed above. Line numbers may shift as the code evolves.

---

## 1. Overview

This document describes the upgrade of `dart_nostr` from version 9.1.1 (pub.dev) to the current `main` branch of https://github.com/anasfik/nostr, which includes a critical fix for the relay connection blocking bug.

The fix (PR #19) was authored by this project's contributor and merged on March 31, 2026. However, no new version has been published to pub.dev since 9.2.5 (February 2026), so the fix is only available via git dependency.

A thorough analysis of all changes between 9.1.1 and current `main` was conducted to evaluate upgrade safety. The conclusion is that **all changes are safe** — no breaking changes affect the app, and several bonus bug fixes are included.

---

## 2. The Problem: Relay Connection Blocking Bug

Full root cause analysis is documented in [RELAY_CONNECTION_BLOCKING_BUG.md](RELAY_CONNECTION_BLOCKING_BUG.md). Summary:

When one or more configured relays are unreachable, the app hangs for **60-120 seconds per dead relay** during startup and every subsequent operation (order loading, event publishing, subscriptions).

### Root Causes (all inside dart_nostr)

1. **Sequential relay connection** — `_startConnectingAndRegisteringRelays()` uses a `for` + `await` loop. One dead relay blocks all subsequent relays from connecting.

2. **Connection timeout is dead code** — The `connectionTimeout` parameter passed to `init()` never reaches the WebSocket layer. The `_connectionTimeout` field (default 5s) in `NostrWebSocketsService` exists but is never used. `connectRelay()` calls `WebSocketChannel.connect()` (no timeout) instead of `IOWebSocketChannel.connect()` (which supports `connectTimeout`).

3. **App init blocks on relay connection** — `appInitializerProvider` awaits `NostrService.init()` before rendering the UI.

4. **Every operation re-triggers init()** — `_registerNewRelays()` calls `init()` before every send/fetch/subscribe, re-triggering the sequential loop on dead relays.

5. **Single timeout for all operations** — A single 30s value is shared for connection, EOSE, and publish, but it only works for EOSE/publish (the connection path is dead code).

### User Impact

| Scenario | Dead Relays | Blocking Time |
|----------|:-----------:|:-------------:|
| All healthy | 0 | ~1.5s |
| 1 dead relay | 1 | **60-120s** |
| 2 dead relays | 2 | **120-240s** |
| 3 dead relays | 3 | **180-360s** |

---

## 3. The Fix: PR #19 to dart_nostr

**PR:** https://github.com/anasfik/nostr/pull/19  
**Author:** Catrya  
**Merged:** March 31, 2026  
**Commit:** `2d87a57` (merge commit: `ca07ddd`)

### Changes Made

#### 3.1 Per-Relay Connection Timeout (web_sockets.dart)

**Import change:**
```dart
// BEFORE:
import 'package:web_socket_channel/web_socket_channel.dart';

// AFTER:
import 'package:web_socket_channel/io.dart';
```

**Connection change:**
```dart
// BEFORE: No timeout — falls back to OS TCP timeout (60-120s)
webSocket = WebSocketChannel.connect(
  Uri.parse(relay),
);

// AFTER: Per-relay timeout via connectTimeout parameter (default 5s)
webSocket = IOWebSocketChannel.connect(
  relay,
  connectTimeout: connectTimeout ?? _connectionTimeout,
);
```

This activates the `_connectionTimeout` field (default 5s) that already existed in the class but was never used.

#### 3.2 Parallel Relay Connections (relays.dart)

**Connection loop change:**
```dart
// BEFORE: Sequential — one dead relay blocks all others
for (final relay in relaysUrl) {
  await webSocketsService.connectRelay(relay: relay, ...);
}

// AFTER: Parallel — all relays connect simultaneously
await Future.wait(
  relaysToConnect.map((relay) async {
    await webSocketsService.connectRelay(
      relay: relay,
      connectTimeout: connectionTimeout,
      ...
    );
  }),
  eagerError: false,
);
```

The same parallel pattern was applied to `reconnectToRelays()`.

### Results

| Scenario | Before | After |
|----------|:------:|:-----:|
| 5 relays, all healthy | ~2.5s | ~2.5s |
| 5 relays, 1 dead (first) | **60-120s** | **~5.5s** |
| 5 relays, 2 dead | **120-240s** | **~6s** |
| Subsequent operations (1 dead) | **60-120s** | **~5.5s** |

Dead relay timeout reduced from 60-120s (OS TCP) to 5s (application-level). Parallel connections mean total time = max(individual) instead of sum(individual).

---

## 4. Upgrade Strategy

### Why Not Wait for pub.dev Release

- Last pub.dev release (9.2.5) was February 9, 2026
- The maintainer (anasfik) is responsive but publishes sporadically — months between releases
- The relay blocking bug critically affects user experience
- No timeline for next release

### Why Not Fork

- Adds maintenance overhead (syncing with upstream)
- The fix is already merged to the official repo
- A git dependency with pinned commit is cleaner and easier to revert

### Chosen Approach: Git Dependency with Pinned Commit

```yaml
dart_nostr:
  git:
    url: https://github.com/anasfik/nostr.git
    ref: ca07ddd  # Merge commit of PR #19
```

This is standard Dart/Flutter practice. The pinned commit ensures reproducible builds regardless of future changes to `main`.

---

## 5. Dependency Impact Analysis

Upgrading from dart_nostr 9.1.1 to main changes two transitive dependencies:

### 5.1 bip340: ^0.2.0 → ^0.3.0 (via dependency_override removal)

> The app overrides bip340 to `^0.2.0` in pubspec.yaml (to fix the `bigToBytes` padding bug in 0.1.0). dart_nostr 9.1.1 declares `bip340: ^0.1.0` upstream, but the effective version the app runs is 0.2.0. With dart_nostr main depending on `bip340: ^0.3.0`, the real upgrade from the app's perspective is 0.2.0 → 0.3.0.

#### What Changed in bip340

| Version | Key Changes |
|---------|-------------|
| 0.1.0 | Original — `bigToBytes()` padding bug (produces 31-byte values for ~1/256 keys) |
| 0.2.0 | `bigToBytes()` fix (`padLeft(64, "0")`), variable-length message support |
| 0.3.0 | `verify(String?)` → `verify(String)`, custom lowercase-only hex codec, new `verifyWithPoint()` |
| 0.3.1 | Dart 3 SDK support, dependency bumps (no API changes) |

#### Risk Analysis

**1. `verify()` nullability change (`String?` → `String`)**

dart_nostr `main` updated `NostrKeyPairs.verify()` to match:
```dart
// 9.1.1: static bool verify(String? pubkey, ...) — accepted nullable
// main:  static bool verify(String pubkey, ...)  — requires non-null
```

The app never passes null — all call sites provide `String` (non-nullable):
- `nostr_utils.dart:87` → `publicKey: publicKey` (typed `String`)
- `mostro_service_test.dart:179` → `NostrKeyPairs.verify(userPubKey, ...)` (typed `String`)

**Result: No impact.**

**2. Lowercase hex requirement**

bip340 0.3.x uses a custom hex codec that only accepts lowercase. Analysis of all hex sources in the app:
- `hex.encode()` (Dart `package:convert`) → always lowercase
- `toRadixString(16)` → always lowercase
- Nostr protocol (NIP-01) specifies lowercase hex for pubkeys, event IDs, signatures
- `bip340.getPublicKey()` and `bip340.sign()` return lowercase

**Result: No impact.** All hex in the pipeline is already lowercase.

**3. `verifyWithPoint()` new function**

Additive — new optimization function. Does not affect existing code.

**Result: No impact.**

**4. Removal of bip340 dependency_override**

The app currently has:
```yaml
dependency_overrides:
  bip340: ^0.2.0
```

This was needed because dart_nostr 9.1.1 depends on `bip340: ^0.1.0` (buggy). With dart_nostr main depending on `bip340: ^0.3.0`, the override is no longer necessary — the padding fix from 0.2.0 is preserved in 0.3.x.

**Result: Beneficial — cleaner pubspec.yaml.**

### 5.2 web_socket_channel: ^2.4.0 → ^3.0.3

#### What Changed in web_socket_channel 3.0.0

| Change | Description |
|--------|-------------|
| `WebSocketChannel` → `abstract interface class` | Cannot instantiate directly (use `AdapterWebSocketChannel`) |
| `WebSocketSink` → `abstract interface class` | Same pattern |
| `.ready` throws `WebSocketChannelException` | Instead of raw `WebSocketException` (except `TimeoutException` preserved) |

#### Risk Analysis

**1. The app does NOT import web_socket_channel directly**

Verified: zero imports of `web_socket_channel` in `lib/`, `test/`, or `integration_test/`. The package is purely transitive through dart_nostr.

**2. No other package depends on web_socket_channel**

Checked all 239 packages in `pubspec.lock`. dart_nostr is the only dependency that pulls in web_socket_channel. No version conflicts possible.

**3. Exception type change**

All error handling in `nostr_service.dart` uses generic `catch (e)` blocks — never catches `WebSocketException` specifically.

**4. `IOWebSocketChannel.connect()` signature unchanged**

The `connectTimeout` parameter that the fix uses works identically in 3.x.

**Result: No impact.**

---

## 6. All Changes Between 9.1.1 and Main

### 6.1 Commit History

| Version | Commit | Author | Change | Risk |
|---------|--------|--------|--------|:----:|
| 9.1.1 | `7b2a795` | gasaichandesu | NIP-05 nullable returns | None |
| — | `c60a4a3` | anasfik | Version/changelog bump | None |
| — | `34b2789` | chebizarro | Fix null type cast (`created_at`) | Beneficial |
| 9.2.1 | `cffd1ba` | anasfik | Broadcasting API (new methods) | None (additive) |
| 9.2.3 | `75e98fd` | gasaichandesu | SDK constraints, deps upgrade | None |
| 9.2.4 | `ea7b809` | anasfik | SHA256 hashing in `NostrKeys.sign()` | See below |
| 9.2.5 | `c76d439` | anasfik | Version bump, README | None |
| post-9.2.5 | `d7b8592` | gasaichandesu | subscriptionId null fix | Beneficial |
| post-9.2.5 | `332874f` | anasfik | Test coverage | None |
| post-9.2.5 | `7b573d3`–`1122558` | anasfik | Docs, roadmap, builder pattern | None (additive) |
| post-9.2.5 | `d5dc4d6` | anasfik | Builder pattern, retry policy, defaults | None (additive) |
| post-9.2.5 | `2d87a57` | Catrya | **Parallel relay connections + timeout fix** | **The fix we need** |
| post-9.2.5 | `ca07ddd` | anasfik | Merge of PR #19 | — |

### 6.2 SHA256 Signing Change (9.2.4) — Detailed Analysis

This was the most concerning change. The high-level wrapper `NostrKeys.sign()` changed from hex-encoding the message to SHA256-hashing it before signing:

```dart
// BEFORE (9.1.1):
final hexEncodedMessage = utils.hexEncodeString(message);
signature = nostrKeyPairs.sign(hexEncodedMessage);

// AFTER (9.2.4):
final messageHash = utils.sha256Hash(message);
signature = nostrKeyPairs.sign(messageHash);
```

**Critical distinction: two levels of signing API**

| API | Level | Changed? |
|-----|-------|:--------:|
| `NostrKeyPairs.sign(message)` | Low-level (calls `bip340.sign()` directly) | **No** |
| `Nostr.instance.services.keys.sign()` / `NostrKeys.sign()` | High-level wrapper | **Yes** |

**App signing call sites:**

| Location | What API It Uses | Affected? |
|----------|-----------------|:---------:|
| `MostroMessage.sign()` (mostro_message.dart:111) | `keyPair.sign(hash)` → `NostrKeyPairs.sign()` | **No** |
| PoW mining (nostr_utils.dart:619) | `keyPairs.sign(minedId)` → `NostrKeyPairs.sign()` | **No** |
| Event signing (`NostrEvent.fromPartialData()`) | Internal → `NostrKeyPairs.sign(id)` | **No** |
| `NostrUtils.signMessage()` (nostr_utils.dart:75) | `_instance.services.keys.sign()` → `NostrKeys.sign()` | **Yes, but never called** |
| `NostrUtils.verifySignature()` (nostr_utils.dart:82) | `_instance.services.keys.verify()` → `NostrKeys.verify()` | **Yes, but never called** |

All critical signing paths go through `NostrKeyPairs.sign()` (unchanged). The high-level `NostrKeys.sign()` that changed is wrapped by `NostrUtils.signMessage()` and `NostrUtils.verifySignature()`, which are **defined but never called** anywhere in the codebase.

**Result: No impact.** No double hashing. No signature incompatibility.

### 6.3 Builder Pattern, Retry Policy, Defaults (post-9.2.5)

New classes added:
- `NostrDefaults` — hardcoded default relays, timeouts, limits
- `NostrRetryPolicy` — configurable retry with backoff
- `NostrFilterBuilder` — fluent builder for `NostrFilter`
- Convenience methods on `Nostr` class (`subscribe()`, `filterBuilder()`)

All additive. No changes to existing methods or behavior. The defaults are only used if explicitly invoked via the new API.

**Result: No impact.**

### 6.4 subscriptionId Null Fix (post-9.2.5)

Bug: `request.serialized()` used the local `subscriptionId` parameter (null) instead of `this.subscriptionId` (resolved value) in the JSON encoding. This caused `["REQ", null, {...}]` to be sent to relays when `useConsistentSubscriptionIdBasedOnRequestData = true`.

The app uses the default (`false`), so the bug never manifests, but the fix is a free improvement.

**Result: Beneficial.**

### 6.5 Null Type Cast Fix (commit `34b2789`)

Fixes `"type 'Null' is not a subtype of type 'int' in type cast"` in event deserialization when `created_at` is null.

**Result: Beneficial — prevents potential crashes with malformed events.**

---

## 7. Risk Assessment Summary

| Change | Compilation Risk | Runtime Risk | Overall |
|--------|:----------------:|:------------:|:-------:|
| bip340 ^0.1.0 → ^0.3.0 | None | None | **Safe** |
| web_socket_channel ^2.4.0 → ^3.0.3 | None | None | **Safe** |
| SHA256 in NostrKeys.sign() | None | None (unused path) | **Safe** |
| Builder/retry/defaults | None | None (additive) | **Safe** |
| subscriptionId null fix | None | None (bonus fix) | **Safe** |
| Null type cast fix | None | None (bonus fix) | **Safe** |
| Parallel relay connections | None | None | **The fix we need** |
| Per-relay connection timeout | None | None | **The fix we need** |

**Conclusion: Zero identified risks. The upgrade is safe to proceed.**

---

## 8. Implementation

### pubspec.yaml Changes

```yaml
# BEFORE:
dependencies:
  dart_nostr: ^9.0.0

dependency_overrides:
  bip340: ^0.2.0

# AFTER:
dependencies:
  dart_nostr:
    git:
      url: https://github.com/anasfik/nostr.git
      ref: ca07ddd

# dependency_overrides section: remove bip340 override
```

### Config Timeout Split

```dart
// lib/core/config.dart
// BEFORE:
static const Duration nostrConnectionTimeout = Duration(seconds: 30);

// AFTER:
static const Duration relayConnectionTimeout = Duration(seconds: 5);
static const Duration nostrOperationTimeout = Duration(seconds: 20);
```

```dart
// lib/services/nostr_service.dart
// init():
connectionTimeout: Config.relayConnectionTimeout,   // 5s for WebSocket handshake

// publishEvent():
timeout: Config.nostrOperationTimeout,              // 20s for relay OK

// fetchEvents():
timeout: Config.nostrOperationTimeout,              // 20s for EOSE
```

**Note on timeout reduction:** This splits the original single `nostrConnectionTimeout` (30s) into two values: 5s for connection + 20s for operations. This intentionally reduces the operation timeout (publish/fetch) by 10 seconds compared to before. This is acceptable because: (1) the original 30s was designed to absorb slow relay connections, which are now capped at 5s per relay; (2) 20s is more than sufficient for EOSE and OK responses from healthy relays; (3) faster operation timeouts provide better UX when relays are genuinely unresponsive.

### Verification Steps

1. `flutter pub get` — resolve dependencies
2. `dart run build_runner build -d` — regenerate code
3. `flutter analyze` — zero issues
4. `flutter test` — all tests pass
5. Manual testing with a dead relay configured — verify 5s timeout instead of 60-120s

---

## 9. Reverting to pub.dev

When anasfik publishes a new version (e.g., 9.3.0) to pub.dev that includes the fix:

```yaml
# Simply replace the git dependency:
dart_nostr: ^9.3.0
```

No other changes needed. The git dependency is a temporary bridge until the upstream release.

---

## Appendix A: dart_nostr Version History

| Version | Date (pub.dev) | Key Changes |
|---------|:--------------:|-------------|
| 9.0.0 | — | Major structure changes |
| 9.1.0 | — | Content nullability fix, OK event data type fix |
| **9.1.1** | — | **Current app version.** NIP-05 nullable returns |
| 9.2.1 | — | Broadcasting API |
| 9.2.3 | — | SDK constraints, dependency upgrades |
| 9.2.4 | — | SHA256 message signing, `sha256Hash()` utility |
| **9.2.5** | 2026-02-09 | **Latest on pub.dev.** README improvements |
| post-9.2.5 | unreleased | subscriptionId fix, builder pattern, relay fix (PR #19) |

## Appendix B: bip340 Version History

| Version | Key Changes | API Compatible? |
|---------|-------------|:---------------:|
| 0.1.0 | Original — `bigToBytes()` padding bug | — |
| 0.2.0 | Padding fix, variable-length messages | Yes (with 0.1.0) |
| 0.3.0 | `verify(String)` non-null, lowercase hex codec, `verifyWithPoint()` | No* |
| 0.3.1 | Dart 3 support | Yes (with 0.3.0) |

\* The `verify()` nullability change is breaking in theory but not in practice — all callers already pass non-null values.

## Appendix C: Key File References

| File | Relevance |
|------|-----------|
| `pubspec.yaml` | dart_nostr dependency, bip340 override |
| `pubspec.lock` | Resolved versions |
| `lib/core/config.dart` | Timeout definitions |
| `lib/services/nostr_service.dart` | dart_nostr integration, timeout usage |
| `lib/shared/providers/app_init_provider.dart` | App init blocking on relay connection |
| `lib/shared/utils/nostr_utils.dart` | Signing wrappers (unused high-level path) |
| `lib/data/models/mostro_message.dart` | MostroMessage signing (low-level path) |
| `docs/architecture/RELAY_CONNECTION_BLOCKING_BUG.md` | Full root cause analysis |
