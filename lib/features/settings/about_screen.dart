import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/generated/l10n.dart';

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
          icon: const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.cream1),
          onPressed: () => context.pop(),
        ),
        title: Text(
          S.of(context)!.about,
          style: TextStyle(
            color: AppTheme.cream1,
          ),
        ),
      ),
      backgroundColor: AppTheme.dark1,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: AppTheme.largePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 24,
                children: [
                  CustomCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      spacing: 16,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          spacing: 8,
                          children: [
                            const Icon(
                              Icons.content_paste,
                              color: AppTheme.mostroGreen,
                            ),
                            Text(S.of(context)!.appInformation,
                                style: textTheme.titleLarge),
                          ],
                        ),
                        Row(
                          spacing: 8,
                          children: [
                            Expanded(
                              child: _buildClientDetails(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  CustomCard(
                    color: AppTheme.dark2,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      spacing: 16,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          spacing: 8,
                          children: [
                            const Icon(
                              Icons.content_paste,
                              color: AppTheme.mostroGreen,
                            ),
                            Text(S.of(context)!.aboutMostroInstance,
                                style: textTheme.titleLarge),
                          ],
                        ),
                        Text(S.of(context)!.generalInfo, 
                            style: textTheme.titleMedium?.copyWith(
                              color: AppTheme.mostroGreen,
                            )),
                        nostrEvent == null
                            ? const Center(child: CircularProgressIndicator())
                            : Row(
                                spacing: 8,
                                children: [
                                  Expanded(
                                    child: _buildInstanceDetails(context,
                                        MostroInstance.fromEvent(nostrEvent)),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  /// Builds the header displaying details from the client.
  Widget _buildClientDetails(BuildContext context) {
    const String appVersion =
        String.fromEnvironment('APP_VERSION', defaultValue: 'N/A');
    const String gitCommit =
        String.fromEnvironment('GIT_COMMIT', defaultValue: 'N/A');

    return CustomCard(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.version,
        ),
        Text(
          appVersion,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              S.of(context)!.githubRepository,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          S.of(context)!.commitHash,
        ),
        Text(
          gitCommit,
        ),
      ],
    ));
  }

  /// Builds the header displaying details from the MostroInstance.
  Widget _buildInstanceDetails(BuildContext context, MostroInstance instance) {
    final formatter = NumberFormat.decimalPattern();

    return CustomCard(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${S.of(context)!.pubkey}: ${instance.pubKey}',
            ),
            const SizedBox(height: 3),
            Text(
              '${S.of(context)!.mostroVersion}: ${instance.mostroVersion}',
            ),
            const SizedBox(height: 3),
            Text(
              '${S.of(context)!.commitHash}: ${instance.commitHash}',
            ),
            const SizedBox(height: 3),
            Text(
              '${S.of(context)!.maxOrderAmount}: ${formatter.format(instance.maxOrderAmount)}',
            ),
            const SizedBox(height: 3),
            Text(
              '${S.of(context)!.minOrderAmount}: ${formatter.format(instance.minOrderAmount)}',
            ),
            const SizedBox(height: 3),
            Text(
              '${S.of(context)!.expirationHours}: ${instance.expirationHours}',
            ),
            const SizedBox(height: 3),
            Text(
              '${S.of(context)!.expirationSeconds}: ${instance.expirationSeconds}',
            ),
            const SizedBox(height: 3),
            Text(
              '${S.of(context)!.fee}: ${instance.fee}',
            ),
            const SizedBox(height: 3),
            Text(
              '${S.of(context)!.proofOfWork}: ${instance.pow}',
            ),
            const SizedBox(height: 3),
            Text(
              '${S.of(context)!.holdInvoiceExpirationWindow}: ${instance.holdInvoiceExpirationWindow}',
            ),
            const SizedBox(height: 3),
            Text(
              '${S.of(context)!.holdInvoiceCltvDelta}: ${instance.holdInvoiceCltvDelta}',
            ),
            const SizedBox(height: 3),
            Text(
              '${S.of(context)!.invoiceExpirationWindow}: ${instance.invoiceExpirationWindow}',
            ),
          ],
        ));
  }
}
