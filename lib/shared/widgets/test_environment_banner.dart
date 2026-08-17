import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/automation/automation_ids.dart';
import 'package:mostro_mobile/core/test_environment.dart';

/// Visible marker shown on every screen while the app runs in the Mortsom
/// test environment. It makes a test build impossible to confuse with a
/// production one and gives automation a stable element to assert on.
class TestEnvironmentBanner extends StatelessWidget {
  const TestEnvironmentBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!TestEnvironment.enabled) {
      return child;
    }
    // Only the banner is pinned to LTR. Wrapping the stack would force the
    // application under test into LTR as well, so an RTL locale would not
    // exercise the layout it ships with. The stack still needs an explicit
    // direction for `Positioned` to resolve left/right.
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Semantics(
                identifier: AutomationIds.envMarker,
                label: TestEnvironment.markerLabel,
                container: true,
                child: IgnorePointer(
                  child: Container(
                    color: const Color(0xCCB71C1C),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    alignment: Alignment.center,
                    child: const Text(
                      TestEnvironment.markerLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
