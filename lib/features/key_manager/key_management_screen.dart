import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers.dart';
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
        _mnemonic = S.of(context)!.noMnemonicFound;
        _tradeKeyIndex = 0;
      }
    } catch (e) {
      _mnemonic = S.of(context)!.errorLoadingMnemonic(e.toString());
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
    final keyManager = ref.read(keyManagerProvider);
    final importValue = _importController.text.trim();
    if (importValue.isNotEmpty) {
      try {
        await keyManager.importMnemonic(importValue);
        await _loadKeys();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.keyImportedSuccessfully)),
        );
      } catch (e) {
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
                        Row(
                          spacing: 8,
                          children: [
                            const Icon(
                              Icons.key,
                              color: AppTheme.mostroGreen,
                            ),
                            Text(S.of(context)!.secretWords, style: textTheme.titleLarge),
                          ],
                        ),
                        Text(S.of(context)!.toRestoreYourAccount,
                            style: textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.grey2)),
                        SelectableText(
                          _mnemonic ?? '',
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
                              Icons.key,
                              color: AppTheme.mostroGreen,
                            ),
                            Text(S.of(context)!.privacy, style: textTheme.titleLarge),
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
                    children: [
                      ElevatedButton(
                        onPressed: _generateNewMasterKey,
                        child: Row(
                          spacing: 8,
                          children: [
                            const Icon(Icons.person_2_outlined),
                            Text(S.of(context)!.generateNewUser),
                          ],
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: _importKey,
                    child: Row(
                      spacing: 8,
                      children: [
                        const Icon(Icons.download),
                        Text(S.of(context)!.importMostroUser),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
