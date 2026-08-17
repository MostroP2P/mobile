// Mortsom test-environment entry point.
//
// Build with:
//   flutter build apk -t lib/main_mortsom.dart \
//     --dart-define=MORTSOM_TEST_ENV=true \
//     --dart-define=MOSTRO_PUB_KEY=<daemon pubkey> \
//     --dart-define=MORTSOM_RELAYS=ws://10.0.2.2:7000
//
// This entry point arms `TestEnvironment` and seeds the local relay list on
// first launch so subscriptions never touch public bootstrap relays. It is
// the ONLY place that arms the test environment; `lib/main.dart` (the
// production entry point) never does.

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:mostro_mobile/core/app_bootstrap.dart';
import 'package:mostro_mobile/core/test_environment.dart';

Future<void> main() async {
  TestEnvironment.arm();
  // Without a seed list `Config.discoveryRelays` is empty and relay init
  // fails on an assertion deep inside dart_nostr, which reads as an opaque
  // startup crash rather than the build mistake it is.
  if (TestEnvironment.seedRelays.isEmpty) {
    throw StateError(
      'The Mortsom build requires --dart-define=MORTSOM_TEST_ENV=true and '
      '--dart-define=MORTSOM_RELAYS=<ws://host:port>[,...]',
    );
  }
  // UiAutomator2 acts as an accessibility service, but make the semantics
  // tree unconditional so identifiers exist from the first frame.
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  await bootstrapAndRun(seedRelays: TestEnvironment.seedRelays);
}
