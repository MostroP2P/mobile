import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'relays_provider.dart';
import 'relay.dart';

class RelaysScreen extends ConsumerWidget {
  const RelaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final settings = ref.watch(settingsProvider);

    final relays = ref.watch(relaysProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.cream1),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'RELAYS',
          style: TextStyle(
            color: AppTheme.cream1,
          ),
        ),
      ),
      backgroundColor: AppTheme.dark1,
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: settings.relays.length,
        itemBuilder: (context, index) {
          final relay = relays[index];
          return Card(
            color: AppTheme.dark2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(
                relay.url,
                style: const TextStyle(color: Colors.white),
              ),
              leading: Icon(
                Icons.circle,
                color: relay.isHealthy ? Colors.green : Colors.red,
                size: 16,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () {
                      _showEditDialog(context, relay, ref);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: () {
                      ref.read(relaysProvider.notifier).removeRelay(relay.url);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.mostroGreen,
        child: const Icon(Icons.add),
        onPressed: () => _showAddDialog(context, ref),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      useRootNavigator: true,
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Add Relay'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Relay URL'),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                final newRelay = Relay(url: url, isHealthy: true);
                ref.read(relaysProvider.notifier).addRelay(newRelay);
              }
              context.pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

void _showEditDialog(BuildContext context, Relay relay, WidgetRef ref) {
  final controller = TextEditingController(text: relay.url);
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Edit Relay'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Relay URL'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty && newUrl != relay.url) {
                final updatedRelay = relay.copyWith(url: newUrl);
                ref.read(relaysProvider.notifier).updateRelay(relay, updatedRelay);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}
}
