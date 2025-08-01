import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/connection_manager.dart' as conn;

// Provider for ConnectionManager
final connectionManagerProvider = Provider<conn.ConnectionManager>((ref) {
  return conn.ConnectionManager(ref);
});

/// Widget to display connection status with user-friendly indicators
class ConnectionStatusWidget extends ConsumerWidget {
  final bool showDetails;
  final EdgeInsets? padding;
  
  const ConnectionStatusWidget({
    super.key,
    this.showDetails = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<conn.ConnectionState>(
      stream: ref.read(connectionManagerProvider).connectionState,
      initialData: ref.read(connectionManagerProvider).currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? conn.ConnectionState.disconnected;
        
        return Container(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusIndicator(state),
              if (showDetails) ...[
                const SizedBox(width: 8),
                _buildStatusText(context, state),
              ],
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildStatusIndicator(conn.ConnectionState state) {
    switch (state) {
      case conn.ConnectionState.connected:
        return Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        );
      case conn.ConnectionState.connecting:
      case conn.ConnectionState.reconnecting:
        return SizedBox(
          width: 8,
          height: 8,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              state == conn.ConnectionState.connecting 
                  ? Colors.blue 
                  : Colors.orange,
            ),
          ),
        );
      case conn.ConnectionState.failed:
        return const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 12,
        );
      case conn.ConnectionState.disconnected:
        return Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
        );
    }
  }
  
  Widget _buildStatusText(BuildContext context, conn.ConnectionState state) {
    final theme = Theme.of(context);
    String text;
    Color color;
    
    switch (state) {
      case conn.ConnectionState.connected:
        text = 'Connected';
        color = Colors.green;
        break;
      case conn.ConnectionState.connecting:
        text = 'Connecting...';
        color = Colors.blue;
        break;
      case conn.ConnectionState.reconnecting:
        text = 'Reconnecting...';
        color = Colors.orange;
        break;
      case conn.ConnectionState.failed:
        text = 'Connection Failed';
        color = Colors.red;
        break;
      case conn.ConnectionState.disconnected:
        text = 'Disconnected';
        color = Colors.grey;
        break;
    }
    
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Banner widget for connection issues
class ConnectionBannerWidget extends ConsumerWidget {
  const ConnectionBannerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<conn.ConnectionState>(
      stream: ref.read(connectionManagerProvider).connectionState,
      initialData: ref.read(connectionManagerProvider).currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? conn.ConnectionState.disconnected;
        
        if (state == conn.ConnectionState.connected) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _getBannerColor(state),
            border: Border(
              bottom: BorderSide(
                color: _getBannerColor(state).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              _buildBannerIcon(state),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getBannerTitle(state),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _getBannerMessage(state),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (state == conn.ConnectionState.failed)
                TextButton(
                  onPressed: () {
                    // Trigger manual reconnection
                    ref.read(connectionManagerProvider).reconnect();
                  },
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Color _getBannerColor(conn.ConnectionState state) {
    switch (state) {
      case conn.ConnectionState.connecting:
        return Colors.blue.shade700;
      case conn.ConnectionState.reconnecting:
        return Colors.orange.shade700;
      case conn.ConnectionState.failed:
        return Colors.red.shade700;
      case conn.ConnectionState.disconnected:
        return Colors.grey.shade700;
      case conn.ConnectionState.connected:
        return Colors.green.shade700;
    }
  }
  
  Widget _buildBannerIcon(conn.ConnectionState state) {
    switch (state) {
      case conn.ConnectionState.connecting:
      case conn.ConnectionState.reconnecting:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case conn.ConnectionState.failed:
        return const Icon(
          Icons.error_outline,
          color: Colors.white,
          size: 20,
        );
      case conn.ConnectionState.disconnected:
        return const Icon(
          Icons.wifi_off,
          color: Colors.white,
          size: 20,
        );
      case conn.ConnectionState.connected:
        return const Icon(
          Icons.wifi,
          color: Colors.white,
          size: 20,
        );
    }
  }
  
  String _getBannerTitle(conn.ConnectionState state) {
    switch (state) {
      case conn.ConnectionState.connecting:
        return 'Connecting to Mostro';
      case conn.ConnectionState.reconnecting:
        return 'Reconnecting...';
      case conn.ConnectionState.failed:
        return 'Connection Failed';
      case conn.ConnectionState.disconnected:
        return 'Offline';
      case conn.ConnectionState.connected:
        return 'Connected';
    }
  }
  
  String _getBannerMessage(conn.ConnectionState state) {
    switch (state) {
      case conn.ConnectionState.connecting:
        return 'Establishing connection to relay network';
      case conn.ConnectionState.reconnecting:
        return 'Attempting to restore connection';
      case conn.ConnectionState.failed:
        return 'Unable to connect to Mostro relay. Check your internet connection.';
      case conn.ConnectionState.disconnected:
        return 'You are currently offline';
      case conn.ConnectionState.connected:
        return 'Connected to Mostro relay';
    }
  }
}

/// Floating connection status indicator
class FloatingConnectionStatus extends ConsumerWidget {
  const FloatingConnectionStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<conn.ConnectionState>(
      stream: ref.read(connectionManagerProvider).connectionState,
      initialData: ref.read(connectionManagerProvider).currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? conn.ConnectionState.disconnected;
        
        if (state == conn.ConnectionState.connected) {
          return const SizedBox.shrink();
        }
        
        return Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 16,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getBannerColor(state),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBannerIcon(state),
                  const SizedBox(width: 6),
                  Text(
                    _getShortStatusText(state),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Color _getBannerColor(conn.ConnectionState state) {
    switch (state) {
      case conn.ConnectionState.connecting:
        return Colors.blue.shade600;
      case conn.ConnectionState.reconnecting:
        return Colors.orange.shade600;
      case conn.ConnectionState.failed:
        return Colors.red.shade600;
      case conn.ConnectionState.disconnected:
        return Colors.grey.shade600;
      case conn.ConnectionState.connected:
        return Colors.green.shade600;
    }
  }
  
  Widget _buildBannerIcon(conn.ConnectionState state) {
    switch (state) {
      case conn.ConnectionState.connecting:
      case conn.ConnectionState.reconnecting:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case conn.ConnectionState.failed:
        return const Icon(
          Icons.error_outline,
          color: Colors.white,
          size: 14,
        );
      case conn.ConnectionState.disconnected:
        return const Icon(
          Icons.wifi_off,
          color: Colors.white,
          size: 14,
        );
      case conn.ConnectionState.connected:
        return const Icon(
          Icons.wifi,
          color: Colors.white,
          size: 14,
        );
    }
  }
  
  String _getShortStatusText(conn.ConnectionState state) {
    switch (state) {
      case conn.ConnectionState.connecting:
        return 'Connecting';
      case conn.ConnectionState.reconnecting:
        return 'Reconnecting';
      case conn.ConnectionState.failed:
        return 'Failed';
      case conn.ConnectionState.disconnected:
        return 'Offline';
      case conn.ConnectionState.connected:
        return 'Online';
    }
  }
}
