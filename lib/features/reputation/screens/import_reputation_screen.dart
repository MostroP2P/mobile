import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/core/automation/automation_id.dart';
import 'package:mostro_mobile/core/automation/automation_ids.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/reputation/lnp2pbot.dart';
import 'package:mostro_mobile/features/reputation/reputation_attestation.dart';
import 'package:mostro_mobile/features/reputation/reputation_errors.dart';
import 'package:mostro_mobile/features/reputation/reputation_service.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Import reputation earned elsewhere: get an attestation (from lnp2pBot on
/// Telegram, or exported from another Mostro), check its figures, and import
/// it into the selected node.
class ImportReputationScreen extends ConsumerStatefulWidget {
  const ImportReputationScreen({super.key});

  @override
  ConsumerState<ImportReputationScreen> createState() =>
      _ImportReputationScreenState();
}

class _ImportReputationScreenState
    extends ConsumerState<ImportReputationScreen> {
  final _input = TextEditingController();
  ReputationAttestation? _attestation;
  String? _error;
  bool _busy = false;
  bool _imported = false;

  @override
  void initState() {
    super.initState();
    // An attestation exported from another Mostro waits to be imported.
    ref.read(reputationServiceProvider).pendingAttestation().then((pending) {
      if (!mounted || pending == null || _input.text.isNotEmpty) return;
      _input.text = pending.json;
      _check();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _check() {
    final s = S.of(context)!;
    final json = extractAttestationJson(_input.text);
    setState(() {
      _attestation = null;
      _imported = false;
      _error = null;
      if (json == null) {
        _error = s.reputationInvalidAttestation;
        return;
      }
      try {
        _attestation = ReputationAttestation.parse(
          json,
          now: ref.read(reputationClockProvider)(),
        );
      } on AttestationException catch (e) {
        _error = reputationErrorText(s, e.reason);
      }
    });
  }

  Future<void> _import() async {
    final attestation = _attestation;
    if (attestation == null) return;
    final s = S.of(context)!;
    setState(() => _busy = true);
    try {
      await ref
          .read(reputationServiceProvider)
          .importReputation(attestation.json);
      if (mounted) setState(() => _imported = true);
    } on ReputationException catch (e) {
      if (mounted) setState(() => _error = reputationErrorText(s, e.reason));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openBot() async {
    final identity = ref.read(keyManagerProvider).masterKeyPair;
    if (identity == null) return;
    await launchUrl(
      lnp2pbotExportUri(identity.public),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
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
          s.reputationImportTitle,
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
            Text(s.reputationImportIntro,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.send),
              label: Text(s.reputationOpenLnp2pbot),
              onPressed: _openBot,
            ).withAutomationId(AutomationIds.reputationImportOpenBot),
            const SizedBox(height: 16),
            TextField(
              controller: _input,
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText: s.reputationPasteHint,
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                border: const OutlineInputBorder(),
              ),
            ).withAutomationId(AutomationIds.reputationImportInput),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _busy ? null : _check,
              child: Text(s.reputationCheck),
            ).withAutomationId(AutomationIds.reputationImportCheck),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.red1)),
            ],
            if (_attestation != null) ...[
              const SizedBox(height: 16),
              _Figures(attestation: _attestation!)
                  .withAutomationId(AutomationIds.reputationImportFigures),
              const SizedBox(height: 16),
              if (_imported)
                Text(s.reputationImported,
                    style: const TextStyle(color: AppTheme.activeColor))
              else
                ElevatedButton(
                  onPressed: _busy ? null : _import,
                  child: Text(s.reputationImportConfirm),
                ).withAutomationId(AutomationIds.reputationImportConfirm),
            ],
          ],
        ),
      ),
    );
  }
}

class _Figures extends StatelessWidget {
  final ReputationAttestation attestation;

  const _Figures({required this.attestation});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final since = DateTime.fromMillisecondsSinceEpoch(
      attestation.since * 1000,
      isUtc: true,
    );
    final days = DateTime.now().toUtc().difference(since).inDays;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.reputationFigures(
              attestation.reviews,
              attestation.ratingText,
              days < 0 ? 0 : days,
            ),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(s.reputationFiguresNote,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
