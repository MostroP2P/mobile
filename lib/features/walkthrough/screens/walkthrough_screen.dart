import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/features/walkthrough/providers/first_run_provider.dart';

class WalkthroughScreen extends ConsumerStatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  ConsumerState<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends ConsumerState<WalkthroughScreen> {
  Widget _buildHighlightedText(String text, {bool isPrivacyStep = false, bool isSecurityStep = false, bool isChatStep = false, bool isOrderBookStep = false}) {
    final List<TextSpan> spans = [];
    
    if (isOrderBookStep) {
      // For order book step, highlight "order book" and its translations
      final RegExp orderBookRegex = RegExp(r'\b(order book|libro de órdenes|libro ordini)\b', caseSensitive: true);
      
      int start = 0;
      for (final match in orderBookRegex.allMatches(text)) {
        // Add text before highlighted term
        if (match.start > start) {
          spans.add(TextSpan(
            text: text.substring(start, match.start),
            style: const TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
          ));
        }
        
        // Add highlighted term with green color and bold
        spans.add(TextSpan(
          text: match.group(0),
          style: const TextStyle(fontSize: 16, color: Color(0xFF8cc63f), fontWeight: FontWeight.w600),
        ));
        
        start = match.end;
      }
      
      // Add remaining text
      if (start < text.length) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: const TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
        ));
      }
    } else if (isChatStep) {
      // For chat step, highlight "end-to-end encrypted" and its translations
      final RegExp encryptedRegex = RegExp(r'\b(end-to-end encrypted|encriptado de extremo a extremo|crittografata end-to-end)\b', caseSensitive: true);
      
      int start = 0;
      for (final match in encryptedRegex.allMatches(text)) {
        // Add text before highlighted term
        if (match.start > start) {
          spans.add(TextSpan(
            text: text.substring(start, match.start),
            style: const TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
          ));
        }
        
        // Add highlighted term with green color and bold
        spans.add(TextSpan(
          text: match.group(0),
          style: const TextStyle(fontSize: 16, color: Color(0xFF8cc63f), fontWeight: FontWeight.w600),
        ));
        
        start = match.end;
      }
      
      // Add remaining text
      if (start < text.length) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: const TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
        ));
      }
    } else if (isSecurityStep) {
      // For security step, highlight "Hold Invoices" and its translations
      final RegExp holdInvoicesRegex = RegExp(r'\b(Hold Invoices|Facturas de Retención|Fatture di Blocco)\b', caseSensitive: true);
      
      int start = 0;
      for (final match in holdInvoicesRegex.allMatches(text)) {
        // Add text before highlighted term
        if (match.start > start) {
          spans.add(TextSpan(
            text: text.substring(start, match.start),
            style: const TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
          ));
        }
        
        // Add highlighted term with green color and bold
        spans.add(TextSpan(
          text: match.group(0),
          style: const TextStyle(fontSize: 16, color: Color(0xFF8cc63f), fontWeight: FontWeight.w600),
        ));
        
        start = match.end;
      }
      
      // Add remaining text
      if (start < text.length) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: const TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
        ));
      }
    } else if (isPrivacyStep) {
      // For privacy step, highlight "Reputation mode" and "Full privacy mode"
      final RegExp privacyTermsRegex = RegExp(r'\b(Reputation mode|Full privacy mode|Modo reputación|Modo privacidad completa|Modalità reputazione|Modalità privacy completa)\b', caseSensitive: true);
      
      int start = 0;
      for (final match in privacyTermsRegex.allMatches(text)) {
        // Add text before highlighted term
        if (match.start > start) {
          spans.add(TextSpan(
            text: text.substring(start, match.start),
            style: const TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
          ));
        }
        
        // Add highlighted term with green color
        spans.add(TextSpan(
          text: match.group(0),
          style: const TextStyle(fontSize: 16, color: Color(0xFF8cc63f), fontWeight: FontWeight.w600),
        ));
        
        start = match.end;
      }
      
      // Add remaining text
      if (start < text.length) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: const TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
        ));
      }
    } else {
      // For first step, highlight "Nostr"
      final RegExp nostrRegex = RegExp(r'\bNostr\b', caseSensitive: true);

      int start = 0;
      for (final match in nostrRegex.allMatches(text)) {
        // Add text before "Nostr"
        if (match.start > start) {
          spans.add(TextSpan(
            text: text.substring(start, match.start),
            style: const TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
          ));
        }

        // Add "Nostr" with green color
        spans.add(TextSpan(
          text: match.group(0),
          style: const TextStyle(fontSize: 16, color: Color(0xFF8cc63f)),
        ));

        start = match.end;
      }

      // Add remaining text
      if (start < text.length) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: const TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
        ));
      }
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
    return [
      PageViewModel(
        title: S.of(context)!.welcomeToMostroMobile,
        bodyWidget:
            _buildHighlightedText(S.of(context)!.discoverSecurePlatform),
        image: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 90.0),
            child: Image.asset("assets/images/wt-1.png", height: 256.5),
          ),
        ),
        decoration: const PageDecoration(
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          bodyTextStyle: TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
        ),
      ),
      PageViewModel(
        title: S.of(context)!.easyOnboarding,
        bodyWidget: _buildHighlightedText(S.of(context)!.guidedWalkthroughSimple, isPrivacyStep: true),
        image: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 60.0),
            child: Image.asset("assets/images/wt-2.png", height: 256.5),
          ),
        ),
        decoration: const PageDecoration(
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          bodyTextStyle: TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
        ),
      ),
      PageViewModel(
        title: S.of(context)!.tradeWithConfidence,
        bodyWidget: _buildHighlightedText(S.of(context)!.seamlessPeerToPeer, isSecurityStep: true),
        image: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 60.0),
            child: Image.asset("assets/images/wt-3.png", height: 256.5),
          ),
        ),
        decoration: const PageDecoration(
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          bodyTextStyle: TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
        ),
      ),
      PageViewModel(
        title: S.of(context)!.encryptedChat,
        bodyWidget: _buildHighlightedText(S.of(context)!.encryptedChatDescription, isChatStep: true),
        image: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 60.0),
            child: Image.asset("assets/images/wt-4.png", height: 256.5),
          ),
        ),
        decoration: const PageDecoration(
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          bodyTextStyle: TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
        ),
      ),
      PageViewModel(
        title: S.of(context)!.takeAnOffer,
        bodyWidget: _buildHighlightedText(S.of(context)!.takeAnOfferDescription, isOrderBookStep: true),
        image: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 60.0),
            child: Image.asset("assets/images/wt-5.png", height: 256.5),
          ),
        ),
        decoration: const PageDecoration(
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          bodyTextStyle: TextStyle(fontSize: 16, color: Color(0xFF9aa1b6)),
        ),
      ),
    ];
  }

  Future<void> _onIntroEnd(BuildContext context) async {
    await ref.read(firstRunProvider.notifier).markFirstRunComplete();
    if (context.mounted) {
      context.go('/');
    }
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
      showBackButton: true,
      back: const Icon(Icons.arrow_back),
      skip: Text(S.of(context)!.skip),
      next: const Icon(Icons.arrow_forward),
      done: Text(S.of(context)!.done,
          style: const TextStyle(fontWeight: FontWeight.w600)),
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
