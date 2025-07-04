import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class WalkthroughScreen extends StatelessWidget {
  const WalkthroughScreen({super.key});

  List<PageViewModel> _getPages(BuildContext context) {
    return [
      PageViewModel(
        title: S.of(context)!.welcomeToMostroMobile,
        body: S.of(context)!.discoverSecurePlatform,
        image: Center(
          child: Image.asset("assets/images/mostro-icons.png", height: 175.0),
        ),
        decoration: const PageDecoration(
          titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          bodyTextStyle: TextStyle(fontSize: 16),
        ),
      ),
      PageViewModel(
        title: S.of(context)!.easyOnboarding,
        body: S.of(context)!.guidedWalkthroughSimple,
        image: Center(
          child: Image.asset("assets/images/logo.png", height: 175.0),
        ),
        decoration: const PageDecoration(
          titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          bodyTextStyle: TextStyle(fontSize: 16),
        ),
      ),
      PageViewModel(
        title: S.of(context)!.tradeWithConfidence,
        body: S.of(context)!.seamlessPeerToPeer,
        image: Center(
          child: Image.asset("assets/images/logo.png", height: 175.0),
        ),
        decoration: const PageDecoration(
          titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          bodyTextStyle: TextStyle(fontSize: 16),
        ),
      ),
    ];
  }

  void _onIntroEnd(BuildContext context) {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Use your app's theme colors.
    final theme = Theme.of(context);
    return IntroductionScreen(
      pages: _getPages(context),
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      showSkipButton: true,
      skip: Text(S.of(context)!.skip),
      next: const Icon(Icons.arrow_forward),
      done: Text(S.of(context)!.done, style: const TextStyle(fontWeight: FontWeight.w600)),
      dotsDecorator: DotsDecorator(
        activeColor: theme.primaryColor,
        size: const Size(10, 10),
        color: theme.cardColor,
        activeSize: const Size(22, 10),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
      ),
    );
  }
}