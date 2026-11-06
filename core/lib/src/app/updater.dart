import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../identity.dart';
import '../sentinel/releases.dart';
import 'providers.dart';

/// The in-app updater: finds a newer release of a standalone app on GitHub,
/// downloads this device's file, checks it against the release's
/// SHA256SUMS.txt and installs it. Nothing is installed that does not match.
///
/// Each app opts in by overriding [updaterProvider] in its own main(), in a
/// release build. The Brahma Suite app hosts modules without one, since the
/// Suite updates itself.

/// A failure updating, worded for the user.
class UpdateException implements Exception, UserFacingError {
  UpdateException(this.message);
  @override
  final String message;
  @override
  String toString() => message;
}

/// The file each release publishes its checksums in.
const checksumsName = 'SHA256SUMS.txt';

typedef ReleaseAsset = ({String name, Uri url, int size});

/// A published release with its files.
class Release {
  const Release({required this.version, required this.page, required this.notes, required this.assets});

  final String version;
  final Uri page;
  final String notes;
  final Map<String, ReleaseAsset> assets;

  /// The file that installs on [os], when the release has one: the APK, the
  /// Windows setup, or the Linux archive (which carries install.sh).
  ReleaseAsset? installerFor(String os) {
    final suffix = switch (os) {
      'android' => '-android.apk',
      'windows' => '-windows-x64-setup.exe',
      'linux' => '-linux-x64.tar.gz',
      _ => null,
    };
    if (suffix == null) return null;
    return assets.values.where((a) => a.name.endsWith(suffix)).firstOrNull;
  }
}

/// The newest release in GitHub's list for [repo] (pre-releases count, since
/// every v0.* release is one; drafts do not). Links outside [repo]'s releases
/// are dropped, so a tampered list cannot send a download elsewhere.
Release? newestReleaseIn(Object? list, String repo) {
  Release? best;
  for (final r in list is List ? list : const []) {
    if (r is! Map || r['draft'] == true) continue;
    final version = '${r['tag_name'] ?? ''}'.replaceFirst(RegExp(r'^[vV]'), '');
    final page = Uri.tryParse('${r['html_url'] ?? ''}');
    if (version.isEmpty || page == null || !isReleaseUrl(page, repo)) continue;
    if (best != null && !isNewerVersion(version, best.version)) continue;
    best = Release(
      version: version,
      page: page,
      notes: '${r['body'] ?? ''}'.trim(),
      assets: {
        for (final a in r['assets'] is List ? r['assets'] as List : const [])
          if (a is Map)
            if (Uri.tryParse('${a['browser_download_url'] ?? ''}') case final url?
                when isReleaseUrl(url, repo))
              '${a['name']}': (name: '${a['name']}', url: url, size: (a['size'] as num?)?.toInt() ?? 0),
      },
    );
  }
  return best;
}

/// SHA256SUMS.txt as file name → checksum (`sum  name` or `sum *name` lines).
Map<String, String> parseChecksums(String text) => {
  for (final line in const LineSplitter().convert(text))
    if (RegExp(r'^([0-9a-fA-F]{64})\s+\*?(\S.*)$').firstMatch(line.trim()) case final m?)
      m[2]!.trim(): m[1]!.toLowerCase(),
};

/// Downloads, checks and installs updates of one app from its GitHub releases.
class AppUpdater {
  AppUpdater(
    this._http, {
    required this.app,
    required this.current,
    required this.dir,
    String? os,
    String? executable,
    Future<ProcessResult> Function(String exe, List<String> args)? run,
  }) : os = os ?? Platform.operatingSystem,
       executable = executable ?? Platform.resolvedExecutable,
       _run = run ?? Process.run;

  final http.Client _http;
  final AppIdentity app;

  /// This build's version.
  final String current;

  /// Where downloads go. On Android the FileProvider shares the APK from here.
  final Directory dir;

  /// android, windows or linux.
  final String os;

  /// The running program; on Linux install.sh replaces it in place, so the
  /// same path starts the new version.
  final String executable;
  final Future<ProcessResult> Function(String exe, List<String> args) _run;

  Map<String, String> get _agent => {'user-agent': app.name};

  String get _repo => app.releases ?? (throw UpdateException('${app.name} has no releases to update from.'));

  /// The newest release when it is newer than this build and has a file for
  /// this device, otherwise null.
  Future<Release?> check() async {
    final response = await _send(
      Uri.https('api.github.com', '/repos/$_repo/releases', {'per_page': '20'}),
      headers: {'accept': 'application/vnd.github+json'},
    );
    final body = await response.stream.toBytes().timeout(const Duration(seconds: 30));
    final r = newestReleaseIn(jsonDecode(utf8.decode(body)), _repo);
    return r != null && isNewerVersion(r.version, current) && r.installerFor(os) != null ? r : null;
  }

