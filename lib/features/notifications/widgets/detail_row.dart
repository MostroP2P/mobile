import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final HeroIcons icon;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  bool _shouldUseMonospace(String value) {
    return value.contains('npub') || 
           value.contains('#') || 
           value.contains('bc1') || // Bitcoin addresses
           RegExp(r'^[0-9a-fA-F]{8,}$').hasMatch(value); // Hex strings
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          HeroIcon(
            icon,
            style: HeroIconStyle.outline,
            size: 14,
            color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 0,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: _shouldUseMonospace(value) ? 'monospace' : null,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}