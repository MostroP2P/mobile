import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/shared/providers/session_storage_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/shared/widgets/privacy_switch_widget.dart';
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
  bool _showMnemonic = false;
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

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

  Future<void> _importKey() async {
    await _showImportDialog();
  }

  Future<void> _showImportDialog() async {
    final TextEditingController mnemonicController = TextEditingController();

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
                controller: mnemonicController,
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
                final mnemonic = mnemonicController.text.trim();
                if (mnemonic.isNotEmpty) {
                  context.pop();
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
          _tradeKeyIndex = result.$1;
        });

        if (mounted && result.$1 > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context)!.tradeHistoryRestored(
                    result.$1.toString(),
                  )),
            ),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    final textTheme = AppTheme.theme.textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(
            HeroIcons.arrowLeft,
            color: AppTheme.cream1,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          S.of(context)!.account,
          style: TextStyle(
            color: AppTheme.cream1,
          ),
        ),
      ),
      backgroundColor: AppTheme.dark1,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppTheme.largePadding,
              child: Column(
                spacing: 24,
                children: [
                  // Secret Words
                  CustomCard(
                    color: AppTheme.dark2,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      spacing: 16,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with title, info icon, and show/hide button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              spacing: 8,
                              children: [
                                const Icon(
                                  Icons.key,
                                  color: AppTheme.mostroGreen,
                                ),
                                Text(S.of(context)!.secretWords,
                                    style: textTheme.titleLarge),
                                // Info tooltip
                                Tooltip(
                                  key: _tooltipKey,
                                  message: S.of(context)!.mnemonicInfoTooltip,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  textStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                  preferBelow: false,
                                  child: GestureDetector(
                                    onTap: () {
                                      _tooltipKey.currentState
                                          ?.ensureTooltipVisible();
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(2.0),
                                      child: Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: AppTheme.grey2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Show/Hide button
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showMnemonic = !_showMnemonic;
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.mostroGreen,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.05),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              child: Text(
                                _showMnemonic
                                    ? S.of(context)!.hide
                                    : S.of(context)!.show,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Description
                        Text(S.of(context)!.toRestoreYourAccount,
                            style: textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.grey2)),
                        // Mnemonic display
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: SelectableText(
                            _showMnemonic
                                ? (_mnemonic ?? '')
                                : '•••• •••• •••• •••• •••• •••• •••• •••• •••• •••• •••• ••••',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Privacy
                  CustomCard(
                    color: AppTheme.dark2,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      spacing: 16,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          spacing: 8,
                          children: [
                            const Icon(
                              Icons.lock,
                              color: AppTheme.mostroGreen,
                            ),
                            Text(S.of(context)!.privacy,
                                style: textTheme.titleLarge),
                          ],
                        ),
                        Text(S.of(context)!.controlPrivacySettings,
                            style: textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.grey2)),
                        PrivacySwitch(
                            initialValue: settings.fullPrivacyMode,
                            onChanged: (bool value) {
                              ref
                                  .watch(settingsProvider.notifier)
                                  .updatePrivacyMode(value);
                            }),
                      ],
                    ),
                  ),
                  // Trade Key Index
                  CustomCard(
                    color: AppTheme.dark2,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      spacing: 16,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          spacing: 8,
                          children: [
                            const Icon(
                              Icons.sync,
                              color: AppTheme.mostroGreen,
                            ),
                            Text(S.of(context)!.currentTradeIndex,
                                style: textTheme.titleLarge),
                          ],
                        ),
                        Text(S.of(context)!.yourTradeCounter,
                            style: textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.grey2)),
                        CustomCard(
                          color: AppTheme.dark1,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Text(
                                '${_tradeKeyIndex ?? 'N/A'}',
                              ),
                              const SizedBox(width: 24),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(S.of(context)!.incrementsWithEachTrade,
                                      style: textTheme.bodyMedium
                                          ?.copyWith(color: AppTheme.grey2)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 16,
                    children: [
                      ElevatedButton(
                        onPressed: _generateNewMasterKey,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 8,
                          children: [
                            const Icon(Icons.person_2_outlined),
                            Text(S.of(context)!.generateNewUser),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _importKey,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 8,
                          children: [
                            const Icon(Icons.download),
                            Text(S.of(context)!.importMostroUser),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
