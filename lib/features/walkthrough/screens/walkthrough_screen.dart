import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:go_router/go_router.dart';

class WalkthroughScreen extends StatelessWidget {
  // Define your walkthrough pages – update texts, images and background colors as needed.
  final List<PageViewModel> pages = [
    PageViewModel(
      title: "Welcome to Mostro Mobile",
      body:
          "Discover a secure, private, and efficient platform for peer-to-peer trading.",
      image: Center(
        child: Image.asset("assets/images/mostro-icons.png", height: 175.0),
      ),
      decoration: const PageDecoration(
        titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        bodyTextStyle: TextStyle(fontSize: 16),
      ),
    ),
    PageViewModel(
      title: "Easy Onboarding",
      body: "Our guided walkthrough makes it simple to get started.",
      image: Center(
        child: Image.asset("assets/images/logo.png", height: 175.0),
      ),
      decoration: const PageDecoration(
        titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        bodyTextStyle: TextStyle(fontSize: 16),
      ),
    ),
    PageViewModel(
      title: "Trade with Confidence",
      body: "Enjoy seamless peer-to-peer trades using our advanced protocols.",
      image: Center(
        child: Image.asset("assets/images/logo.png", height: 175.0),
      ),
      decoration: const PageDecoration(
        titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        bodyTextStyle: TextStyle(fontSize: 16),
      ),
    ),
  ];

  WalkthroughScreen({super.key});

  void _onIntroEnd(BuildContext context) {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Use your app's theme colors.
    final theme = Theme.of(context);
    return IntroductionScreen(
      pages: pages,
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      showSkipButton: true,
      skip: const Text("Skip"),
      next: const Icon(Icons.arrow_forward),
      done: const Text("Done", style: TextStyle(fontWeight: FontWeight.w600)),
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
