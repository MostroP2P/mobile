import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends ConsumerWidget {
  static final textTheme = AppTheme.theme.textTheme;

  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nostrEvent = ref.watch(orderRepositoryProvider).mostroInstance;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          S.of(context)!.about,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Information Card
                  _buildAppInformationCard(context),
                  const SizedBox(height: 16),

                  // Documentation Card
                  _buildDocumentationCard(context),
                  const SizedBox(height: 16),

                  // Mostro Node Card
                  nostrEvent == null
                      ? _buildLoadingCard(context)
                      : _buildMostroNodeCard(
                          context, MostroInstance.fromEvent(nostrEvent)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAppInformationCard(BuildContext context) {
    const String appVersion = String.fromEnvironment('APP_VERSION',
        defaultValue: 'N/A'); // DON'T TOUCH
    const String gitCommit = String.fromEnvironment('GIT_COMMIT',
        defaultValue: 'N/A'); // DON'T TOUCH

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.smartphone,
                  color: AppTheme.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.appInformation,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Version
            _buildInfoRow(
              S.of(context)!.version,
              appVersion,
            ),
            const SizedBox(height: 12),

            // GitHub Repository
            _buildClickableInfoRow(
              context,
              S.of(context)!.githubRepository,
              'mostro-mobile',
              'https://github.com/MostroP2P/mobile',
              Icons.open_in_new,
            ),
            const SizedBox(height: 12),

            // Commit Hash
            _buildInfoRow(
              S.of(context)!.commitHash,
              gitCommit,
            ),
            const SizedBox(height: 12),

            // License
            _buildLicenseInfoRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentationCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.book,
                  color: AppTheme.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.documentation,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Users Documentation (English)
            _buildClickableInfoRow(
              context,
              S.of(context)!.usersDocumentationEnglish,
              S.of(context)!.read,
              'https://mostro.network/docs-english/',
              Icons.open_in_new,
            ),
            const SizedBox(height: 12),

            // Users Documentation (Spanish)
            _buildClickableInfoRow(
              context,
              S.of(context)!.usersDocumentationSpanish,
              S.of(context)!.read,
              'https://mostro.network/docs-spanish/',
              Icons.open_in_new,
            ),
            const SizedBox(height: 12),

            // Technical Documentation
            _buildClickableInfoRow(
              context,
              S.of(context)!.technicalDocumentation,
              S.of(context)!.read,
              'https://mostro.network/protocol/',
              Icons.open_in_new,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMostroNodeCard(BuildContext context, MostroInstance instance) {
    final formatter = NumberFormat.decimalPattern();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.server,
                  color: AppTheme.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.mostroNode,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // General Info Section
            Text(
              S.of(context)!.generalInfo,
              style: const TextStyle(
                color: AppTheme.activeColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            _buildInfoRowWithDialogAndCopy(
              context,
              S.of(context)!.mostroPublicKey,
              instance.pubKey,
              S.of(context)!.lndNodePublicKeyExplanation,
            ),

            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.maxOrderAmount,
              '${formatter.format(instance.maxOrderAmount)} ${S.of(context)!.satoshis}',
              S.of(context)!.maxOrderAmountExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.minOrderAmount,
              '${formatter.format(instance.minOrderAmount)} ${S.of(context)!.satoshis}',
              S.of(context)!.minOrderAmountExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.orderLifespan,
              '${instance.expirationHours} ${S.of(context)!.hour}',
              S.of(context)!.orderExpirationExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.serviceFee,
              '${instance.fee}%',
              S.of(context)!.serviceFeeExplanation,
            ),
            const SizedBox(height: 20),

            // Technical Details Section
            Text(
              S.of(context)!.technicalDetails,
              style: const TextStyle(
                color: AppTheme.activeColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.mostroDaemonVersion,
              instance.mostroVersion,
              S.of(context)!.mostroVersionExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.mostroCommitId,
              instance.commitHash,
              S.of(context)!.mostroCommitIdExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.orderExpiration,
              '${instance.expirationSeconds} ${S.of(context)!.sec}',
              S.of(context)!.orderExpirationExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.holdInvoiceExpiration,
              '${instance.holdInvoiceExpirationWindow} ${S.of(context)!.sec}',
              S.of(context)!.holdInvoiceExpirationExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.holdInvoiceCltvDelta,
              '${instance.holdInvoiceCltvDelta} ${S.of(context)!.blocks}',
              S.of(context)!.holdInvoiceCltvDeltaExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.invoiceExpirationWindow,
              '${instance.invoiceExpirationWindow} ${S.of(context)!.seconds}',
              S.of(context)!.invoiceExpirationWindowExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.proofOfWork,
              instance.pow.toString(),
              S.of(context)!.proofOfWorkExplanation,
            ),
            const SizedBox(height: 20),

            // Lightning Network Section
            Text(
              S.of(context)!.lightningNetwork,
              style: const TextStyle(
                color: AppTheme.activeColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.lndDaemonVersion,
              instance.lndVersion,
              S.of(context)!.lndDaemonVersionExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialogAndCopy(
              context,
              S.of(context)!.lndNodePublicKey,
              instance.lndNodePublicKey,
              S.of(context)!.lndNodePublicKeyExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.lndCommitId,
              instance.lndCommitHash,
              S.of(context)!.lndCommitIdExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.lndNodeAlias,
              instance.lndNodeAlias,
              S.of(context)!.lndNodeAliasExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.supportedChains,
              instance.supportedChains,
              S.of(context)!.supportedChainsExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialog(
              context,
              S.of(context)!.supportedNetworks,
              instance.supportedNetworks,
              S.of(context)!.supportedNetworksExplanation,
            ),
            const SizedBox(height: 16),

            _buildInfoRowWithDialogAndCopy(
              context,
              S.of(context)!.lndNodeUri,
              instance.lndNodeUri,
              S.of(context)!.lndNodeUriExplanation,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.info,
                  color: AppTheme.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.mostroNode,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Center(
              child: CircularProgressIndicator(
                color: AppTheme.activeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRowWithDialog(
      BuildContext context, String label, String value, String explanation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with info icon
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _showInfoDialog(context, label, explanation),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Value below the label
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRowWithDialogAndCopy(
      BuildContext context, String label, String value, String explanation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with info and copy icons
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _showInfoDialog(context, label, explanation),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _copyToClipboard(context, value),
              borderRadius: BorderRadius.circular(12),
              child: const Icon(
                Icons.copy,
                size: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Value below the label
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.backgroundCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            content,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                S.of(context)!.ok,
                style: const TextStyle(
                  color: AppTheme.activeColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClickableInfoRow(BuildContext context, String label,
      String value, String url, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The label takes up as much space as possible.
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // The value + icon take up only the minimum space
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _launchUrl(url, context),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppTheme.activeColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      icon,
                      color: AppTheme.activeColor,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url, BuildContext context) async {
    try {
      final Uri uri = Uri.parse(url);

      final launchModes = [
        LaunchMode.platformDefault,
        LaunchMode.externalApplication,
        LaunchMode.inAppWebView,
      ];

      for (final mode in launchModes) {
        try {
          await launchUrl(uri, mode: mode);
          return; // Success, exit early
        } catch (e) {
          // Continue to next mode
        }
      }

      // All launch modes failed
      if (context.mounted) {
        _showErrorSnackBar(context, S.of(context)!.cannotOpenLink);
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, S.of(context)!.failedToOpenLink);
      }
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.statusError,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildLicenseInfoRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The label takes up as much space as possible
        Expanded(
          child: Text(
            S.of(context)!.license,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // The value + icon take up only the minimum space
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _showLicenseDialog(context),
                borderRadius: BorderRadius.circular(4),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'MIT',
                      style: TextStyle(
                        color: AppTheme.activeColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: const Color(0xFF1E2230),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                S.of(context)!.license,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // License text in scrollable container
              Container(
                height: 400,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    S.of(context)!.mitLicenseText.replaceAll('\\n', '\n'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8CC63F),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    S.of(context)!.close,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.copiedToClipboard),
          backgroundColor: AppTheme.statusSuccess,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
