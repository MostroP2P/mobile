import 'package:flutter/material.dart';

class PremiumSection extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const PremiumSection({
    super.key,
    required this.value,
    required this.onChanged,
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
                  'Premium (%) ',
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
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFF764BA2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        value.toStringAsFixed(1),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Slider
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFF764BA2),
                    inactiveTrackColor: Colors.grey[800],
                    thumbColor: Colors.white,
                    overlayColor: const Color(0xFF764BA2).withOpacity(0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: value,
                    min: -10,
                    max: 10,
                    divisions: 200,
                    onChanged: onChanged,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        '-10%',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      Text(
                        '+10%',
                        style:
                            TextStyle(color: Color(0xFF8CC63F), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
