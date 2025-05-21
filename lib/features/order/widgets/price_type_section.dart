import 'package:flutter/material.dart';

class PriceTypeSection extends StatelessWidget {
  final bool isMarketRate;
  final ValueChanged<bool> onToggle;

  const PriceTypeSection({
    super.key,
    required this.isMarketRate,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'Price type ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.white.withOpacity(0.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Market price',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    Text(
                      'Market',
                      style: TextStyle(
                        color: isMarketRate
                            ? const Color(0xFF8CC63F)
                            : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    Switch(
                      value: isMarketRate,
                      activeColor: const Color(0xFF764BA2),
                      onChanged: onToggle,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
