import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:brahma_core/brahma_core.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// A failed hub call, worded for the user. [problems] lists what the hub
/// found wrong with what was sent (a post too long for Bluesky...).
class HubException implements Exception, UserFacingError {
  HubException(this.error, {this.status = 0, this.problems = const []});
  final String error;
  final int status;
  final List<String> problems;

  @override
  String get message => problems.isEmpty ? error : '$error\n• ${problems.join('\n• ')}';

  @override
  String toString() => message;
}

/// No hub address and token yet (Settings > Hub).
class NoHubException implements Exception, UserFacingError {
  @override
  String get message => 'Connect your social hub in Settings first.';
}

/// The social hub's address and API token, as kept in synced prefs.
class HubLink {
  const HubLink({this.url = '', this.token = ''});
  final String url, token;
  bool get ready => url.isNotEmpty && token.isNotEmpty;

  factory HubLink.fromJson(Json j) => HubLink(url: str(j['url']), token: str(j['token']));
  Json toJson() => {'url': url, 'token': token};

  /// What is wrong with [url], or null. Plain http only for the user's own
  /// network, never the public internet.
  static String? checkUrl(String url) {
    final u = Uri.tryParse(url.trim());
    if (u == null || !u.hasScheme || u.host.isEmpty) {
      return 'Enter the hub address, e.g. https://brahma-watch.you.workers.dev';
    }
    if (u.scheme == 'https') return null;
    if (u.scheme == 'http' && _local(u.host)) return null;
    return 'Use https (plain http only works on your own network).';
  }

  static bool _local(String host) =>
      host == 'localhost' ||
      host.endsWith('.local') ||
      host.endsWith('.ts.net') ||
      RegExp(r'^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|100\.)').hasMatch(host);
}

typedef DiscoveryRun = ({List<Find> finds, List<Alert> alerts, List<String> errors});

/// Every call of the social hub's HTTP API (watch/SOCIAL.md).
class HubClient {
  HubClient(
    String url,
    this.token, {
    this.profile = Profile.main,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : base = Uri.parse(url.trim().replaceAll(RegExp(r'/+$'), '')),
       _http = client ?? http.Client();

  final Uri base;
  final String token;

  /// The profile every call works in (profile management is hub-wide).
  final String profile;
  final Duration timeout;
  final http.Client _http;

  Uri _uri(String path, [Map<String, String?> query = const {}]) {
    final q = {
      for (final e in query.entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    return base.replace(path: '${base.path}$path', queryParameters: q.isEmpty ? null : q);
  }

  Map<String, String> get _headers => {
    'authorization': 'Bearer $token',
    'accept': 'application/json',
    if (profile != Profile.main) 'x-vani-profile': profile,
  };

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String?> query = const {},
    Duration? wait,
  }) async {
    final req = http.Request(method, _uri(path, query))..headers.addAll(_headers);
    if (body is Uint8List) {
      req.headers['content-type'] = 'application/octet-stream';
      req.bodyBytes = body;
    } else if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(wait ?? timeout));
    } on TimeoutException {
      throw HubException('The hub did not answer in time. Check your connection and try again.');
    } on SocketException catch (e) {
      throw HubException('Cannot reach the hub at ${base.host}: ${e.message}');
    } on http.ClientException catch (e) {
      throw HubException('Cannot reach the hub at ${base.host}: ${e.message}');
    }
    final text = res.body;
    Object? data;
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } on FormatException {
        data = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    final j = obj(data);
    final error =
        strOrNull(j['error']) ??
        switch (res.statusCode) {
          401 => 'The hub refused the API token. Check it in Settings.',
          404 => 'The hub does not know $path. Is it up to date?',
          _ => 'The hub answered ${res.statusCode}.',
        };
    throw HubException(error, status: res.statusCode, problems: strs(j['problems']));
  }

  Future<Json> _obj(
    String method,
    String path, {
    Object? body,
    Map<String, String?> query = const {},
  }) async => obj(await _send(method, path, body: body, query: query));

  Future<List<Json>> _list(String path, {Map<String, String?> query = const {}}) async =>
      objs(await _send('GET', path, query: query));

