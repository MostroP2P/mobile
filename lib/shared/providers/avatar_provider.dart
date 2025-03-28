import 'package:flutter/material.dart';

final List<IconData> kPossibleIcons = [
  Icons.person,
  Icons.star,
  Icons.favorite,
  Icons.lock,
  Icons.adb,
  Icons.bolt,
  Icons.casino,
  Icons.visibility,
  Icons.language,
  Icons.face,
  Icons.thumb_up,
  Icons.pets,
  Icons.hotel_class,
  Icons.anchor,
  Icons.school,
  Icons.public,
  Icons.construction,
  Icons.emoji_emotions,
  Icons.whatshot,
  Icons.waving_hand,
  Icons.nights_stay,
  Icons.cruelty_free,
  Icons.outdoor_grill,
  Icons.sports_motorsports,
  Icons.sports_football,
  Icons.skateboarding,
  Icons.sports_martial_arts,
  Icons.paragliding,
  Icons.face_6,
  Icons.south_america,
  Icons.face_2,
  Icons.tsunami,
  Icons.local_shipping,
  Icons.flight,
  Icons.directions_run,
  Icons.lunch_dining,
  Icons.directions_boat,
];

/// Deterministically pick one IconData from [kPossibleIcons],
/// based on the user’s 32-byte hex pubkey.
IconData pickNymIcon(String hexPubKey) {
  final pubKeyBigInt = BigInt.parse(hexPubKey, radix: 16);
  final index = (pubKeyBigInt % BigInt.from(kPossibleIcons.length)).toInt();
  return kPossibleIcons[index];
}

/// Deterministically pick a color from the 32-byte pubkey.
Color pickNymColor(String hexPubKey) {
  final pubKeyBigInt = BigInt.parse(hexPubKey, radix: 16);
  final hue = (pubKeyBigInt % BigInt.from(360)).toInt().toDouble();
  return HSVColor.fromAHSV(1.0, hue, 0.6, 0.8).toColor();
}

class NymAvatar extends StatelessWidget {
  final String pubkeyHex;
  final double size;

  const NymAvatar({
    super.key,
    required this.pubkeyHex,
    this.size = 32.0,
  });

  @override
  Widget build(BuildContext context) {
    final icon = pickNymIcon(pubkeyHex);
    final color = pickNymColor(pubkeyHex);

    return CircleAvatar(
      radius: (size) - 8,
      backgroundColor: color,
      child: CircleAvatar(
        child: Icon(
          icon,
          size: size,
          color: color,
        ),
      ),
    );
  }
}
