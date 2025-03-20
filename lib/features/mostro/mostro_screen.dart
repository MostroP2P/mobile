import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_drawer.dart';

class MostroScreen extends ConsumerWidget {
  const MostroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nostrEvent = ref.read(orderRepositoryProvider).mostroInstance;
    final List<MostroMessage> mostroMessages = []; // ref.read(mostroStorageProvider).getAllOrders();

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
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Mostro Messages',
                        style: AppTheme.theme.textTheme.displayLarge,
                      ),
                    ),
                    const SizedBox(height: 24),
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
