import 'dart:async';
import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:brahma_core/src/sentinel/releases.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _Sync extends SyncController {
  _Sync(this.initial);
  final SyncState initial;
  @override
  SyncState build() => initial;
}

class _Snoozes extends Snoozes {
  _Snoozes(this.initial);
  final Map<String, String> initial;
  @override
  Future<Map<String, String>> build() async => initial;
}

class _Updates extends UpdateChecks {
  _Updates(this.on);
  final bool on;
  @override
  Future<bool> build() async => on;
}

const _app = AppIdentity(
  id: 'brahma',
  name: 'Brahma',
  androidPackage: 'dev.brahma.app',
  releases: 'o/brahma',
);

Map<String, Object?> _release(String tag, {bool draft = false}) => {
  'tag_name': tag,
  'draft': draft,
  'html_url': 'https://github.com/o/brahma/releases/tag/$tag',
};

ProviderContainer _container(List<Override> overrides) {
  final c = ProviderContainer(overrides: overrides, retry: (_, _) => null);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('versions compare number by number, ignoring v, pre-release and build parts', () {
    expect(isNewerVersion('0.10.0', '0.9.9'), isTrue);
    expect(isNewerVersion('v0.3.0', '0.2.0'), isTrue);
    expect(isNewerVersion('0.2.0-beta.1', '0.2.0'), isFalse);
    expect(isNewerVersion('0.2.0', '0.2.0+2'), isFalse);
    expect(isNewerVersion('0.2', '0.2.1'), isFalse);
  });

  test('the newest release counts pre-releases and skips drafts and odd links', () {
    final newest = newestInList([
      _release('v0.2.0'),
      _release('v0.4.0', draft: true),
      {'tag_name': 'v0.9.0', 'html_url': 'http://example.com'},
      _release('v0.3.0-beta.1'),
    ]);
    expect(newest?.version, '0.3.0-beta.1');
    expect(newestInList('not a list'), isNull);
  });

  test('the update banner offers the installer for this platform, from GitHub only', () {
    final assets = [
      for (final n in [
        'Brahma-0.3.0-android.apk',
        'Brahma-0.3.0-windows-x64-setup.exe',
        'Brahma-0.3.0-linux-x64.tar.gz',
      ])
        {'name': n, 'browser_download_url': 'https://github.com/o/brahma/releases/download/v0.3.0/$n'},
      {'name': 'evil-setup.exe', 'browser_download_url': 'https://evil.example/evil-setup.exe'},
    ];
    final list = [
      {..._release('v0.3.0'), 'body': 'Faster sync', 'assets': assets},
    ];
    expect(newestInList(list, os: 'android')!.download!.path, endsWith('android.apk'));
    expect(newestInList(list, os: 'windows')!.download!.path, endsWith('windows-x64-setup.exe'));
    expect(newestInList(list, os: 'linux')!.download, isNull);
    expect(newestInList(list, os: 'linux')!.notes, 'Faster sync');
    final onlyEvil = [
      {..._release('v0.3.0'), 'assets': assets.sublist(3)},
    ];
    expect(newestInList(onlyEvil, os: 'windows')!.download, isNull);
    final otherRepo = [
      {..._release('v0.3.0'), 'html_url': 'https://github.com/someone/else/releases/tag/v0.3.0'},
    ];
    expect(newestInList(otherRepo, repo: 'o/brahma'), isNull);
    expect(newestInList(list, os: 'android', repo: 'O/Brahma')!.download, isNotNull);
  });

  test('only plain http outside this machine and Tailscale is in clear', () {
    for (final (url, clear) in [
      ('https://sync.example.com', false),
      ('http://localhost:8090', false),
      ('http://127.0.0.1:8090', false),
      ('http://100.101.2.3:8090', false),
      ('http://[fd7a:115c:a1e0::1]:8090', false),
      ('http://box.tail1234.ts.net:8090', false),
      ('http://192.168.1.5:8090', true),
      ('http://box.local', true),
    ]) {
      expect(sentInClear(Uri.parse(url)), clear, reason: url);
    }
  });

  test('a service reached in clear is one warning, named for where to fix it', () {
    Finding? link(String url) => linkInClear(id: 'x.http', name: 'Vani hub', url: url, where: 'Settings');
    expect(link('https://hub.example.com'), isNull);
    expect(link(''), isNull);
    final f = link('http://192.168.1.5:8787')!;
    expect(f.id, 'x.http');
    expect(f.status, Status.warning);
    expect(f.title, 'Vani hub is reached without https');
    expect(f.steps, endsWith('in Settings.'));
  });

  group('sync check', () {
    Future<List<Finding>> run(SyncState s) =>
        _container([syncProvider.overrideWith(() => _Sync(s))]).read(syncCheck.findings.future);

    test('signed out, or synced today over https: nothing', () async {
      expect(await run(const SyncState(SyncPhase.signedOut)), isEmpty);
      final now = DateTime.now().toUtc().toIso8601String();
      expect(await run(SyncState(SyncPhase.idle, server: 'https://s.example.com', lastSync: now)), isEmpty);
    });

    test('a week without sync, and a LAN server over http, are both reported', () async {
      final old = DateTime.now().toUtc().subtract(const Duration(days: 9)).toIso8601String();
      final found = await run(
        SyncState(SyncPhase.failed, server: 'http://192.168.1.5', lastSync: old, error: 'Offline'),
      );
      expect(found.map((f) => f.id), ['sync.http', 'sync.stale']);
      expect(found.last.title, 'Not synced for 9 days');
      expect(found.last.why, endsWith('Last error: Offline'));
      expect(found.last.fix?.label, 'Sync now');
    });

    test('a first sync that keeps failing is reported, one still running is not', () async {
      expect(
        (await run(const SyncState(SyncPhase.failed, server: 'https://s.example.com'))).single.id,
        'sync.stale',
      );
      expect(await run(const SyncState(SyncPhase.running, server: 'https://s.example.com')), isEmpty);
    });
  });

  group('update check', () {
    setUp(
      () => PackageInfo.setMockInitialValues(
        appName: 'Brahma',
        packageName: 'dev.brahma.app',
        version: '0.2.0',
        buildNumber: '2',
        buildSignature: '',
      ),
    );

    ProviderContainer container(http.Client client, {bool on = true, AppIdentity app = _app}) => _container([
      appIdentityProvider.overrideWithValue(app),
      updateChecksProvider.overrideWith(() => _Updates(on)),
      releasesClientProvider.overrideWithValue(client),
    ]);

    final newer = MockClient((req) async {
      expect(req.url.path, '/repos/o/brahma/releases');
      return http.Response(jsonEncode([_release('v0.2.0'), _release('v0.3.0')]), 200);
    });

    test('a newer release is reported, per version', () async {
      final f = (await container(newer).read(updateCheck.findings.future)).single;
      expect(f.id, 'update.0.3.0');
      expect(f.title, 'Brahma 0.3.0 is out');
      expect(f.fix?.label, 'Download');
    });

    test('nothing is asked when turned off or the app has no releases', () async {
      final never = MockClient((_) => fail('GitHub was asked'));
      expect(await container(never, on: false).read(updateCheck.findings.future), isEmpty);
      const bare = AppIdentity(id: 'x', name: 'X', androidPackage: 'x');
      expect(await container(never, app: bare).read(updateCheck.findings.future), isEmpty);
    });

    test('the newest version already installed: nothing', () async {
      final same = MockClient((_) async => http.Response(jsonEncode([_release('v0.2.0')]), 200));
      expect(await container(same).read(updateCheck.findings.future), isEmpty);
    });
  });

  group('report', () {
    Finding finding(String id, Status status) => Finding(id: id, status: status, title: id, why: '');

    test('most severe first, failures as info, snoozed ones hidden and counted', () async {
      final waiting = Completer<List<Finding>>();
      final checks = [
        SecurityCheck(
          id: 'a',
          title: 'A',
          findings: FutureProvider(
            (_) async => [finding('a.warn', Status.warning), finding('a.off', Status.critical)],
          ),
        ),
        SecurityCheck(
          id: 'b',
          title: 'B',
          findings: FutureProvider((_) => throw CheckFailed('No connection.')),
        ),
        SecurityCheck(id: 'c', title: 'C', findings: FutureProvider((_) => waiting.future)),
        SecurityCheck(
          id: 'd',
          title: 'D',
          findings: FutureProvider((_) async => [finding('d.crit', Status.critical)]),
        ),
      ];
      final c = _container([
        sentinelChecksProvider.overrideWithValue(checks),
        snoozesProvider.overrideWith(() => _Snoozes({'a.off': '2999-01-01'})),
      ]);
      c.listen(sentinelProvider, (_, _) {});
      for (final check in checks.take(2)) {
        await c.read(check.findings.future).catchError((_) => <Finding>[]);
      }
      await c.read(checks[3].findings.future);
      await c.read(snoozesProvider.future);

      var r = c.read(sentinelProvider);
      expect(r.findings.map((f) => f.id), ['d.crit', 'a.warn', 'b.failed']);
      expect(r.findings.last.title, 'Could not check: B');
      expect(r.findings.last.why, 'No connection.');
      expect(r.snoozed, 1);
      expect(r.checking, isTrue);
      expect(r.toFix.length, 2);
      expect(r.status, Status.critical);

      waiting.complete(const []);
      await c.read(checks[2].findings.future);
      r = c.read(sentinelProvider);
      expect(r.checking, isFalse);
    });

    test('nothing found reads as all clear', () async {
      final c = _container([
        sentinelChecksProvider.overrideWithValue(const []),
        snoozesProvider.overrideWith(() => _Snoozes(const {})),
      ]);
      await c.read(snoozesProvider.future);
      final r = c.read(sentinelProvider);
      expect(r.status, Status.good);
      expect(sentinelSummary(r), 'All clear');
    });
  });
}
