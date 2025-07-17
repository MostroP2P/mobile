import 'package:flutter/material.dart';
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
          icon: const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.textPrimary),
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
                  
                  // About Mostro Instance Card
                  nostrEvent == null
                      ? _buildLoadingCard(context)
                      : _buildMostroInstanceCard(context, MostroInstance.fromEvent(nostrEvent)),
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
    const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
    const String gitCommit = String.fromEnvironment('GIT_COMMIT', defaultValue: 'add5b89d87674067d54c79ca01275856e45554a2');

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
              S.of(context)!.githubRepository,
              'mostro/mobile',
              'https://github.com/MostroP2P/mobile',
              Icons.open_in_new,
            ),
            const SizedBox(height: 12),
            
            // Commit Hash
            _buildInfoRow(
              S.of(context)!.commitHash,
              gitCommit,
            ),
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
              S.of(context)!.usersDocumentationEnglish,
              S.of(context)!.read,
              'https://mostro.network/docs-english/',
              Icons.open_in_new,
            ),
            const SizedBox(height: 12),
            
            // Users Documentation (Spanish)
            _buildClickableInfoRow(
              S.of(context)!.usersDocumentationSpanish,
              S.of(context)!.read,
              'https://mostro.network/docs-spanish/',
              Icons.open_in_new,
            ),
            const SizedBox(height: 12),
            
            // Technical Documentation
            _buildClickableInfoRow(
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

  Widget _buildMostroInstanceCard(BuildContext context, MostroInstance instance) {
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
                  LucideIcons.info,
                  color: AppTheme.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.aboutMostroInstance,
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
            
            _buildInfoRow(
              S.of(context)!.mostroPublicKey,
              instance.pubKey,
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.maxOrderAmount,
              '${formatter.format(instance.maxOrderAmount)} ${S.of(context)!.satoshis}',
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.minOrderAmount,
              '${formatter.format(instance.minOrderAmount)} ${S.of(context)!.satoshis}',
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.orderLifespan,
              '${instance.expirationHours} ${S.of(context)!.hour}',
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.serviceFee,
              '${instance.fee}%',
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
            
            _buildInfoRow(
              S.of(context)!.mostroDaemonVersion,
              instance.mostroVersion,
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.mostroCommitId,
              instance.commitHash,
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.orderExpiration,
              '${instance.expirationSeconds} ${S.of(context)!.sec}',
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.holdInvoiceExpiration,
              '${instance.holdInvoiceExpirationWindow} ${S.of(context)!.sec}',
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.holdInvoiceCltvDelta,
              '${instance.holdInvoiceCltvDelta} ${S.of(context)!.blocks}',
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.invoiceExpirationWindow,
              '${instance.invoiceExpirationWindow} ${S.of(context)!.seconds}',
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.proofOfWork,
              instance.pow.toString(),
            ),
            const SizedBox(height: 20),
            
            // LND Daemon Section
            Text(
              S.of(context)!.lndDaemonVersion,
              style: const TextStyle(
                color: AppTheme.activeColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildInfoRow(
              S.of(context)!.lndDaemonVersion,
              instance.lndVersion,
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.lndNodePublicKey,
              instance.lndNodePublicKey,
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.lndCommitId,
              instance.lndCommitHash,
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.lndNodeAlias,
              instance.lndNodeAlias,
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.supportedChains,
              instance.supportedChains,
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.supportedNetworks,
              instance.supportedNetworks,
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow(
              S.of(context)!.lndNodeUri,
              instance.lndNodeUri,
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
                  S.of(context)!.aboutMostroInstance,
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

  Widget _buildClickableInfoRow(String label, String value, String url, IconData icon) {
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
          child: GestureDetector(
            onTap: () => _launchUrl(url),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: AppTheme.activeColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  color: AppTheme.activeColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Handle error - could show a snackbar or dialog
    }
  }
}