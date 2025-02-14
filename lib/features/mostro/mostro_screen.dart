import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_drawer.dart';

class MostroScreen extends ConsumerWidget {
  const MostroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read the current MostroInstance (here represented by a NostrEvent)
    final nostrEvent = ref.watch(orderRepositoryProvider).mostroInstance;

    // For messages, assume you have a provider that holds a list of MostroMessage objects.
    final mostroMessages = ref.watch(mostroRepositoryProvider).allMessages;

    return nostrEvent == null
        ? Scaffold(
            backgroundColor: AppTheme.dark1,
            body: const Center(child: CircularProgressIndicator()),
          )
        : Scaffold(
            backgroundColor: AppTheme.dark1,
            appBar: const MostroAppBar(),
            drawer: const MostroAppDrawer(),
            body: RefreshIndicator(
              onRefresh: () async {
                // Trigger a refresh of your providers
                //ref.refresh(mostroInstanceProvider);
                //ref.refresh(mostroMessagesProvider);
              },
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.dark2,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey,
                        foregroundImage:
                            AssetImage('assets/images/launcher-icon.png'),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildInstanceDetails(
                          MostroInstance.fromEvent(nostrEvent)),
                    ),
                    // List of messages
                    Expanded(
                      child: ListView.builder(
                        itemCount: mostroMessages.length,
                        itemBuilder: (context, index) {
                          final message = mostroMessages[index];
                          return _buildMessageTile(message);
                        },
                      ),
                    ),
                    const BottomNavBar(),
                  ],
                ),
              ),
            ),
          );
  }

  /// Builds the header displaying details from the MostroInstance.
  Widget _buildInstanceDetails(MostroInstance instance) {
    return CustomCard(
        color: AppTheme.dark1,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version: ${instance.mostroVersion}',
              style: GoogleFonts.robotoCondensed(
                color: AppTheme.cream1,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Commit Hash: ${instance.commitHash}',
            ),
            const SizedBox(height: 4),
            Text(
              'Max Order Amount: ${instance.maxOrderAmount}',
            ),
            const SizedBox(height: 4),
            Text(
              'Min Order Amount: ${instance.minOrderAmount}',
            ),
            const SizedBox(height: 4),
            Text(
              'Expiration Hours: ${instance.expirationHours}',
            ),
            const SizedBox(height: 4),
            Text(
              'Expiration Seconds: ${instance.expirationSeconds}',
            ),
            const SizedBox(height: 4),
            Text(
              'Fee: ${instance.fee}',
            ),
            const SizedBox(height: 4),
            Text(
              'Proof of Work: ${instance.pow}',
            ),
            const SizedBox(height: 4),
            Text(
              'Hold Invoice Expiration Window: ${instance.holdInvoiceExpirationWindow}',
            ),
            const SizedBox(height: 4),
            Text(
              'Hold Invoice CLTV Delta: ${instance.holdInvoiceCltvDelta}',
            ),
            const SizedBox(height: 4),
            Text(
              'Invoice Expiration Window: ${instance.invoiceExpirationWindow}',
            ),
            const SizedBox(height: 4),
          ],
        ));
  }

  /// Builds a simple ListTile to display an individual MostroMessage.
  Widget _buildMessageTile(MostroMessage message) {
    return ListTile(
      title: Text(
        'Order Type: ${message.action}',
      ),
      subtitle: Text(
        'Order Id: ${message.payload?.toJson()}',
      ),
    );
  }
}