  // ---- overview, meta, credentials ----

  Future<Overview> overview() async => Overview.fromJson(await _obj('GET', '/social/overview'));

  Future<HubMeta> meta() async => HubMeta.fromJson(await _obj('GET', '/social/meta'));

  Future<List<CredentialStatus>> credentials() async => [
    for (final c in await _list('/social/credentials')) CredentialStatus.fromJson(c),
  ];

  Future<void> setCredential(CredentialProvider p, {String? publicId, required String secret}) =>
      _send('PUT', '/social/credentials/${p.name}', body: {'publicId': ?publicId, 'secret': secret});

  Future<void> deleteCredential(CredentialProvider p) => _send('DELETE', '/social/credentials/${p.name}');

  // ---- profiles ----

  Future<List<Profile>> profiles() async => [
    for (final j in await _list('/social/profiles')) Profile.fromJson(j),
  ];

  Future<Profile> addProfile(String name) async =>
      Profile.fromJson(await _obj('POST', '/social/profiles', body: {'name': name}));

  Future<Profile> renameProfile(String id, String name) async =>
      Profile.fromJson(await _obj('PATCH', '/social/profiles/$id', body: {'name': name}));

  /// Refused while the profile has accounts.
  Future<void> deleteProfile(String id) => _send('DELETE', '/social/profiles/$id');

  // ---- accounts ----

  Future<List<Account>> accounts() async => [
    for (final a in await _list('/social/accounts')) Account.fromJson(a),
  ];

  /// The sign-in page to open in a browser.
  Future<String> connect(OAuthProvider p) async =>
      str((await _obj('POST', '/social/connect/${p.name}'))['url']);

  Future<Account> addBluesky({required String handle, required String appPassword, String? service}) async =>
      Account.fromJson(
        await _obj(
          'POST',
          '/social/accounts/bluesky',
          body: {'handle': handle, 'appPassword': appPassword, 'service': ?service},
        ),
      );

  Future<Account> addMastodon({required String instance, required String accessToken}) async =>
      Account.fromJson(
        await _obj(
          'POST',
          '/social/accounts/mastodon',
          body: {'instance': instance, 'accessToken': accessToken},
        ),
      );

  /// [chat]: @channel, a t.me link or a chat id.
  Future<Account> addTelegram({required String botToken, required String chat}) async => Account.fromJson(
    await _obj('POST', '/social/accounts/telegram', body: {'botToken': botToken, 'chat': chat}),
  );

  Future<Account> checkAccount(String id) async =>
      Account.fromJson(await _obj('POST', '/social/accounts/$id/check'));

  Future<void> removeAccount(String id) => _send('DELETE', '/social/accounts/$id');

  // ---- media ----

  Future<List<MediaItem>> media() async => [
    for (final m in await _list('/social/media')) MediaItem.fromJson(m),
  ];

  Future<MediaItem> setAlt(String id, String alt) async =>
      MediaItem.fromJson(await _obj('PATCH', '/social/media/$id', body: {'alt': alt}));

  /// Claude drafts alt text (saved on the hub); [context] is the post's text.
  Future<MediaItem> describeMedia(String id, {String? context}) async => MediaItem.fromJson(
    await _obj(
      'POST',
      '/social/media/$id/alt',
      body: {if (context != null && context.isNotEmpty) 'context': context},
    ),
  );

  Future<void> deleteMedia(String id) => _send('DELETE', '/social/media/$id');

  /// Uploads [file] in parts; [onProgress] gets 0..1.
  Future<MediaItem> uploadFile(File file, {String? contentType, void Function(double)? onProgress}) async {
    final size = await file.length();
    final raf = await file.open();
    try {
      return await _upload(file.uri.pathSegments.last, contentType ?? contentTypeFor(file.path), size, (
        offset,
        length,
      ) async {
        await raf.setPosition(offset);
        return raf.read(length);
      }, onProgress);
    } finally {
      await raf.close();
    }
  }

