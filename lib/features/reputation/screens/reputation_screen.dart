import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/core/automation/automation_id.dart';
import 'package:mostro_mobile/core/automation/automation_ids.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/features/reputation/reputation_errors.dart';
import 'package:mostro_mobile/features/reputation/reputation_service.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// What the selected node offers: export (`reputation_issuer`) and import
/// (`reputation_import_issuers`), read from its info event.
final reputationNodeSupportProvider =
    FutureProvider.autoDispose<({String? issuer, List<String>? importIssuers})>(
  (ref) async {
    final instance =
        await ref.watch(orderRepositoryProvider).awaitMostroInstance();
    return (
      issuer: instance?.reputationIssuer,
      importIssuers: instance?.reputationImportIssuers,
    );
  },
);

/// Reputation: export what the user earned on this node, import what they
/// earned elsewhere, and authorise moving an exported reputation to a new
/// identity.
class ReputationScreen extends ConsumerStatefulWidget {
  const ReputationScreen({super.key});

  @override
  ConsumerState<ReputationScreen> createState() => _ReputationScreenState();
}

class _ReputationScreenState extends ConsumerState<ReputationScreen> {
  String? _exported;
  String? _rebind;
  String? _error;
  bool _busy = false;
  final _newIdentity = TextEditingController();
  final _rebindInput = TextEditingController();

  @override
  void dispose() {
    _newIdentity.dispose();
    _rebindInput.dispose();
    super.dispose();
  }

  String _npub(String hex) => NostrUtils.encodePublicKeyToNpub(hex);

  Future<void> _export() async {
    final s = S.of(context)!;
    final identity = ref.read(keyManagerProvider).masterKeyPair;
    if (identity == null) return;
    // The request binds this node's account to the identity: confirm it.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.reputationExportConfirmTitle),
        content: SelectableText(
            s.reputationExportConfirmBody(_npub(identity.public))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.reputationExportConfirmButton),
          ).withAutomationId(AutomationIds.reputationExportConfirm),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _exported = null;
    });
    // Moving to this identity from the one the account is bound to needs the
    // authorisation that identity signed for this one.
    final rebind = _rebindInput.text.trim();
    try {
      final attestation = await ref
          .read(reputationServiceProvider)
          .exportReputation(rebind: rebind.isEmpty ? null : rebind);
      if (mounted) setState(() => _exported = attestation.json);
    } on ReputationException catch (e) {
      if (mounted) setState(() => _error = reputationErrorText(s, e.reason));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _signRebind(String issuer) {
    final s = S.of(context)!;
    final input = _newIdentity.text.trim();
    String? hex;
    try {
      hex = input.startsWith('npub')
          ? NostrUtils.decodeNpubKeyToPublicKey(input)
          : (RegExp(r'^[0-9a-f]{64}$').hasMatch(input) ? input : null);
    } catch (_) {
      hex = null;
    }
    setState(() {
      _error = null;
      _rebind = null;
      if (hex == null) {
        _error = s.reputationInvalidIdentity;
        return;
      }
      try {
        _rebind = ref
            .read(reputationServiceProvider)
            .signRebind(issuer: issuer, newIdentity: hex);
      } on ReputationException catch (e) {
        _error = reputationErrorText(s, e.reason);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final support = ref.watch(reputationNodeSupportProvider);
    final fullPrivacy = ref.watch(settingsProvider).fullPrivacyMode;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ).withAutomationId(AutomationIds.appBarBack),
        title: Text(
          s.reputation,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (fullPrivacy)
              _Card(child: Text(s.reputationIdentityRequired, style: _body)),
            _Card(
              title: s.reputationImportTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.reputationImportCardBody, style: _body),
                  const SizedBox(height: 12),
                  support.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) =>
                        Text(s.reputationNodeDoesNotImport, style: _body),
                    data: (node) => node.importIssuers == null
                        ? Text(s.reputationNodeDoesNotImport, style: _body)
                        : ElevatedButton(
                            onPressed: fullPrivacy
                                ? null
                                : () => context.push('/import_reputation'),
                            child: Text(s.reputationImportTitle),
                          ).withAutomationId(
                            AutomationIds.reputationOpenImport),
                  ),
                ],
              ),
            ),
            _Card(
              title: s.reputationExportTitle,
              child: support.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) =>
                    Text(s.reputationNodeDoesNotExport, style: _body),
                data: (node) => node.issuer == null
                    ? Text(s.reputationNodeDoesNotExport, style: _body)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(s.reputationExportCardBody, style: _body),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _rebindInput,
                            minLines: 1,
                            maxLines: 3,
                            style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 12),
                            decoration: InputDecoration(
                                hintText: s.reputationRebindPasteHint),
                          ).withAutomationId(
                              AutomationIds.reputationRebindPaste),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: fullPrivacy || _busy ? null : _export,
                            child: Text(s.reputationExportTitle),
                          ).withAutomationId(AutomationIds.reputationExport),
                          if (_exported != null) ...[
                            const SizedBox(height: 12),
                            Text(s.reputationExported, style: _body),
                            _Copyable(text: _exported!).withAutomationId(
                                AutomationIds.reputationExported),
                          ],
                          const SizedBox(height: 16),
                          Text(s.reputationRebindBody, style: _body),
                          TextField(
                            controller: _newIdentity,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                                hintText: s.reputationNewIdentityHint),
                          ).withAutomationId(
                              AutomationIds.reputationRebindIdentity),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: fullPrivacy
                                ? null
                                : () => _signRebind(node.issuer!),
                            child: Text(s.reputationRebindSign),
                          ).withAutomationId(
                              AutomationIds.reputationRebindSign),
                          if (_rebind != null) _Copyable(text: _rebind!),
                        ],
                      ),
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppTheme.red1)),
          ],
        ),
      ),
    );
  }
}

const _body = TextStyle(color: AppTheme.textSecondary, fontSize: 13);

class _Card extends StatelessWidget {
  final String? title;
  final Widget child;

  const _Card({this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      );
}

/// A long value the user copies whole into another app.
class _Copyable extends StatelessWidget {
  final String text;

  const _Copyable({required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: AppTheme.textSecondary),
            onPressed: () => Clipboard.setData(ClipboardData(text: text)),
          ),
        ],
      );
}
