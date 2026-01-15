import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/features/walkthrough/providers/first_run_provider.dart';
import 'package:mostro_mobile/features/notifications/providers/backup_reminder_provider.dart';
import 'package:mostro_mobile/features/walkthrough/utils/highlight_config.dart';

class WalkthroughScreen extends ConsumerStatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  ConsumerState<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends ConsumerState<WalkthroughScreen> {
  Widget _buildHighlightedText(
    String text, {
    bool isPrivacyStep = false,
    bool isSecurityStep = false,
    bool isChatStep = false,
    bool isOrderBookStep = false,
    bool isCreateOfferStep = false,
  }) {
    const defaultStyle = TextStyle(fontSize: 16, color: Colors.white70);
    const highlightStyle = TextStyle(
      fontSize: 16,
      color: AppTheme.mostroGreen,
      fontWeight: FontWeight.w600,
    );

    final List<TextSpan> spans = [];

    // Determine which highlight config to use based on the step type
    final HighlightConfig config = isPrivacyStep
        ? HighlightConfig.privacy
        : isSecurityStep
            ? HighlightConfig.security
            : isChatStep
                ? HighlightConfig.chat
                : isOrderBookStep
                    ? HighlightConfig.orderBook
                    : isCreateOfferStep
                        ? HighlightConfig.createOffer
                        : HighlightConfig.firstStep;

    final RegExp highlightRegex = RegExp(
      config.pattern,
      caseSensitive: false,
      unicode: true,
    );

    int start = 0;
    for (final match in highlightRegex.allMatches(text)) {
      // Add text before highlighted term
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: defaultStyle,
        ));
      }

      // Add highlighted term with green color and bold
      spans.add(TextSpan(
        text: match.group(0),
        style: highlightStyle,
      ));

      start = match.end;
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: defaultStyle,
      ));
    }

    return Builder(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final horizontalMargin = screenWidth * 0.06; // 6% margin on each side

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
          child: RichText(
            text: TextSpan(children: spans),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  List<PageViewModel> _getPages(BuildContext context) {
    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      bodyTextStyle: TextStyle(fontSize: 16, color: Colors.white70),
      bodyPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      imagePadding: EdgeInsets.zero,
    );

    Widget buildPageImage(String assetPath) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 30.0),
          child: SizedBox(
            height: 200,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    return [
      PageViewModel(
        title: S.of(context)!.welcomeToMostroMobile,
        bodyWidget:
            _buildHighlightedText(S.of(context)!.discoverSecurePlatform),
        image: buildPageImage("assets/images/wt-1.png"),
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: S.of(context)!.easyOnboarding,
        bodyWidget: _buildHighlightedText(
            S.of(context)!.guidedWalkthroughSimple,
            isPrivacyStep: true),
        image: buildPageImage("assets/images/wt-2.png"),
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: S.of(context)!.tradeWithConfidence,
        bodyWidget: _buildHighlightedText(S.of(context)!.seamlessPeerToPeer,
            isSecurityStep: true),
        image: buildPageImage("assets/images/wt-3.png"),
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: S.of(context)!.encryptedChat,
        bodyWidget: _buildHighlightedText(
            S.of(context)!.encryptedChatDescription,
            isChatStep: true),
        image: buildPageImage("assets/images/wt-4.png"),
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: S.of(context)!.takeAnOffer,
        bodyWidget: _buildHighlightedText(S.of(context)!.takeAnOfferDescription,
            isOrderBookStep: true),
        image: buildPageImage("assets/images/wt-5.png"),
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: S.of(context)!.cantFindWhatYouNeed,
        bodyWidget: _buildHighlightedText(S.of(context)!.createYourOwnOffer,
            isCreateOfferStep: true),
        image: buildPageImage("assets/images/wt-6.png"),
        decoration: pageDecoration,
      ),
    ];
  }

  Future<void> _onIntroEnd(BuildContext context) async {
    await ref.read(firstRunProvider.notifier).markFirstRunComplete();
    // Show backup reminder for first-time users
    ref.read(backupReminderProvider.notifier).showBackupReminder();
    if (context.mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstRunState = ref.watch(firstRunProvider);
    
    return firstRunState.when(
      data: (isFirstRun) {
        // If this is not the first run, redirect to home
        if (!isFirstRun) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/');
            }
          });
          return const SizedBox.shrink();
        }
        
        // Show walkthrough for first run
        final theme = Theme.of(context);
        return SafeArea(
          child: IntroductionScreen(
            pages: _getPages(context),
            onDone: () => _onIntroEnd(context),
            onSkip: () => _onIntroEnd(context),
            showSkipButton: true,
            showBackButton: true,
            back: const Icon(Icons.arrow_back),
            skip: Text(S.of(context)!.skip),
            next: const Icon(Icons.arrow_forward),
            done: Text(S.of(context)!.done,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            dotsDecorator: DotsDecorator(
              activeColor: theme.primaryColor,
              size: const Size(8, 8),
              color: theme.cardColor,
              activeSize: const Size(16, 8),
              spacing: const EdgeInsets.symmetric(horizontal: 3),
              activeShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25.0),
              ),
            ),
            globalFooter: const SizedBox(height: 16),
            bodyPadding: const EdgeInsets.only(bottom: 0),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) {
        // On error, redirect to home
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('/');
          }
        });
        return const SizedBox.shrink();
      },
    );
  }
}