  Future<MediaItem> uploadBytes(
    String filename,
    String contentType,
    Uint8List bytes, {
    void Function(double)? onProgress,
  }) => _upload(
    filename,
    contentType,
    bytes.length,
    (offset, length) async => Uint8List.sublistView(bytes, offset, offset + length),
    onProgress,
  );

  Future<MediaItem> _upload(
    String filename,
    String contentType,
    int size,
    Future<Uint8List> Function(int offset, int length) read,
    void Function(double)? onProgress,
  ) async {
    final start = await _obj(
      'POST',
      '/social/media',
      body: {'filename': filename, 'contentType': contentType, 'size': size},
    );
    final media = MediaItem.fromJson(obj(start['media']));
    final partSize = integer(start['partSize'], 8 * 1024 * 1024);
    if (partSize <= 0) throw HubException('The hub gave an invalid part size.');
    final parts = <Json>[];
    var offset = 0, n = 1;
    onProgress?.call(0);
    do {
      final length = (size - offset).clamp(0, partSize);
      final bytes = await read(offset, length);
      final res = obj(
        await _send(
          'PUT',
          '/social/media/${media.id}/parts/$n',
          body: bytes,
          wait: const Duration(minutes: 5),
        ),
      );
      parts.add({'n': n, 'etag': str(res['etag'])});
      offset += length;
      n++;
      onProgress?.call(size == 0 ? 1 : offset / size);
    } while (offset < size);
    return MediaItem.fromJson(
      await _obj('POST', '/social/media/${media.id}/complete', body: {'parts': parts}),
    );
  }

  // ---- posts ----

  Future<List<Post>> posts({String? from, String? to, String? status}) async => [
    for (final p in await _list('/social/posts', query: {'from': from, 'to': to, 'status': status}))
      Post.fromJson(p),
  ];

  Future<Post> createPost(PostInput input) async =>
      Post.fromJson(await _obj('POST', '/social/posts', body: input.toJson()));

  Future<Post> updatePost(String id, PostInput input) async =>
      Post.fromJson(await _obj('PUT', '/social/posts/$id', body: input.toJson()));

  Future<void> deletePost(String id) => _send('DELETE', '/social/posts/$id');

  Future<Post> publishPost(String id) async => Post.fromJson(await _obj('POST', '/social/posts/$id/publish'));

  Future<Post> retryPost(String id, {bool force = false}) async =>
      Post.fromJson(await _obj('POST', '/social/posts/$id/retry', body: {if (force) 'force': true}));

  // ---- inbox ----

  Future<InboxPage> inbox({
    String? status,
    Platform? platform,
    String? kind,
    String? accountId,
    String? triage,
    String? before,
    int? limit,
  }) async {
    final j = await _obj(
      'GET',
      '/social/inbox',
      query: {
        'status': status,
        'platform': platform?.name,
        'kind': kind,
        'accountId': accountId,
        'triage': triage,
        'before': before,
        'limit': limit?.toString(),
      },
    );
    return InboxPage([
      for (final i in objs(j['items'])) InboxItem.fromJson(i),
    ], InboxCounts.fromJson(obj(j['counts'])));
  }

  Future<InboxItem> setInboxStatus(String id, String status) async =>
      InboxItem.fromJson(await _obj('PATCH', '/social/inbox/$id', body: {'status': status}));

  Future<void> bulkInbox(List<String> ids, String status) =>
      _send('POST', '/social/inbox/bulk', body: {'ids': ids, 'status': status});

  Future<InboxItem> reply(String id, String text, {bool private = false}) async => InboxItem.fromJson(
    await _obj('POST', '/social/inbox/$id/reply', body: {'text': text, if (private) 'private': true}),
  );

  Future<List<String>> suggestReplies(String id) async =>
      strs((await _obj('POST', '/social/inbox/$id/suggest'))['suggestions']);

  Future<InboxItem> translateItem(String id) async =>
      InboxItem.fromJson(await _obj('POST', '/social/inbox/$id/translate'));

  /// [action]: hide | unhide | delete.
  Future<InboxItem> moderate(String id, String action) async =>
      InboxItem.fromJson(await _obj('POST', '/social/inbox/$id/moderate', body: {'action': action}));

  Future<int> refreshInbox() async => integer((await _obj('POST', '/social/inbox/refresh'))['items']);

