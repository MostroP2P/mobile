import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/shared/providers/session_storage_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class KeyManagementScreen extends ConsumerStatefulWidget {
  const KeyManagementScreen({super.key});

  @override
  ConsumerState<KeyManagementScreen> createState() =>
      _KeyManagementScreenState();
}

class _KeyManagementScreenState extends ConsumerState<KeyManagementScreen> {
  String? _mnemonic;
  int? _tradeKeyIndex;
  bool _loading = false;
  bool _loadingKeys = false;
  bool _showSecretWords = false;
  final TextEditingController _importController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    setState(() {
      _loading = true;
    });
    try {
      final keyManager = ref.read(keyManagerProvider);
      final hasMaster = await keyManager.hasMasterKey();
      if (hasMaster) {
        _mnemonic = await keyManager.getMnemonic();
        _tradeKeyIndex = await keyManager.getCurrentKeyIndex();
      } else {
        if (mounted) _mnemonic = S.of(context)!.noMnemonicFound;
        _tradeKeyIndex = 0;
      }
    } catch (e) {
      if (mounted) {
        _mnemonic = S.of(context)!.errorLoadingMnemonic(e.toString());
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _generateNewMasterKey() async {
    final sessionNotifer = ref.read(sessionNotifierProvider.notifier);
    await sessionNotifer.reset();

    final mostroStorage = ref.read(mostroStorageProvider);
    await mostroStorage.deleteAll();

    final eventStorage = ref.read(eventStorageProvider);
    await eventStorage.deleteAll();

    final keyManager = ref.read(keyManagerProvider);
    await keyManager.generateAndStoreMasterKey();

    await _loadKeys();
  }

  // ignore: unused_element
  Future<void> _importKey() async {
    await _showImportDialog();
  }

  Future<void> _showImportDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.dark2,
          title: Text(
            S.of(context)!.importUser,
            style: const TextStyle(color: AppTheme.cream1),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context)!.importUserInstructions,
                style: TextStyle(
                  color: AppTheme.grey2,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _importController,
                maxLines: 3,
                style: const TextStyle(color: AppTheme.cream1),
                decoration: InputDecoration(
                  hintText: S.of(context)!.mnemonicPlaceholder,
                  hintStyle: TextStyle(color: AppTheme.grey2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.mostroGreen),
                  ),
                  filled: true,
                  fillColor: AppTheme.dark1,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                context.pop();
              },
              child: Text(
                S.of(context)!.cancel,
                style: const TextStyle(color: AppTheme.grey2),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final mnemonic = _importController.text.trim();
                if (mnemonic.isNotEmpty) {
                  context.pop();
                  _importController.clear();
                  await _performImport(mnemonic);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mostroGreen,
                foregroundColor: AppTheme.dark1,
              ),
              child: Text(S.of(context)!.import),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performImport(String mnemonic) async {
    setState(() {
      _loadingKeys = true;
    });
    final sessionNotifer = ref.read(sessionNotifierProvider.notifier);
    await sessionNotifer.reset();

    final mostroStorage = ref.read(mostroStorageProvider);
    await mostroStorage.deleteAll();

    final eventStorage = ref.read(eventStorageProvider);
    await eventStorage.deleteAll();

    final sessionStorage = ref.read(sessionStorageProvider);
    await sessionStorage.deleteAll();

    final keyManager = ref.read(keyManagerProvider);
    try {
      await keyManager.importMnemonic(mnemonic);
      await _loadKeys();

      final restorationService = ref.read(tradeHistoryRestorationProvider);
      restorationService.restoreTradeHistory().then((result) {
        sessionStorage
            .putSessions(
                result.$2.map((key, value) => MapEntry(value.orderId!, value)))
            .then((_) {
          sessionNotifer.init();
        });

        setState(() {
          _tradeKeyIndex = result.$1 + 1;
          _loadingKeys = false;
        });

      }).catchError((error) {
        debugPrint('Trade history restoration failed: $error');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context)!.tradeHistoryRestorationFailed(
                    error.toString(),
                  )),
              backgroundColor: AppTheme.red2,
            ),
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.keyImportedSuccessfully)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.importFailed(e.toString()))),
        );
      }
    }
  }

  String _maskSeedPhrase(String seedPhrase) {
    final words = seedPhrase.split(' ');
    if (words.length < 4) return seedPhrase;

    // Show first 2 and last 2 words, mask the middle
    final first = words.take(2).join(' ');
    final last = words.skip(words.length - 2).join(' ');
    final masked = '••• ••• ••• •••';

    return '$first $masked $last';
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

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
          S.of(context)!.account,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.activeColor))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Secret Words Card
                        _buildSecretWordsCard(context),
                        const SizedBox(height: 16),

                        // Privacy Card
                        _buildPrivacyCard(context, settings),
                        const SizedBox(height: 16),

                        // Current Trade Index Card
                        _buildCurrentTradeIndexCard(context),
                        const SizedBox(height: 24),

                        // Generate New User Button
                        _buildGenerateNewUserButton(context),
                        const SizedBox(height: 16),

                        // Import Mostro User Button
                        _buildImportUserButton(context),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSecretWordsCard(BuildContext context) {
    return Container(
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
                  LucideIcons.key,
                  color: AppTheme.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.secretWords,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _showInfoDialog(
                    context,
                    S.of(context)!.secretWords,
                    S.of(context)!.secretWordsInfoText,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              S.of(context)!.toRestoreYourAccount,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  SelectableText(
                    _showSecretWords
                        ? _mnemonic ?? ''
                        : _mnemonic != null
                            ? _maskSeedPhrase(_mnemonic!)
                            : '',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showSecretWords = !_showSecretWords;
                          });
                        },
                        icon: Icon(
                          _showSecretWords
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye,
                          size: 16,
                          color: AppTheme.activeColor,
                        ),
                        label: Text(
                          _showSecretWords
                              ? S.of(context)!.hide
                              : S.of(context)!.show,
                          style: const TextStyle(
                            color: AppTheme.activeColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard(BuildContext context, settings) {
    return Container(
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
                  LucideIcons.shield,
                  color: AppTheme.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.privacy,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _showInfoDialog(
                    context,
                    S.of(context)!.privacy,
                    S.of(context)!.privacyInfoText,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              S.of(context)!.controlPrivacySettings,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings.fullPrivacyMode
                              ? S.of(context)!.fullPrivacyMode
                              : S.of(context)!.reputationMode,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          settings.fullPrivacyMode
                              ? S.of(context)!.maximumAnonymity
                              : S.of(context)!.standardPrivacyWithReputation,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.fullPrivacyMode,
                    onChanged: (value) {
                      ref
                          .watch(settingsProvider.notifier)
                          .updatePrivacyMode(value);
                    },
                    activeColor: AppTheme.activeColor,
                    inactiveThumbColor: AppTheme.textSecondary,
                    inactiveTrackColor: AppTheme.backgroundInactive,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTradeIndexCard(BuildContext context) {
    return Container(
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
                  LucideIcons.refreshCcw,
                  color: AppTheme.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.currentTradeIndex,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _showInfoDialog(
                    context,
                    S.of(context)!.currentTradeIndex,
                    S.of(context)!.currentTradeIndexInfoText,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              S.of(context)!.yourTradeCounter,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  _loadingKeys
                      ? const CircularProgressIndicator(
                          color: AppTheme.mostroGreen,
                        )
                      : Text(
                          '${_tradeKeyIndex ?? 0}',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      S.of(context)!.incrementsWithEachTrade,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateNewUserButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showGenerateNewUserDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.activeColor,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.userPlus,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.generateNewUser,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportUserButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _importKey,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppTheme.backgroundCard,
          side:
              BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.download,
              size: 20,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.importMostroUser,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.backgroundCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            content,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                S.of(context)!.ok,
                style: const TextStyle(
                  color: AppTheme.activeColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGenerateNewUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.backgroundCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            S.of(context)!.generateNewUserDialogTitle,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            S.of(context)!.generateNewUserDialogContent,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                S.of(context)!.cancel,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _generateNewMasterKey();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.activeColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                S.of(context)!.continueButton,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
