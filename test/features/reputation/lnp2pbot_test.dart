import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/reputation/lnp2pbot.dart';

void main() {
  test('the export link carries the identity in 43 base64url characters', () {
    const identity =
        'ab1db593a4d1196eb07335fdc702a314712ed29c631ceaebd84708a17d3bc2f7';
    final uri = lnp2pbotExportUri(identity);
    expect(uri.scheme, 'https');
    expect(uri.host, 't.me');
    expect(uri.path, '/lnp2pbot');
    final start = uri.queryParameters['start']!;
    expect(start, startsWith('rep_'));
    expect(start.length, lessThanOrEqualTo(64));
    final encoded = start.substring(4);
    expect(encoded, hasLength(43));
    expect(encoded, isNot(contains('=')));
    // Round trip, the way the bot decodes it.
    final bytes = base64Url.decode('$encoded=');
    expect(
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), identity);
  });

  test('finds the attestation inside pasted text', () {
    final vectors =
        jsonDecode(File('test/fixtures/reputation_v1.json').readAsStringSync());
    final json = vectors['attestation']['valid']['json'] as String;
    expect(extractAttestationJson(json), json);
    expect(extractAttestationJson('  \n$json\n '), json);
    expect(extractAttestationJson('Here it is: $json thanks'), json);
    expect(extractAttestationJson('no json here'), isNull);
    expect(extractAttestationJson('{broken'), isNull);
  });
}
