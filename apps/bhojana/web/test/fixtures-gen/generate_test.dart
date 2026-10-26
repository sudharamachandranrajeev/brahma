// Writes web/test/fixtures/dart-vectors.json: values made by the real
// brahma_core code, which the web client's tests must reproduce or open.
// Run from the repository root when the wire format changes:
//
//   flutter test web/test/fixtures-gen/generate_test.dart
//
// Inputs are fixed; nonces and ephemeral keys are random, so the file changes
// on every run but stays valid.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
// Transitive through brahma_core; needed to rebuild key pairs from seeds.
// ignore: depend_on_referenced_packages
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _bytes(int from, int n) => [for (var i = 0; i < n; i++) (from + i) & 255];
String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('generate dart-vectors.json', () async {
    const email = '  Me@Example.com ';
    const password = 'correct horse battery staple';
    final keys = await VaultCrypto.fromPassword(email, password);
    final kek = await keys.kek.extractBytes();

    final dek = _bytes(0, 32);
    final recovery = VaultCrypto.newRecoveryKey();
    final recoveryKek = await VaultCrypto.recoveryKek(recovery);
    final loose = recovery.toLowerCase().replaceAll('-', ' ').replaceAll('0', 'o').replaceAll('1', 'l');

    const owner = 'abcdefghijklmno';
    final device = 'a' * 32;
    final batch = {
      'v': 1,
      'rows': [
        {
          't': 'food_items',
          'r': {
            'id': '0b6f3c3e-1d1e-4c55-9b7e-2f6a3d1c9e01',
            'hlc': '001760000000000-000000-${'b' * 32}',
            'deleted': 0,
            'list_id': '7d2b1c0e-5f4a-4e8b-a1c2-3d4e5f6a7b8c',
            'name': 'Semi-skimmed milk £1.55 ✓',
            'qty': 2,
            'note': '',
            'done': 0,
            'ord': 0,
            'added': '2026-10-26',
          },
        },
      ],
    };
    final aad = '${VaultCrypto.version}|$owner|$device|1';

    final link = PairingLink(
      Uri.parse('https://sync.example.com'),
      'pairpairpair123',
      _bytes(100, 32),
      scheme: 'bhojana',
    );
    final x = X25519();
    final joinerSeed = _bytes(200, 32);
    final joiner = await x.newKeyPairFromSeed(joinerSeed);
    final joinerPub = (await joiner.extractPublicKey()).bytes;
    final request = await PairingCrypto.sealRequest(
      link,
      JoinRequest(name: 'Phone', platform: 'android', publicKey: joinerPub),
    );
    final grant = await PairingCrypto.sealGrant(
      link,
      joinerPub,
      PairingGrant(email: 'me@example.com', userId: owner, secret: keys.authSecret, dataKey: dek),
    );

    final out = {
      'note': 'Made by web/test/fixtures-gen/generate_test.dart from brahma_core. Test values only.',
      'password': {'email': email, 'password': password, 'authSecret': keys.authSecret, 'kek': _hex(kek)},
      'wrap': {
        'dek': _hex(dek),
        'wrappedPassword': await VaultCrypto.wrapKey(dek, keys.kek, 'password'),
        'recoveryKey': recovery,
        'recoveryLoose': loose,
        'recoveryKek': _hex(await recoveryKek.extractBytes()),
        'wrappedRecovery': await VaultCrypto.wrapKey(dek, recoveryKek, 'recovery'),
      },
      'batch': {'aad': aad, 'json': batch, 'sealed': await VaultCrypto.seal(batch, dek, aad)},
      'pairing': {
        'link': link.toString(),
        'joinerSeed': _hex(joinerSeed),
        'joinerPublic': base64.encode(joinerPub),
        'code': await PairingCrypto.code(link, joinerPub),
        'request': request,
        'grant': grant,
      },
      'hlc': {
        'ticks': () {
          var t = 1760000000000;
          final c = HlcClock('n0de', now: () => t);
          final a = c.tick(), b = c.tick();
          c.receive('001760000000005-000007-other');
          final d = c.tick();
          t = 1760000000009;
          return [a, b, d, c.tick()];
        }(),
      },
    };
    final file = File('web/test/fixtures/dart-vectors.json');
    await file.writeAsString('${const JsonEncoder.withIndent('  ').convert(out)}\n');
  });
}
