import 'dart:convert';
import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _repo = 'example/app';
const _app = AppIdentity(id: 'example', name: 'Example', releases: _repo, androidPackage: 'dev.example.app');

String _dl(String name) => 'https://github.com/$_repo/releases/download/v0.2.0/$name';

Map<String, Object?> _release(String tag, {Map<String, String> assets = const {}, bool draft = false}) => {
  'tag_name': tag,
  'html_url': 'https://github.com/$_repo/releases/tag/$tag',
  'body': 'Notes for $tag',
  'draft': draft,
  'assets': [
    for (final MapEntry(:key, :value) in assets.entries)
      {'name': key, 'browser_download_url': value, 'size': 3},
  ],
};

void main() {
  test('the newest release wins; drafts and links elsewhere are dropped', () {
    final r = newestReleaseIn([
      _release('v0.1.0'),
      _release('v0.3.0', draft: true),
      _release(
        'v0.2.0',
        assets: {
          'Example-0.2.0-linux-x64.tar.gz': _dl('Example-0.2.0-linux-x64.tar.gz'),
          'Example-0.2.0-android.apk': 'https://evil.example/Example-0.2.0-android.apk',
        },
      ),
    ], _repo)!;
    expect(r.version, '0.2.0');
    expect(r.installerFor('linux')?.name, 'Example-0.2.0-linux-x64.tar.gz');
    expect(r.installerFor('android'), isNull);
    expect(newestReleaseIn('not a list', _repo), isNull);
  });

  test('checksum files are read in both styles', () {
    final a = 'a' * 64, b = 'B' * 64;
    expect(parseChecksums('$a  one.apk\n$b *two.exe\nnot a line\n'), {'one.apk': a, 'two.exe': 'b' * 64});
  });

  group('download and install', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('brahma-update'));
    tearDown(() => dir.delete(recursive: true));

    AppUpdater updater(List<int> file, {String? sum, List<List<String>>? ran}) {
      const name = 'Example-0.2.0-linux-x64.tar.gz';
      final client = MockClient((req) async {
        final url = '${req.url}';
        if (url.startsWith('https://api.github.com/')) {
          return http.Response(
            jsonEncode([
              _release('v0.2.0', assets: {name: _dl(name), 'SHA256SUMS.txt': _dl('SHA256SUMS.txt')}),
            ]),
            200,
          );
        }
        if (url == _dl('SHA256SUMS.txt'))
          return http.Response('${sum ?? sha256.convert(file)}  $name\n', 200);
        if (url == _dl(name)) return http.Response.bytes(file, 200);
        return http.Response('', 404);
      });
      return AppUpdater(
        client,
        app: _app,
        current: '0.1.0',
        dir: Directory('${dir.path}/updates'),
        os: 'linux',
        run: (exe, args) {
          ran?.add([exe, ...args]);
          return Process.run(exe, args);
        },
      );
    }

    test('a newer release downloads, is checked and installs with install.sh', () async {
      // A release archive as the Linux build makes it: one folder holding install.sh.
      final src = Directory('${dir.path}/src/Example-0.2.0')..createSync(recursive: true);
      final marker = '${dir.path}/installed';
      File('${src.path}/install.sh')
        ..writeAsStringSync('#!/bin/sh\necho ok > "$marker"\n')
        ..setLastModifiedSync(DateTime(2026));
      await Process.run('chmod', ['+x', '${src.path}/install.sh']);
      final tar = '${dir.path}/a.tar.gz';
      expect((await Process.run('tar', ['czf', tar, '-C', '${dir.path}/src', 'Example-0.2.0'])).exitCode, 0);
      final bytes = File(tar).readAsBytesSync();

      final ran = <List<String>>[];
      final u = updater(bytes, ran: ran);
      final release = (await u.check())!;
      final progress = <double>[];
      final file = await u.download(release, onProgress: progress.add);
      expect(file.readAsBytesSync(), bytes);
      expect(progress.last, 1);
      expect(await u.install(file), isTrue);
      expect(File(marker).readAsStringSync().trim(), 'ok');
      expect(ran.last.single, endsWith('/install.sh'));
      expect(file.existsSync(), isFalse);
    });

    test('a download that does not match its checksum is thrown away', () async {
      final u = updater([1, 2, 3], sum: '0' * 64);
      final release = (await u.check())!;
      await expectLater(
        u.download(release),
        throwsA(isA<UpdateException>().having((e) => e.message, 'message', contains('checksum'))),
      );
      expect(Directory('${dir.path}/updates').listSync(), isEmpty);
    });

    test('no update when this build is the newest', () async {
      final u = AppUpdater(
        MockClient((_) async => http.Response(jsonEncode([_release('v0.1.0')]), 200)),
        app: _app,
        current: '0.1.0',
        dir: dir,
        os: 'linux',
      );
      expect(await u.check(), isNull);
    });
  });
}
