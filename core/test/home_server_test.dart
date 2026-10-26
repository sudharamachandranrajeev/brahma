// Runs the real home server (../server/src/home.ts, Node 24+) on a throwaway
// data folder and drives core against it: the plain-language server check,
// the account service, the server's backup time and the setup wizard.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _app = AppIdentity(id: 'brahma', name: 'Brahma', androidPackage: 'dev.brahma.app');

AccountService _device(String id) =>
    AccountService(KeyVault(MemorySecretStore(), _app), deviceId: id * 32, platform: 'linux');

void main() {
  late Directory dir;
  late Process server;
  late String url, setupCode;
  final home = '${Directory.current.parent.path}/server/src/home.ts';
  final v = Process.runSync('node', ['--version']);
  final major = int.tryParse(RegExp(r'v(\d+)').firstMatch('${v.stdout}')?.group(1) ?? '') ?? 0;
  final skip = v.exitCode != 0 || major < 24 ? 'Needs Node 24 or newer' : null;

  Future<ProcessResult> run(List<String> args) =>
      Process.run('node', [home, ...args], environment: {'BRAHMA_SERVER_HOME': dir.path});

  setUpAll(() async {
    // The test binding fakes HTTP; these tests need the real thing.
    HttpOverrides.global = null;
    if (skip != null) return;
    dir = await Directory.systemTemp.createTemp('brahma-home-test-');
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    expect((await run(['init', '$port'])).exitCode, 0);
    setupCode = RegExp(
      r'^SETUP_CODE=(.+)$',
      multiLine: true,
    ).firstMatch(await File('${dir.path}/server.env').readAsString())!.group(1)!;
    server = await Process.start('node', [home, 'serve'], environment: {'BRAHMA_SERVER_HOME': dir.path});
    final ready = Completer<void>();
    server.stdout.transform(utf8.decoder).listen((t) {
      if (t.contains('listening') && !ready.isCompleted) ready.complete();
    });
    server.stderr.transform(utf8.decoder).listen(stderr.write);
    await ready.future.timeout(const Duration(seconds: 20));
    url = 'http://127.0.0.1:$port';
  });

  tearDownAll(() async {
    if (skip != null) return;
    server.kill();
    await server.exitCode;
    await dir.delete(recursive: true);
  });

  test('addresses people type are completed', () {
    expect(completeServerAddress('192.168.1.20'), 'http://192.168.1.20:8090');
    expect(completeServerAddress('100.101.102.103:8091/'), 'http://100.101.102.103:8091');
    expect(completeServerAddress('homeserver.local'), 'http://homeserver.local:8090');
    expect(completeServerAddress('sync.example.com'), 'https://sync.example.com');
    expect(completeServerAddress('https://x.workers.dev'), 'https://x.workers.dev');
  });

  test('the check finds a home server waiting for its owner', () async {
    final c = await checkServer(url, place: ServerPlace.home);
    expect(c.ok, isTrue);
    expect(c.info!.kind, ServerKind.home);
    expect(c.info!.needsSetup, isTrue);
    expect(c.info!.describe, startsWith('Home server "'));
  }, skip: skip);

  test('problems are explained in plain words', () async {
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    final refused = await checkServer('http://127.0.0.1:$port', place: ServerPlace.home);
    expect(refused.problem, contains("isn't running"));
    expect(refused.fix, contains('install.sh --status'));

    final public = await checkServer('http://example.com', place: ServerPlace.cloud);
    expect(public.problem, contains("can't be used"));
    expect(public.fix, contains('https://'));
  }, skip: skip);

  test('two devices share an account; the owner sees the last backup', () async {
    final a = _device('a'), b = _device('b');
    await a.signUp(server: url, email: 'me@home.test', password: 'correct horse battery', invite: setupCode);
    expect(await (await a.api()).isOwner(), isTrue);
    expect(await (await a.api()).lastBackup(), isNull);
    expect((await run(['backup'])).exitCode, 0);
    final backup = await (await a.api()).lastBackup();
    expect(DateTime.now().difference(backup!).inMinutes, lessThan(5));

    await b.signIn(server: url, email: 'me@home.test', password: 'correct horse battery');
    expect(await (await b.api()).isOwner(), isTrue);
    expect((await checkServer(url)).info!.needsSetup, isFalse);
  }, skip: skip);

  testWidgets('the wizard: device only, or sync through a home server', (tester) async {
    HttpOverrides.global = null;
    bool? finished;
    Future<void> show() => tester.pumpWidget(
      ProviderScope(
        overrides: [appIdentityProvider.overrideWithValue(_app)],
        child: MaterialApp(home: SyncSetupWizard(onFinished: (v) => finished = v)),
      ),
    );

    await show();
    expect(find.text('Welcome to Brahma'), findsOneWidget);
    await tester.tap(find.text('Keep everything on this device'));
    expect(finished, isFalse);

    await show();
    await tester.tap(find.text('Sync across my devices'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home server'));
    await tester.pumpAndSettle();
    expect(find.textContaining('./install.sh'), findsWidgets);
    await tester.ensureVisible(find.text("I've done this, connect"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I've done this, connect"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), url);
    await tester.tap(find.text('Check server'));
    for (var i = 0; i < 50 && find.textContaining('Found:').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(find.textContaining('Found: Home server'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  }, skip: skip != null);
}
