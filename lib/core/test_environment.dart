import 'package:flutter/foundation.dart';

/// Mortsom test-environment switch (see `docs/automation-contract.md`).
///
/// The test environment is enabled only when BOTH conditions hold:
///  1. the app was started through the `lib/main_mortsom.dart` entry point,
///     which is the only caller of [arm]; and
///  2. the build carried `--dart-define=MORTSOM_TEST_ENV=true`.
///
/// The production entry point (`lib/main.dart`) never arms it and the
/// release pipeline never passes the define, so a release build cannot enter
/// the test environment by accident.
///
/// Values passed as Dart defines are visible to build tooling, so only
/// non-secret data travels this way: the daemon public key (already
/// `MOSTRO_PUB_KEY`) and the local relay seed list (`MORTSOM_RELAYS`).
/// Secrets such as mnemonics or NWC URIs are entered through the UI.
class TestEnvironment {
  TestEnvironment._();

  static const bool _defineEnabled =
      bool.fromEnvironment('MORTSOM_TEST_ENV', defaultValue: false);
  static const String _relaysDefine =
      String.fromEnvironment('MORTSOM_RELAYS', defaultValue: '');

  static bool _armed = false;

  /// Marks the process as started through the Mortsom entry point.
  /// Only `lib/main_mortsom.dart` may call this. In release mode arming
  /// without the compile-time define is a build mistake and fails loudly in
  /// debug/profile builds through the assertion.
  static void arm() {
    assert(
      !kReleaseMode || _defineEnabled,
      'TestEnvironment.arm() called from a release build without MORTSOM_TEST_ENV',
    );
    _armed = true;
  }

  /// Test-only: clears the armed state between tests.
  @visibleForTesting
  static void disarm() {
    _armed = false;
  }

  /// True when the app runs in the Mortsom test environment.
  static bool get enabled => _armed && _defineEnabled;

  /// Whether the compile-time define is present (regardless of arming).
  @visibleForTesting
  static bool get defineEnabled => _defineEnabled;

  /// Local relay seed list, in the order given by `MORTSOM_RELAYS`
  /// (comma separated). Empty outside the test environment.
  static List<String> get seedRelays =>
      enabled ? parseRelays(_relaysDefine) : const [];

  /// Parses a comma-separated relay list, trimming and dropping blanks.
  @visibleForTesting
  static List<String> parseRelays(String csv) => csv
      .split(',')
      .map((r) => r.trim())
      .where((r) => r.isNotEmpty)
      .toList(growable: false);

  /// In the test environment the app must never fall back to public
  /// bootstrap relays: a disconnected local relay must fail the test.
  static bool get disableBootstrapFallback => enabled;

  /// Local test relays are plain `ws://` on a private address (for example
  /// `ws://localhost:7000`), so the test environment accepts them. The
  /// general build policy (non-release builds accept them too) lives in
  /// `Config.allowInsecureRelays`, not here.
  static bool get allowInsecureRelays => enabled;

  /// Copy of the visible environment marker.
  static const String markerLabel = 'TEST ENVIRONMENT · Mortsom';
}
