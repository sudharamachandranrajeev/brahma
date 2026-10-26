import 'dart:convert';
import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:brahma_core/src/sentinel/releases.dart' show CheckFailed;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 26);
  late SimpleKeyPair keys;
  late String pub;

  setUpAll(() async {
    keys = await Ed25519().newKeyPair();
    pub = base64.encode((await keys.extractPublicKey()).bytes);
  });

  Future<String> sign(String text) async =>
      base64.encode((await Ed25519().sign(utf8.encode(text), keyPair: keys)).bytes);

  String file({String issued = '2026-10-20T00:00:00Z', String expires = '2027-01-01T00:00:00Z'}) =>
      jsonEncode({
        'issued': issued,
        'expires': expires,
        'advisories': [
          {
            'id': 'artha-leak',
            'apps': ['artha'],
            'below': '0.2.1',
            'status': 'serious',
            'title': 'Update Artha',
            'why': 'Old versions log the sync token.',
          },
          {'id': 'all', 'status': 'info', 'title': 'Note', 'why': 'For everyone.'},
          {'id': 'broken'},
        ],
      });

  Future<String> reason(Future<SentinelRules> f) async {
    try {
      await f;
    } on CheckFailed catch (e) {
      return e.message;
    }
    fail('verified');
  }

  test('a file signed with the key verifies and reads', () async {
    final text = file();
    final r = await verifyRules(text, await sign(text), now: now, publicKey: pub);
    expect(r.issued, DateTime.utc(2026, 10, 20));
    expect([for (final a in r.advisories) a.id], ['artha-leak', 'all']);
    final leak = r.advisories.first;
    expect(leak.status, Status.serious);
    expect(leak.concerns('artha', '0.2.0'), isTrue);
    expect(leak.concerns('artha', '0.2.1'), isFalse);
    expect(leak.concerns('vidya', '0.1.0'), isFalse);
    expect(r.advisories.last.concerns('vidya', '9.9.9'), isTrue);
  });

  test('a changed, foreign, expired or replayed file is refused', () async {
    final text = file();
    final sig = await sign(text);
    expect(await reason(verifyRules('$text ', sig, now: now, publicKey: pub)), contains('not signed'));
    expect(await reason(verifyRules(text, sig, now: now)), contains('not signed'));
    expect(
      await reason(verifyRules(text, 'not base64!', now: now, publicKey: pub)),
      contains('not readable'),
    );
    final old = file(expires: '2026-01-01T00:00:00Z');
    expect(await reason(verifyRules(old, await sign(old), now: now, publicKey: pub)), contains('expired'));
    expect(
      await reason(verifyRules(text, sig, now: now, notBefore: DateTime.utc(2026, 10, 25), publicKey: pub)),
      contains('older'),
    );
  });

  test('the published rules file verifies against the built-in key', () async {
    final text = File('../sentinel/rules.json').readAsStringSync();
    final sig = File('../sentinel/rules.json.sig').readAsStringSync();
    expect((await verifyRules(text, sig, now: now)).issued, isNotNull);
  });
}