  // ---- content ----

  Future<List<Content>> content({String? accountId, int? limit}) async => [
    for (final c in await _list(
      '/social/content',
      query: {'accountId': accountId, 'limit': limit?.toString()},
    ))
      Content.fromJson(c),
  ];

  // ---- rules, discovery, alerts ----

  Future<List<InboxRule>> rules() async => [
    for (final r in await _list('/social/rules')) InboxRule.fromJson(r),
  ];

  Future<List<InboxRule>> saveRules(List<InboxRule> rules) async => [
    for (final r in objs(await _send('PUT', '/social/rules', body: [for (final r in rules) r.toJson()])))
      InboxRule.fromJson(r),
  ];

  Future<List<DiscoveryWatch>> discovery() async => [
    for (final w in await _list('/social/discovery')) DiscoveryWatch.fromJson(w),
  ];

  Future<List<DiscoveryWatch>> saveDiscovery(List<DiscoveryWatch> watches) async => [
    for (final w in objs(
      await _send('PUT', '/social/discovery', body: [for (final w in watches) w.toJson()]),
    ))
      DiscoveryWatch.fromJson(w),
  ];

  Future<DiscoveryWatch> suggestDiscovery(String description, {String? postcode}) async =>
      DiscoveryWatch.fromJson(
        await _obj(
          'POST',
          '/social/discovery/suggest',
          body: {'description': description, 'postcode': ?postcode},
        ),
      );

  /// Runs a watch now: what it found, the alerts raised, and the sources
  /// that failed.
  Future<DiscoveryRun> runDiscovery(String id) async {
    final j = await _obj('POST', '/social/discovery/$id/run');
    return (
      finds: [for (final f in objs(j['finds'])) Find.fromJson(f)],
      alerts: [for (final a in objs(j['alerts'])) Alert.fromJson(a)],
      errors: strs(j['errors']),
    );
  }

  Future<List<Alert>> alerts({String? since, bool unread = false}) async => [
    for (final a in await _list('/social/alerts', query: {'since': since, if (unread) 'unread': 'true'}))
      Alert.fromJson(a),
  ];

  /// Marks [ids] read, or every alert when null.
  Future<void> markAlertsRead([List<String>? ids]) =>
      _send('POST', '/social/alerts/read', body: {'ids': ?ids});

  // ---- stats, settings, AI ----

  Future<Stats> stats() async => Stats.fromJson(await _obj('GET', '/social/stats'));

  Future<HubSettings> settings() async => HubSettings.fromJson(await _obj('GET', '/social/settings'));

  Future<HubSettings> saveSettings(HubSettings s) async =>
      HubSettings.fromJson(await _obj('PUT', '/social/settings', body: s.toJson()));

  Future<CaptionResult> caption(String brief, List<Platform> platforms, {String? tone}) async {
    final j = await _obj(
      'POST',
      '/social/ai/caption',
      body: {
        'brief': brief,
        'platforms': [for (final p in platforms) p.name],
        'tone': ?tone,
      },
    );
    return CaptionResult({
      for (final e in obj(j['variants']).entries)
        if (Platform.values.any((p) => p.name == e.key)) Platform.parse(e.key): str(e.value),
    }, strs(j['hashtags']));
  }

  /// Translates [text] into [to] (a language name).
  Future<String> translate(String text, String to) async =>
      str((await _obj('POST', '/social/ai/translate', body: {'text': text, 'to': to}))['text']);

  /// Makes the weekly summary now; it also arrives as a push.
  Future<Alert> weeklySummary() async => Alert.fromJson(await _obj('POST', '/social/ai/weekly'));

  Future<List<Idea>> ideas() async => parseIdeas(await _obj('GET', '/social/ai/ideas'));

  /// Sends a test push to the phone (Brahma Watch's ntfy topic).
  Future<void> testNotify() => _send('POST', '/test-notify');
}

/// The MIME type for a file name, for the media types platforms take.
String contentTypeFor(String path) {
  final ext = path.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'mp4' || 'm4v' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    _ => 'application/octet-stream',
  };
}
