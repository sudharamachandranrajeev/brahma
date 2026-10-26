// The web client (web/) and the native apps must be one account's devices:
// this opens values the TypeScript code sealed (web/test/fixtures/
// ts-vectors.json), then runs the real SyncEngine against the dev server
// alongside the web client: a batch pushed by the web is applied to an
// in-memory Bhojana database, and one pushed from Dart shows up in the web.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bhojana/domain/book.dart';
import 'package:brahma_core/brahma_core.dart';
// Transitive through brahma_core; needed to rebuild a key pair from a seed.
// ignore: depend_on_referenced_packages
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const _app = AppIdentity(id: 'bhojana', name: 'Bhojana', androidPackage: 'dev.brahma.bhojana');
const _setupCode = 'TEST-SETUP-CODE';

List<int> _unhex(String s) => [
  for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
];

Future<(Process, String)> _start() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  final p = await Process.start('node', ['test/dev-server.ts', '$port'], workingDirectory: 'server');
  final ready = Completer<void>();
  p.stdout.transform(utf8.decoder).listen((t) {
    if (t.contains('ready') && !ready.isCompleted) ready.complete();
  });
  p.stderr.transform(utf8.decoder).listen((t) => stderr.write(t));
  await ready.future.timeout(const Duration(seconds: 20));
  return (p, 'http://127.0.0.1:$port');
}

/// Runs the web client's command-line twin (web/test/interop-client.ts).
Future<Map<String, dynamic>> _web(List<String> args) async {
  final r = await Process.run('node', ['test/interop-client.ts', ...args], workingDirectory: 'web');
  if (r.exitCode != 0) fail('web client ${args[1]} failed:\n${r.stdout}\n${r.stderr}');
  return jsonDecode((r.stdout as String).trim().split('\n').last) as Map<String, dynamic>;
}

void main() {
  group('values sealed by the web client', () {
    final ts =
        jsonDecode(File('web/test/fixtures/ts-vectors.json').readAsStringSync()) as Map<String, dynamic>;
    final pw = ts['password'] as Map<String, dynamic>;
    final wrap = ts['wrap'] as Map<String, dynamic>;
    final pairing = ts['pairing'] as Map<String, dynamic>;

    test('the password gives the same login secret and key', () async {
      final keys = await VaultCrypto.fromPassword(pw['email'] as String, pw['password'] as String);
      expect(keys.authSecret, pw['authSecret']);
      expect(await keys.kek.extractBytes(), _unhex(pw['kek'] as String));
      expect(
        await VaultCrypto.unwrapKey(wrap['wrappedPassword'] as String, keys.kek, 'password'),
        _unhex(wrap['dek'] as String),
      );
    });

    test('the recovery key opens its wrap', () async {
      final kek = await VaultCrypto.recoveryKek(wrap['recoveryKey'] as String);
      expect(
        await VaultCrypto.unwrapKey(wrap['wrappedRecovery'] as String, kek, 'recovery'),
        _unhex(wrap['dek'] as String),
      );
    });

    test('a change batch opens', () async {
      final batch = ts['batch'] as Map<String, dynamic>;
      final opened = await VaultCrypto.open(
        batch['sealed'] as String,
        _unhex(wrap['dek'] as String),
        batch['aad'] as String,
      );
      expect(opened, batch['json']);
    });

    test('a pairing link, request, code and grant are read', () async {
      final link = BrahmaLink.parse(pairing['link'] as String) as PairingLink;
      expect(link.server.toString(), 'https://sync.example.com');
      final request = await PairingCrypto.openRequest(link, pairing['request'] as String);
      expect(request.name, 'Firefox on Linux');
      expect(request.platform, 'web');
      expect(base64.encode(request.publicKey), pairing['joinerPublic']);
      expect(await PairingCrypto.code(link, request.publicKey), pairing['code']);

      final pair = await X25519().newKeyPairFromSeed(_unhex(pairing['recipientSeed'] as String));
      expect(base64.encode((await pair.extractPublicKey()).bytes), pairing['recipientPublic']);
      final grant = await PairingCrypto.openGrant(JoinTicket(link, pair, ''), pairing['grant'] as String);
      expect(grant.email, 'someone@example.com');
      expect(grant.secret, pw['authSecret']);
      expect(grant.dataKey, _unhex(wrap['dek'] as String));
    });
  });

  group('the web client and the native SyncEngine on one server', () {
    late Process node;
    late String url;
    var ready = true;

    setUpAll(() async {
      // Node 24+ runs the TypeScript directly; the web client needs its packages.
      final v = Process.runSync('node', ['--version']);
      final major = int.tryParse(RegExp(r'v(\d+)').firstMatch('${v.stdout}')?.group(1) ?? '') ?? 0;
      if (v.exitCode != 0 || major < 24 || !Directory('web/node_modules').existsSync()) {
        ready = false;
        return;
      }
      (node, url) = await _start();
    });
    tearDownAll(() => ready ? node.kill() : null);

    test('a batch from the web is applied by Dart, and one from Dart reaches the web', () async {
      if (!ready) {
        markTestSkipped('needs Node 24+ and `npm ci` in web/');
        return;
      }
      const email = 'me@example.com', password = 'correct horse battery';
      final pushed = await _web([url, 'signup-push', email, password, _setupCode]);
      expect(pushed['pushed'], 5);

      final db = memoryDatabase();
      addTearDown(db.close);
      final store = await Store.open(db);
      final account = AccountService(
        KeyVault(MemorySecretStore(), _app),
        deviceId: store.deviceId,
        platform: 'linux',
      );
      await account.signIn(server: url, email: email, password: password);
      final result = await (await account.engine(store))!.run();
      expect(result.pulled, 5);

      final book = ShoppingBook(store);
      final lists = await db.select(db.foodLists).get();
      expect(lists.single.name, 'From the web');
      final items = await book.items(lists.single.id);
      expect(
        [for (final i in items) '${i.qty} ${i.name} ${i.done} ${i.note}'],
        ['2 oat milk false ', '3 bread true seeded'],
      );
      expect(await book.pref('bhojana.shops'), 'tesco,aldi');
      final prices = await book.prices();
      expect(costByShop(items, prices).single.pence, 225);
      expect(prices.single.source, 'typed');

      await book.addItem(lists.single.id, '4 bananas', today: '2026-10-26');
      await book.tick(items.first, true);
      final back = await (await account.engine(store))!.run();
      expect(back.pushed, 2);

      final seen = await _web([url, 'pull', email, password]);
      final names = [for (final i in seen['items'] as List) '${i['qty']} ${i['name']} ${i['done']}']..sort();
      expect(names, ['2 oat milk true', '3 bread true', '4 bananas false']);
      final ordered = await (db.select(db.foodItems)..orderBy([(t) => OrderingTerm.asc(t.ord)])).get();
      expect(ordered.last.name, 'bananas');
    });
  });
}