  /// Downloads this device's file of [release] and checks it against the
  /// published checksum. [onProgress] hears 0 to 1.
  Future<File> download(Release release, {void Function(double done)? onProgress}) async {
    final asset = release.installerFor(os);
    final sums = release.assets[checksumsName];
    if (asset == null) throw UpdateException('${app.name} ${release.version} has no file for this device.');
    if (sums == null) {
      throw UpdateException(
        '${app.name} ${release.version} publishes no checksums, so it is not installed from here.',
      );
    }
    final sumsBody = await (await _send(sums.url)).stream.toBytes().timeout(const Duration(seconds: 30));
    final expected = parseChecksums(utf8.decode(sumsBody))[asset.name];
    if (expected == null) throw UpdateException('${asset.name} is missing from the release checksums.');

    await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}${asset.name}');
    final part = File('${file.path}.part');
    final response = await _send(asset.url);
    final total = response.contentLength ?? asset.size;
    final sink = part.openWrite();
    var got = 0;
    try {
      await for (final bytes in response.stream.timeout(const Duration(seconds: 60))) {
        sink.add(bytes);
        got += bytes.length;
        if (total > 0) onProgress?.call((got / total).clamp(0, 1));
      }
      await sink.close();
    } on Object catch (e) {
      await sink.close().catchError((_) {});
      if (await part.exists()) await part.delete();
      if (e is TimeoutException || e is SocketException || e is http.ClientException) {
        throw UpdateException('The download stopped. Try again.');
      }
      rethrow;
    }
    // Hashed as it is read, so a large file is never held in memory.
    final actual = (await sha256.bind(part.openRead()).first).toString();
    if (actual != expected) {
      await part.delete();
      throw UpdateException('The download did not match its checksum, so it was not installed.');
    }
    return part.rename(file.path);
  }

  /// Installs a checked [file]. Android opens its installer; Windows runs the
  /// setup, which closes this copy; Linux runs the archive's install.sh,
  /// which swaps the new version in for the next start. Returns whether the
  /// app should offer a restart (Linux).
  Future<bool> install(File file) async {
    switch (os) {
      case 'android':
        await MethodChannel(app.updateChannel).invokeMethod<bool>('installApk', {'path': file.path});
        return false;
      case 'windows':
        // The setup closes this copy and offers to start the new one.
        await Process.start(file.path, const ['/CURRENTUSER', '/NORESTART'], mode: ProcessStartMode.detached);
        exit(0);
      case 'linux':
        final into = Directory('${dir.path}/unpacked');
        if (await into.exists()) await into.delete(recursive: true);
        await into.create(recursive: true);
        try {
          await _ok('tar', ['xzf', file.path, '-C', into.path]);
          final unpacked = into.listSync().whereType<Directory>().firstOrNull;
          final script = unpacked == null ? null : File('${unpacked.path}/install.sh');
          if (script == null || !script.existsSync()) {
            throw UpdateException('The download held no ${app.name} installer.');
          }
          await _ok(script.path, const []);
        } finally {
          if (await into.exists()) await into.delete(recursive: true);
          if (await file.exists()) await file.delete();
        }
        return true;
    }
    throw UpdateException('${app.name} cannot update itself on $os.');
  }

  /// Starts the installed copy and closes this one (Linux, after [install]).
  Future<Never> restart() async {
    await Process.start(executable, const [], mode: ProcessStartMode.detached);
    exit(0);
  }

  Future<void> _ok(String exe, List<String> args) async {
    final r = await _run(exe, args);
    if (r.exitCode != 0) {
      final why = '${r.stderr}'.trim().split('\n').last;
      throw UpdateException('Installing failed${why.isEmpty ? '' : ': $why'}');
    }
  }

  Future<http.StreamedResponse> _send(Uri url, {Map<String, String> headers = const {}}) async {
    try {
      final r = await _http
          .send(http.Request('GET', url)..headers.addAll({..._agent, ...headers}))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) {
        r.stream.listen(null).cancel().ignore();
        throw UpdateException('GitHub answered with error ${r.statusCode}.');
      }
      return r;
    } on TimeoutException {
      throw UpdateException('GitHub did not answer in time.');
    } on SocketException {
      throw UpdateException('No connection to GitHub. Check the internet connection.');
    } on http.ClientException catch (e) {
      throw UpdateException('No connection to GitHub: ${e.message}');
    }
  }
}

/// This app's updater, set by a standalone app's main() in a release build.
/// Null in tests, debug builds and modules hosted by the Brahma Suite app.
final updaterProvider = Provider<AppUpdater?>((ref) => null);
