import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';

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
          'ABOUT',
          style: TextStyle(
            color: AppTheme.cream1,
          ),
        ),
      ),
      backgroundColor: AppTheme.dark1,
      body: nostrEvent == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.dark2,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Center(
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.grey,
                          foregroundImage:
                              AssetImage('assets/images/launcher-icon.png'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Mostro Mobile Client',
                        style: textTheme.displayMedium,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildClientDetails(),
                      ),
                      Text(
                        'Mostro Daemon',
                        style: textTheme.displayMedium,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildInstanceDetails(
                            MostroInstance.fromEvent(nostrEvent)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// Builds the header displaying details from the client.
  Widget _buildClientDetails() {
    const String appVersion =
        String.fromEnvironment('APP_VERSION', defaultValue: 'N/A');
    const String gitCommit =
        String.fromEnvironment('GIT_COMMIT', defaultValue: 'N/A');

    return CustomCard(
        color: AppTheme.dark1,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version: $appVersion',
            ),
            const SizedBox(height: 3),
            Text(
              'Commit Hash: $gitCommit',
            ),
          ],
        ));
  }

  /// Builds the header displaying details from the MostroInstance.
  Widget _buildInstanceDetails(MostroInstance instance) {
    final formatter = NumberFormat.decimalPattern(Intl.getCurrentLocale());

    return CustomCard(
        color: AppTheme.dark1,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pubkey: ${instance.pubKey}',
            ),
            const SizedBox(height: 3),
            Text(
              'Version: ${instance.mostroVersion}',
            ),
            const SizedBox(height: 3),
            Text(
              'Commit Hash: ${instance.commitHash}',
            ),
            const SizedBox(height: 3),
            Text(
              'Max Order Amount: ${formatter.format(instance.maxOrderAmount)}',
            ),
            const SizedBox(height: 3),
            Text(
              'Min Order Amount: ${formatter.format(instance.minOrderAmount)}',
            ),
            const SizedBox(height: 3),
            Text(
              'Expiration Hours: ${instance.expirationHours}',
            ),
            const SizedBox(height: 3),
            Text(
              'Expiration Seconds: ${instance.expirationSeconds}',
            ),
            const SizedBox(height: 3),
            Text(
              'Fee: ${instance.fee}',
            ),
            const SizedBox(height: 3),
            Text(
              'Proof of Work: ${instance.pow}',
            ),
            const SizedBox(height: 3),
            Text(
              'Hold Invoice Expiration Window: ${instance.holdInvoiceExpirationWindow}',
            ),
            const SizedBox(height: 3),
            Text(
              'Hold Invoice CLTV Delta: ${instance.holdInvoiceCltvDelta}',
            ),
            const SizedBox(height: 3),
            Text(
              'Invoice Expiration Window: ${instance.invoiceExpirationWindow}',
            ),
          ],
        ));
  }
}
