import 'package:flutter/material.dart';
import 'package:mostro_mobile/features/mostro/mostro_node.dart';
import 'package:mostro_mobile/shared/providers/avatar_provider.dart';

/// Displays a Mostro node avatar with network image support and NymAvatar fallback.
class MostroNodeAvatar extends StatelessWidget {
  final MostroNode node;
  final double size;

  const MostroNodeAvatar({
    super.key,
    required this.node,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (node.picture != null) {
      return ClipOval(
        child: Image.network(
          node.picture!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: size,
              height: size,
              child: Center(
                child: SizedBox(
                  width: size * 0.4,
                  height: size * 0.4,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) =>
              NymAvatar(pubkeyHex: node.pubkey, size: size / 2),
        ),
      );
    }
    return NymAvatar(pubkeyHex: node.pubkey, size: size / 2);
  }
}
