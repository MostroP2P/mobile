import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/relays/widgets/relay_selector.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/widgets/currency_selection_dialog.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/widgets/language_selector.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final mostroTextContoller =
        TextEditingController(text: settings.mostroPublicKey);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          S.of(context)!.settings,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language Card
                  _buildLanguageCard(context),
                  const SizedBox(height: 16),

                  // Currency Card
                  _buildCurrencyCard(context, ref),
                  const SizedBox(height: 16),

                  // Relays Card
                  _buildRelaysCard(context, ref),
                  const SizedBox(height: 16),

                  // Mostro Card
                  _buildMostroCard(context, ref, mostroTextContoller),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLanguageCard(BuildContext context) {
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
                  LucideIcons.globe,
                  color: AppTheme.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.language,
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
                    S.of(context)!.language,
                    S.of(context)!.languageInfoText,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              S.of(context)!.chooseLanguageDescription,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            const LanguageSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyCard(BuildContext context, WidgetRef ref) {
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
                  LucideIcons.coins,
                  color: AppTheme.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.currency,
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
                    S.of(context)!.currency,
                    S.of(context)!.currencyInfoText,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              S.of(context)!.setDefaultFiatCurrency,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            _buildCurrencySelector(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildRelaysCard(BuildContext context, WidgetRef ref) {
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
                  LucideIcons.radio,
                  color: AppTheme.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.relays,
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
                    S.of(context)!.relays,
                    S.of(context)!.relaysInfoText,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              S.of(context)!.selectNostrRelays,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            RelaySelector(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    RelaySelector.showAddDialog(context, ref);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.activeColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    S.of(context)!.addRelay,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMostroCard(
      BuildContext context, WidgetRef ref, TextEditingController controller) {
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
                  LucideIcons.zap,
                  color: AppTheme.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.mostro,
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
                    S.of(context)!.mostro,
                    S.of(context)!.mostroInfoText,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              S.of(context)!.enterMostroPublicKey,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.backgroundInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextFormField(
                controller: controller,
                style: const TextStyle(color: AppTheme.textPrimary),
                onChanged: (value) => ref
                    .watch(settingsProvider.notifier)
                    .updateMostroInstance(value),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  labelText: S.of(context)!.mostroPubkey,
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencySelector(BuildContext context, WidgetRef ref) {
    final currenciesAsync = ref.watch(currencyCodesProvider);
    final selectedFiatCode = ref.watch(selectedFiatCodeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: currenciesAsync.when(
        loading: () => const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stackTrace) => Row(
          children: [
            Text(S.of(context)!.errorLoadingCurrencies),
            TextButton(
              onPressed: () => ref.refresh(currencyCodesProvider),
              child: Text(S.of(context)!.retry),
            ),
          ],
        ),
        data: (currencies) {
          final selectedCurrency = currencies[selectedFiatCode];
          final displayText = selectedCurrency != null
              ? '${selectedCurrency.emoji.isNotEmpty ? selectedCurrency.emoji : '🏳️'} $selectedFiatCode - ${selectedCurrency.name}'
              : selectedFiatCode;

          return InkWell(
            onTap: () async {
              final selectedCode = await CurrencySelectionDialog.show(
                context,
                ref,
                title: S.of(context)!.defaultFiatCurrency,
                currentSelection: selectedFiatCode,
              );
              if (selectedCode != null && context.mounted) {
                ref
                    .read(settingsProvider.notifier)
                    .updateDefaultFiatCode(selectedCode);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context)!.defaultFiatCurrency,
                          style: const TextStyle(
                            color: AppTheme.grey2,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayText,
                          style: const TextStyle(
                            color: AppTheme.cream1,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: AppTheme.grey2,
                  ),
                ],
              ),
            ),
          );
        },
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
}
