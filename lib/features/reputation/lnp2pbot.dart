import 'dart:convert';

import 'package:convert/convert.dart';

/// lnp2pBot issues reputation attestations through Telegram
/// (MostroP2P/protocol reputation_attestation.md, "Telegram hand-off").
const lnp2pbotUsername = 'lnp2pbot';

/// The link that asks lnp2pBot to attest the user's reputation for
/// [identityHex]: the identity travels as 43 characters of unpadded base64url
/// so the start parameter fits Telegram's 64-character cap.
Uri lnp2pbotExportUri(String identityHex, {String bot = lnp2pbotUsername}) {
  final encoded = base64Url.encode(hex.decode(identityHex)).replaceAll('=', '');
  return Uri.parse('https://t.me/$bot?start=rep_$encoded');
}

/// The attestation event JSON inside pasted text: lnp2pBot sends it as a
/// message of its own, but a paste may carry surrounding text or whitespace.
/// Returns `null` when no JSON object is found.
String? extractAttestationJson(String text) {
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  final candidate = text.substring(start, end + 1);
  try {
    return jsonDecode(candidate) is Map<String, dynamic> ? candidate : null;
  } on FormatException {
    return null;
  }
}
