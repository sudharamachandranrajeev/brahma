// Runs the real Worker handler (server/, on node:sqlite) and drives core's
// account service and remote against it: sign-up, sign-in, recovery key,
// device pairing and the change log.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _app = AppIdentity(id: 'bhojana', name: 'Bhojana', androidPackage: 'dev.brahma.bhojana');
const _setupCode = 'TEST-SETUP-CODE';

Future<(Process, String)> _start() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  final p = await Process.start('node', ['test/dev-server.ts', '$port'], workingDirectory: 'server');
  final ready = Completer<void>();
  p.stdout.transform(utf8.decoder).listen((t) {
    if (t.contains('ready') && !ready.isCompleted) ready.complete();
  });
  p.stderr.transform(utf8.decoder).listen((t) => stderr.write(t));
  await ready.future.timeout(const Duration(seconds: 20));
  return (p, 'http://127.0.0.1:$port');
}

AccountService _device(String id, [MemorySecretStore? store]) => AccountService(
  KeyVault(store ?? MemorySecretStore(), _app),
  deviceId: id * 32,
  deviceName: 'Device $id',
  platform: 'linux',
);

void main() {
  late Process node;
  late String url;
  var nodeOk = true;

  setUpAll(() async {
    // The dev server runs TypeScript directly and uses node:sqlite: Node 24+.
    final v = Process.runSync('node', ['--version']);
    final major = int.tryParse(RegExp(r'v(\d+)').firstMatch('${v.stdout}')?.group(1) ?? '') ?? 0;
    if (v.exitCode != 0 || major < 24) {
      nodeOk = false;
      return;
    }
    (node, url) = await _start();
  });
  tearDownAll(() => nodeOk ? node.kill() : null);

  test('connect recognises the Worker', () async {
    if (!nodeOk) return;
    expect(await AccountApi.connect(url), isA<AccountApi>());
  });

  test('owner signs up, a second device signs in, pairing hands over the keys', () async {
    if (!nodeOk) return;
    final a = _device('1');
    final bad = a.signUp(
      server: url,
      email: 'me@example.com',
      password: 'correct horse battery',
      invite: 'nope',
    );
    await expectLater(bad, throwsA(isA<SyncException>()));

    final recovery = await a.signUp(
      server: url,
      email: 'me@example.com',
      password: 'correct horse battery',
      invite: _setupCode,
    );
    expect(recovery, isNotEmpty);

    final b = _device('2');
    await b.signIn(server: url, email: 'me@example.com', password: 'correct horse battery');
    expect(await a.vault.dataKey(), await b.vault.dataKey());

    final c = _device('3');
    final link = await a.offerPairing();
    final ticket = await c.requestJoin(BrahmaLink.parse(link.toString()) as PairingLink);
    final request = await a.pairingRequest(link);
    expect(request!.name, 'Device 3');
    expect(ticket.code, isNotEmpty);
    await a.approvePairing(link, request);
    final grant = await c.joinGrant(ticket);
    await c.join(ticket, grant!);
    expect(await c.vault.dataKey(), await a.vault.dataKey());
    expect(await a.pairingFinished(link), isTrue);
  });

  test('changes pushed by one device are pulled by another, in order', () async {
    if (!nodeOk) return;
    final api = await AccountApi.connect(url);
    final keys = await VaultCrypto.fromPassword('me@example.com', 'correct horse battery');
    final id = await api.login('me@example.com', keys.authSecret);
    final remote = api.remote(id);
    final dev = 'a' * 32;
    expect(await remote.push(dev, 1, 'one'), isTrue);
    expect(await remote.push(dev, 1, 'again'), isFalse);
    expect(await remote.push(dev, 2, 'two'), isTrue);
    expect(await remote.lastSeq(dev), 2);
    expect(await remote.fetch(dev, 2), 'two');
    expect(await remote.fetch(dev, 9), isNull);
    expect([for (final c in await remote.pull(dev, 1)) c.payload], ['two']);
  });

  test('a changed password reaches other devices and a wrong password is refused', () async {
    if (!nodeOk) return;
    final a = _device('4');
    final recovery = await a.signUp(
      server: url,
      email: 'x@example.com',
      password: 'first password 1',
      invite: await _invite(url),
    );
    await a.changePassword(oldPassword: 'first password 1', newPassword: 'second password 2');
    final b = _device('5');
    await b.signIn(server: url, email: 'x@example.com', password: 'second password 2');
    expect(await b.vault.dataKey(), await a.vault.dataKey());
    expect(recovery, isNotEmpty);
    await expectLater(
      _device('6').signIn(server: url, email: 'x@example.com', password: 'wrong password 3'),
      throwsA(isA<SyncException>()),
    );
  });
}

/// A fresh invite code, asked for as the owner (the first account made above).
Future<String> _invite(String url) async {
  final keys = await VaultCrypto.fromPassword('me@example.com', 'correct horse battery');
  final http = HttpClient();
  Future<Map<String, dynamic>> post(String path, Object body, [String? token]) async {
    final req = await http.postUrl(Uri.parse('$url$path'));
    req.headers.contentType = ContentType.json;
    if (token != null) req.headers.set('authorization', 'Bearer $token');
    req.write(jsonEncode(body));
    final res = await req.close();
    return jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
  }

  final token = (await post('/api/login', {'email': 'me@example.com', 'secret': keys.authSecret}))['token'];
  final code = (await post('/api/invites', {}, token as String))['code'] as String;
  http.close();
  return code;
}
