import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../app/providers.dart';

/// A check that could not run, worded for the user.
class CheckFailed implements Exception, UserFacingError {
  CheckFailed(this.message);
  @override
  final String message;
  @override
  String toString() => message;
}

/// A published release: its version, page and notes, and the installer for
/// this platform when it has one (the Android APK or the Windows setup; Linux
/// builds are archives, so Linux gets the page).
typedef ReleaseInfo = ({String version, Uri page, String notes, Uri? download});

/// Which release file installs on [os] (Platform.operatingSystem).
bool installerFor(String os, String name) => switch (os) {
  'android' => name.endsWith('.apk'),
  'windows' => name.endsWith('-setup.exe'),
  _ => false,
};

/// "v0.10.2-beta.1" → [0, 10, 2]; anything after a '-' or '+' is dropped and
/// a part that is not a number counts as 0.
List<int> _parts(String version) => [
  for (final p in version.trim().replaceFirst(RegExp(r'^[vV]'), '').split(RegExp('[-+]')).first.split('.'))
    int.tryParse(p) ?? 0,
];

/// Whether [candidate] is newer than [current], number by number.
bool isNewerVersion(String candidate, String current) {
  final a = _parts(candidate), b = _parts(current);
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// Whether [url] is a page or file of [repo]'s GitHub releases, so a
/// tampered release list cannot send anyone elsewhere.
bool isReleaseUrl(Uri url, String? repo) =>
    url.scheme == 'https' &&
    url.host == 'github.com' &&
    (repo == null || url.path.toLowerCase().startsWith('/${repo.toLowerCase()}/releases/'));

/// The newest release in a GitHub releases list (pre-releases count, since
/// every v0.* release is one; drafts do not). With [repo], only links into
/// that repository's releases are kept.
ReleaseInfo? newestInList(Object? list, {String? os, String? repo}) {
  final platform = os ?? Platform.operatingSystem;
  ReleaseInfo? best;
  for (final r in list is List ? list : const []) {
    if (r is! Map || r['draft'] == true) continue;
    final version = '${r['tag_name'] ?? ''}'.replaceFirst(RegExp(r'^[vV]'), '');
    final page = Uri.tryParse('${r['html_url'] ?? ''}');
    if (version.isEmpty || page == null || !isReleaseUrl(page, repo)) continue;
    if (best != null && !isNewerVersion(version, best.version)) continue;
    Uri? download;
    for (final a in r['assets'] is List ? r['assets'] as List : const []) {
      final url = a is Map ? Uri.tryParse('${a['browser_download_url'] ?? ''}') : null;
      if (url != null &&
          url.scheme == 'https' &&
          url.host == 'github.com' &&
          installerFor(platform, '${a['name']}')) {
        download = url;
        break;
      }
    }
    best = (version: version, page: page, notes: '${r['body'] ?? ''}'.trim(), download: download);
  }
  return best;
}

/// The newest release of the GitHub repository [repo] ("owner/name").
Future<ReleaseInfo?> fetchNewestRelease(http.Client client, String repo) async {
  final http.Response response;
  try {
    response = await client
        .get(
          // The list, not /releases/latest: that one skips pre-releases.
          Uri.https('api.github.com', '/repos/$repo/releases', {'per_page': '20'}),
          headers: {'accept': 'application/vnd.github+json', 'user-agent': 'Brahma Sentinel'},
        )
        .timeout(const Duration(seconds: 20));
  } on TimeoutException {
    throw CheckFailed('GitHub did not answer in time.');
  } on SocketException {
    throw CheckFailed('No connection to GitHub.');
  } on http.ClientException catch (e) {
    throw CheckFailed('No connection to GitHub: ${e.message}');
  }
  if (response.statusCode != 200) throw CheckFailed('GitHub answered with error ${response.statusCode}.');
  return newestInList(jsonDecode(utf8.decode(response.bodyBytes)), repo: repo);
}
