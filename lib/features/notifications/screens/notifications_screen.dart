import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_item.dart';
import 'package:mostro_mobile/features/notifications/widgets/notifications_actions_menu.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/notification_history_bell_widget.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsHistoryProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: MostroAppBar(
        title: Text(
          S.of(context)!.notifications,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        showBackButton: true,
        showDrawerButton: false,
        actions: const [
          NotificationsActionsMenu(),
          SizedBox(width: 8),
          NotificationBellWidget(),
          SizedBox(width: 16),
        ],
      ),
      body: notifications.when(
        data: (notificationList) {
          if (notificationList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HeroIcon(
                    HeroIcons.bellSlash,
                    style: HeroIconStyle.outline,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context)!.noNotifications,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    S.of(context)!.noNotificationsDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              return ref.refresh(notificationsProvider);
            },
            child: ListView.builder(
              padding: AppTheme.mediumPadding,
              itemCount: notificationList.length,
              itemBuilder: (context, index) {
                final notification = notificationList[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NotificationItem(
                    notification: notification,
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppTheme.mostroGreen,
          ),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const HeroIcon(
                HeroIcons.exclamationTriangle,
                style: HeroIconStyle.outline,
                size: 64,
                color: AppTheme.statusError,
              ),
              const SizedBox(height: 16),
              Text(
                S.of(context)!.errorLoadingNotifications,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.statusError,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(notificationsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mostroGreen,
                ),
                child: Text(S.of(context)!.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}