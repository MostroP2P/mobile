import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';

class KeyManagementScreen extends ConsumerStatefulWidget {
  const KeyManagementScreen({super.key});

  @override
  ConsumerState<KeyManagementScreen> createState() =>
      _KeyManagementScreenState();
}

class _KeyManagementScreenState extends ConsumerState<KeyManagementScreen> {
  String? _masterKey;
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
        final masterKeyPairs = await keyManager.getMasterKey();
        _masterKey = masterKeyPairs.private;
        _mnemonic = await keyManager.getMnemonic();
        _tradeKeyIndex = await keyManager.getCurrentKeyIndex();
      } else {
        _masterKey = 'No master key found';
        _mnemonic = 'No mnemonic found';
        _tradeKeyIndex = 0;
      }
    } catch (e) {
      _masterKey = 'Error: $e';
      _mnemonic = 'Error: $e';
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  Future<void> _generateNewMasterKey() async {
    final sessionNotifer = ref.read(sessionNotifierProvider.notifier);
    await sessionNotifer.reset();
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
          const SnackBar(content: Text('Key imported successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTheme.theme.textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.cream1),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'KEY MANAGEMENT',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Master Key
                  Text('Master Key', style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  SelectableText(
                    _masterKey ?? '',
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _masterKey != null
                        ? () => _copyToClipboard(_masterKey!, 'Master Key')
                        : null,
                    child: const Text('Copy Master Key'),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: AppTheme.grey2),
                  const SizedBox(height: 16),
                  // Mnemonic
                  Text('Mnemonic', style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  SelectableText(
                    _mnemonic ?? '',
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _mnemonic != null
                        ? () => _copyToClipboard(_mnemonic!, 'Mnemonic')
                        : null,
                    child: const Text('Copy Mnemonic'),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: AppTheme.grey2),
                  const SizedBox(height: 16),
                  // Trade Key Index
                  Text(
                    'Current Trade Key Index: ${_tradeKeyIndex ?? 'N/A'}',
                  ),
                  const SizedBox(height: 16),
                  // Buttons to generate and delete keys
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _generateNewMasterKey,
                        child: const Text('Generate New Master Key'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Import Key
                  Text('Import Key from Mnemonic', style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _importController,
                    decoration: const InputDecoration(
                      labelText: 'Enter key or mnemonic',
                      labelStyle: TextStyle(color: AppTheme.grey2),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _importKey,
                    child: const Text('Import Key'),
                  ),
                ],
              ),
            ),
    );
  }
}
