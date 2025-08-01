import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple connection status indicator for quick wins implementation
class SimpleConnectionStatus extends ConsumerWidget {
  final bool showText;
  
  const SimpleConnectionStatus({
    super.key,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now, we'll show a simple indicator based on NostrService availability
    // This is a placeholder until the full ConnectionManager is integrated
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Simple connection indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getConnectionColor(),
              shape: BoxShape.circle,
            ),
          ),
          if (showText) ...[
            const SizedBox(width: 6),
            Text(
              _getConnectionText(),
              style: TextStyle(
                color: _getConnectionColor(),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Color _getConnectionColor() {
    // For quick wins, we'll assume connected if NostrService is available
    // In a real implementation, this would check actual connection state
    return Colors.green;
  }
  
  String _getConnectionText() {
    // For quick wins, show simple status
    return 'Online';
  }
}

/// Simple connection banner for network issues
class SimpleConnectionBanner extends StatelessWidget {
  final bool showOffline;
  
  const SimpleConnectionBanner({
    super.key,
    this.showOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!showOffline) {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade700,
        border: Border(
          bottom: BorderSide(
            color: Colors.orange.shade700.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Connection Issues',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Some features may not work properly',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: Trigger manual reconnection
            },
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
