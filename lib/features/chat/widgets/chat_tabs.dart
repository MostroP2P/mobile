import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/chat/providers/chat_tab_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class ChatTabs extends ConsumerWidget {
  final ChatTabType currentTab;

  const ChatTabs({
    super.key,
    required this.currentTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildTabButton(context, ref, ChatTabType.messages, S.of(context)!.messages, currentTab == ChatTabType.messages),
          _buildTabButton(context, ref, ChatTabType.disputes, S.of(context)!.disputes, currentTab == ChatTabType.disputes),
        ],
      ),
    );
  }

  Widget _buildTabButton(
      BuildContext context, WidgetRef ref, ChatTabType tabType, String text, bool isActive) {
    return Expanded(
      child: InkWell(
        onTap: () {
          ref.read(chatTabProvider.notifier).state = tabType;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppTheme.mostroGreen : Colors.transparent,
                width: 3.0,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? AppTheme.mostroGreen : AppTheme.textInactive,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}