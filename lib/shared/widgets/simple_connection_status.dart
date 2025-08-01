import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/connection_manager.dart' as conn;

/// Simple connection status indicator for quick wins implementation
class SimpleConnectionStatus extends ConsumerWidget {
  final bool showText;
  
  const SimpleConnectionStatus({
    super.key,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conn.connectionManagerProvider);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _getConnectionColor(state),
            shape: BoxShape.circle,
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 6),
          Text(
            _getConnectionText(context, state),
            style: TextStyle(
              color: _getConnectionColor(state),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
  
  Color _getConnectionColor(conn.ConnectionState state) {
    switch (state) {
      case conn.ConnectionState.connected:
        return Colors.green;
      case conn.ConnectionState.connecting:
      case conn.ConnectionState.reconnecting:
        return Colors.orange;
      case conn.ConnectionState.disconnected:
      case conn.ConnectionState.failed:
        return Colors.red;
    }
  }
  
  String _getConnectionText(BuildContext context, conn.ConnectionState state) {
    switch (state) {
      case conn.ConnectionState.connected:
        return S.of(context)!.connectionConnected;
      case conn.ConnectionState.connecting:
        return S.of(context)!.connectionConnecting;
      case conn.ConnectionState.reconnecting:
        return S.of(context)!.connectionReconnecting;
      case conn.ConnectionState.disconnected:
        return S.of(context)!.connectionDisconnected;
      case conn.ConnectionState.failed:
        return S.of(context)!.connectionFailed;
    }
  }
}

/// Simple connection banner for connection issues
class SimpleConnectionBanner extends ConsumerWidget {
  const SimpleConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conn.connectionManagerProvider);
    
    // Show banner for problematic connection states
    final hasConnectionIssues = state == conn.ConnectionState.disconnected ||
        state == conn.ConnectionState.failed ||
        state == conn.ConnectionState.reconnecting;
    
    if (!hasConnectionIssues) {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.of(context)!.connectionIssues,
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  S.of(context)!.connectionIssuesDescription,
                  style: TextStyle(
                    color: Colors.orange.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(conn.connectionManagerInstanceProvider).reconnect();
            },
            child: Text(
              S.of(context)!.connectionRetry,
              style: TextStyle(color: Colors.orange.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
