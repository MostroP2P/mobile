import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/community/community.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/avatar_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunityCard extends StatelessWidget {
  final Community community;
  final bool isSelected;
  final VoidCallback onTap;

  const CommunityCard({
    super.key,
    required this.community,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.activeColor.withValues(alpha: 0.1)
              : AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.activeColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + name + region
            Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.displayName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        community.region,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.activeColor,
                    size: 24,
                  ),
              ],
            ),

            // About text
            if (community.about != null && community.about!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                community.about!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Currencies
            if (community.currencies.isNotEmpty ||
                (community.hasTradeInfo && community.currencies.isEmpty)) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: community.currencies.isNotEmpty
                    ? community.currencies.map((currency) {
                        return _buildCurrencyTag(currency);
                      }).toList()
                    : [
                        _buildCurrencyTag(
                          S.of(context)!.communityAllCurrencies,
                        ),
                      ],
              ),
            ],

            // Stats row: fee + range
            if (community.fee != null ||
                community.minAmount != null ||
                community.maxAmount != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (community.fee != null) ...[
                    Icon(
                      Icons.percent,
                      size: 14,
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${S.of(context)!.communityFee} ${(community.fee! * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (community.fee != null &&
                      (community.minAmount != null ||
                          community.maxAmount != null))
                    const SizedBox(width: 16),
                  if (community.minAmount != null ||
                      community.maxAmount != null) ...[
                    Icon(
                      Icons.bar_chart,
                      size: 14,
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatRange(context),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // Social links
            if (community.social.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: community.social.map((link) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => _launchUrl(link.url),
                      child: Icon(
                        _socialIcon(link.type),
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.activeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.activeColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (community.picture != null) {
      return ClipOval(
        child: Image.network(
          community.picture!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return NymAvatar(pubkeyHex: community.pubkey, size: 44);
          },
          errorBuilder: (_, __, ___) =>
              NymAvatar(pubkeyHex: community.pubkey, size: 44),
        ),
      );
    }
    return NymAvatar(pubkeyHex: community.pubkey, size: 44);
  }

  String _formatRange(BuildContext context) {
    final min = community.minAmount;
    final max = community.maxAmount;
    if (min != null && max != null) {
      return '${_formatSats(context, min)} - ${_formatSats(context, max)}';
    }
    if (min != null) return '${_formatSats(context, min)}+';
    if (max != null) return '< ${_formatSats(context, max)}';
    return '';
  }

  String _formatSats(BuildContext context, int amount) {
    final locale = Localizations.localeOf(context).toString();
    final formatted = amount < 1000
        ? NumberFormat.decimalPattern(locale).format(amount)
        : NumberFormat.compact(locale: locale).format(amount);
    return '$formatted sats';
  }

  IconData _socialIcon(String type) {
    switch (type) {
      case 'telegram':
        return Icons.telegram;
      case 'x':
        return Icons.alternate_email;
      case 'instagram':
        return Icons.camera_alt_outlined;
      default:
        return Icons.link;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Silently fail - social links are non-critical
    }
  }
}
