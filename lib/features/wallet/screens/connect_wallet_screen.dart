import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/services/nwc/nwc_connection.dart';
import 'package:mostro_mobile/services/nwc/nwc_exceptions.dart';
import 'package:mostro_mobile/generated/l10n.dart';

/// Screen for connecting a wallet via NWC URI.
///
/// Provides a text field to paste a URI and a placeholder QR scanner button.
class ConnectWalletScreen extends ConsumerStatefulWidget {
  const ConnectWalletScreen({super.key});

  @override
  ConsumerState<ConnectWalletScreen> createState() =>
      _ConnectWalletScreenState();
}

class _ConnectWalletScreenState extends ConsumerState<ConnectWalletScreen> {
  final _uriController = TextEditingController();
  String? _validationError;
  bool _isConnecting = false;

  @override
  void dispose() {
    _uriController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for state changes to navigate on success
    ref.listen<NwcState>(nwcProvider, (previous, next) {
      if (next.status == NwcStatus.connected) {
        if (context.mounted) {
          context.pop();
        }
      } else if (next.status == NwcStatus.error) {
        setState(() {
          _isConnecting = false;
          _validationError = next.errorMessage;
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(
            HeroIcons.arrowLeft,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          S.of(context)!.connectWallet,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.link,
                          color: AppTheme.activeColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          S.of(context)!.pasteNwcUri,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // URI input field
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundInput,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _validationError != null
                              ? Colors.redAccent
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextFormField(
                        controller: _uriController,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        onChanged: (_) {
                          if (_validationError != null) {
                            setState(() => _validationError = null);
                          }
                        },
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'nostr+walletconnect://...',
                          hintStyle: const TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              LucideIcons.scanLine,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () => _showQrComingSoon(context),
                            tooltip: S.of(context)!.scanQrCode,
                          ),
                        ),
                      ),
                    ),

                    // Validation error
                    if (_validationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _validationError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Connect button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isConnecting ? null : _onConnect,
                        icon: _isConnecting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(LucideIcons.plug, size: 18),
                        label: Text(
                          _isConnecting
                              ? S.of(context)!.connecting
                              : S.of(context)!.connectWallet,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.activeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onConnect() {
    final uri = _uriController.text.trim();
    if (uri.isEmpty) {
      setState(() => _validationError = S.of(context)!.pasteNwcUri);
      return;
    }

    // Validate URI format before attempting connection
    try {
      NwcConnection.fromUri(uri);
    } on NwcInvalidUriException catch (e) {
      setState(() => _validationError = e.message);
      return;
    }

    setState(() {
      _isConnecting = true;
      _validationError = null;
    });

    ref.read(nwcProvider.notifier).connect(uri);
  }

  void _showQrComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.scanQrCodeComingSoon),
        backgroundColor: AppTheme.backgroundCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
