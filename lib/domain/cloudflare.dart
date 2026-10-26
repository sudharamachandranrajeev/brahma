import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:brahma_core/brahma_core.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'hub.dart';
import 'models.dart';

/// A Cloudflare API refusal, worded for the user. [code] is Cloudflare's
/// error code (10042: R2 is not enabled on the account).
class CloudflareException implements Exception, UserFacingError {
  CloudflareException(this.message, {this.status = 0, this.code = 0});
  @override
  final String message;
  final int status, code;

  bool get r2Disabled => code == 10042;

  @override
  String toString() => message;
}

typedef CloudflareAccount = ({String id, String name});

/// The calls of Cloudflare's API that deploying the hub needs. [token] is an
/// API token the user made in the Cloudflare dashboard (see [tokenPageUrl]).
class CloudflareClient {
  CloudflareClient(this.token, {http.Client? client}) : _http = client ?? http.Client();
  final String token;
  final http.Client _http;

  static final _base = Uri.parse('https://api.cloudflare.com/client/v4');

  Uri _uri(String path, [Map<String, String>? query]) =>
      _base.replace(path: '${_base.path}$path', queryParameters: query);

  Future<Object?> _call(String method, String path, {Object? body, Map<String, String>? query}) async {
    final req = http.Request(method, _uri(path, query))..headers['authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    return _read(() => _http.send(req));
  }

  Future<Object?> _read(Future<http.StreamedResponse> Function() send) async {
    final http.Response res;
    try {
      res = await http.Response.fromStream(await send().timeout(const Duration(minutes: 2)));
    } on TimeoutException {
      throw CloudflareException('Cloudflare did not answer in time. Check your connection and try again.');
    } on SocketException catch (e) {
      throw CloudflareException('Cannot reach Cloudflare: ${e.message}');
    } on http.ClientException catch (e) {
      throw CloudflareException('Cannot reach Cloudflare: ${e.message}');
    }
    Json j = const {};
    try {
      j = obj(jsonDecode(res.body));
    } on FormatException {
      // Not JSON: worded from the status below.
    }
    if (res.statusCode >= 200 && res.statusCode < 300 && j['success'] != false) return j['result'];
    final errors = objs(j['errors']);
    final code = errors.isEmpty ? 0 : (errors.first['code'] as num?)?.toInt() ?? 0;
    final said = errors.map((e) => str(e['message'])).where((m) => m.isNotEmpty).join('; ');
    throw CloudflareException(
      switch (res.statusCode) {
        401 || 403 when code != 10042 =>
          'Cloudflare refused the key${said.isEmpty ? '' : ' ($said)'}. Check that it has every '
              'permission listed in step 3.',
        _ => said.isEmpty ? 'Cloudflare answered ${res.statusCode}.' : 'Cloudflare: $said',
      },
      status: res.statusCode,
      code: code,
    );
  }

  /// Null when Cloudflare has no such thing (a 404), so callers can create it.
  Future<Object?> _find(String path, {Map<String, String>? query}) async {
    try {
      return await _call('GET', path, query: query);
    } on CloudflareException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<List<CloudflareAccount>> accounts() async => [
    for (final a in objs(await _call('GET', '/accounts', query: {'per_page': '50'})))
      (id: str(a['id']), name: str(a['name'])),
  ];

  /// The account's `<name>.workers.dev` name, or null before it has one.
  Future<String?> subdomain(String account) async =>
      strOrNull(obj(await _find('/accounts/$account/workers/subdomain'))['subdomain']);

  Future<String> createSubdomain(String account, String name) async => str(
    obj(await _call('PUT', '/accounts/$account/workers/subdomain', body: {'subdomain': name}))['subdomain'],
  );

  Future<String> kvNamespace(String account, String title) async {
    final path = '/accounts/$account/storage/kv/namespaces';
    for (final n in objs(await _call('GET', path, query: {'per_page': '100'}))) {
      if (n['title'] == title) return str(n['id']);
    }
    return str(obj(await _call('POST', path, body: {'title': title}))['id']);
  }

  Future<String> d1Database(String account, String name) async {
    final path = '/accounts/$account/d1/database';
    for (final d in objs(await _call('GET', path, query: {'name': name}))) {
      if (d['name'] == name) return str(d['uuid']);
    }
    return str(obj(await _call('POST', path, body: {'name': name}))['uuid']);
  }

  /// Runs [sql] (one statement with [params], or several without) and
  /// returns the last statement's rows.
  Future<List<Json>> d1Query(String account, String db, String sql, [List<Object?> params = const []]) async {
    final out = objs(
      await _call(
        'POST',
        '/accounts/$account/d1/database/$db/query',
        body: {'sql': sql, if (params.isNotEmpty) 'params': params},
      ),
    );
    return out.isEmpty ? const [] : objs(out.last['results']);
  }

  /// Makes the bucket unless it is there. Throws with [CloudflareException.r2Disabled]
  /// until R2 is turned on in the dashboard.
  Future<void> r2Bucket(String account, String name) async {
    if (await _find('/accounts/$account/r2/buckets/$name') != null) return;
    await _call('POST', '/accounts/$account/r2/buckets', body: {'name': name});
  }

  Future<bool> scriptExists(String account, String name) async =>
      await _find('/accounts/$account/workers/scripts/$name/settings') != null;

  /// Uploads the Worker as one ES module with its bindings.
  Future<void> uploadScript(String account, String name, {required Json metadata, required String code}) =>
      _read(() {
        final req = http.MultipartRequest('PUT', _uri('/accounts/$account/workers/scripts/$name'))
          ..headers['authorization'] = 'Bearer $token'
          ..files.add(
            http.MultipartFile.fromString(
              'metadata',
              jsonEncode(metadata),
              filename: 'metadata.json',
              contentType: MediaType('application', 'json'),
            ),
          )
          ..files.add(
            http.MultipartFile.fromString(
              str(metadata['main_module']),
              code,
              filename: str(metadata['main_module']),
              contentType: MediaType('application', 'javascript+module'),
            ),
          );
        return _http.send(req);
      });

  Future<void> setSchedules(String account, String name, List<String> crons) => _call(
    'PUT',
    '/accounts/$account/workers/scripts/$name/schedules',
    body: [
      for (final c in crons) {'cron': c},
    ],
  );

  /// Serves the Worker at `<name>.<subdomain>.workers.dev`.
  Future<void> enableWorkersDev(String account, String name) => _call(
    'POST',
    '/accounts/$account/workers/scripts/$name/subdomain',
    body: {'enabled': true, 'previews_enabled': false},
  );

  /// The dashboard page that makes an API token with the permissions the
  /// hub's setup needs, filled in.
  static final tokenPageUrl = Uri.https('dash.cloudflare.com', '/profile/api-tokens', {
    'permissionGroupKeys': jsonEncode([
      {'key': 'workers_scripts', 'type': 'edit'},
      {'key': 'workers_kv_storage', 'type': 'edit'},
      {'key': 'd1', 'type': 'edit'},
      {'key': 'workers_r2', 'type': 'edit'},
      {'key': 'account_settings', 'type': 'read'},
    ]),
    'name': 'Vani hub',
    'accountId': '*',
    'zoneId': 'all',
  });
}

/// The Worker build Vani ships (assets/hub, made by `npm run bundle` in
/// hub/): the code and what deploying it needs.
class HubBundle {
  HubBundle({required this.manifest, required this.code});
  final Json manifest;
  final String code;

  String get version => str(manifest['version']);
  String get name => str(manifest['name']);
  String get d1Name => str(obj(manifest['d1'])['name']);
  String get r2Name => str(obj(manifest['r2'])['name']);
  List<({String name, String sql})> get migrations => [
    for (final m in objs(manifest['migrations'])) (name: str(m['name']), sql: str(m['sql'])),
  ];
}

/// What this device remembers about the hub it deployed: the Cloudflare key
/// (for updates) and a copy of the hub's secrets. Device-only, in the
/// encrypted database; never synced.
class HubDeployment {
  const HubDeployment({
    required this.cloudflareToken,
    required this.accountId,
    this.url = '',
    this.apiToken = '',
    this.tokenKey = '',
    this.ntfyTopic = '',
  });
  final String cloudflareToken, accountId, url, apiToken, tokenKey, ntfyTopic;

  static const localKey = 'vani.hubDeployment';

  factory HubDeployment.fromJson(Json j) => HubDeployment(
    cloudflareToken: str(j['cloudflareToken']),
    accountId: str(j['accountId']),
    url: str(j['url']),
    apiToken: str(j['apiToken']),
    tokenKey: str(j['tokenKey']),
    ntfyTopic: str(j['ntfyTopic']),
  );

  Json toJson() => {
    'cloudflareToken': cloudflareToken,
    'accountId': accountId,
    'url': url,
    'apiToken': apiToken,
    'tokenKey': tokenKey,
    'ntfyTopic': ntfyTopic,
  };

  /// The ntfy page for the phone alerts (open it, or scan it with ntfy).
  String get ntfyUrl => 'https://ntfy.sh/$ntfyTopic';
}

/// The stages of a deploy, in order, for the progress list.
enum DeployStep {
  storage('Storage for searches and alerts'),
  database('Database for posts and the inbox'),
  media('Storage for photos and videos'),
  worker('The hub itself'),
  schedule('Every-minute timer'),
  address('Web address'),
  check('Checking it answers');

  const DeployStep(this.label);
  final String label;
}

/// The result of [deployHub]: the link to connect with ([link] is empty for
/// an existing hub this device has no token for: the user enters it).
typedef Deployed = ({HubDeployment deployment, HubLink link, bool updated});

String _random(int bytes, {bool hex = false}) {
  final r = Random.secure();
  final b = List<int>.generate(bytes, (_) => r.nextInt(256));
  return hex ? b.map((x) => x.toRadixString(16).padLeft(2, '0')).join() : base64.encode(b);
}

/// Deploys [bundle] to the user's Cloudflare account, or updates the hub
/// already there. Safe to run again: everything is found by name before it
/// is made, and migrations already applied are skipped (tracked in
/// wrangler's `d1_migrations` table, so `wrangler d1 migrations` agrees).
///
/// A new hub gets fresh secrets. An existing one keeps its secrets (above
/// all TOKEN_KEY, which unlocks the stored platform tokens): only the code,
/// bindings, timer and migrations change.
Future<Deployed> deployHub({
  required CloudflareClient cf,
  required String accountId,
  required String subdomain,
  required HubBundle bundle,
  HubDeployment? previous,
  http.Client? client,
  void Function(DeployStep step)? onStep,
  Duration wait = const Duration(seconds: 5),
  int attempts = 36,
}) async {
  final a = accountId, name = bundle.name;
  onStep?.call(DeployStep.storage);
  final kv = await cf.kvNamespace(a, '$name-${str(bundle.manifest['kvBinding'])}');

  onStep?.call(DeployStep.database);
  final db = await cf.d1Database(a, bundle.d1Name);
  await cf.d1Query(
    a,
    db,
    'CREATE TABLE IF NOT EXISTS d1_migrations(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, '
    'applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL)',
  );
  final applied = {for (final r in await cf.d1Query(a, db, 'SELECT name FROM d1_migrations')) str(r['name'])};
  for (final m in bundle.migrations) {
    if (applied.contains(m.name)) continue;
    await cf.d1Query(a, db, m.sql);
    await cf.d1Query(a, db, 'INSERT INTO d1_migrations (name) VALUES (?)', [m.name]);
  }

  onStep?.call(DeployStep.media);
  await cf.r2Bucket(a, bundle.r2Name);

  onStep?.call(DeployStep.worker);
  final url = 'https://$name.$subdomain.workers.dev';
  final updating = await cf.scriptExists(a, name);
  // Deployed before from here (or connected on this device): keep what we
  // know. Otherwise (another computer made it) its secrets stay on
  // Cloudflare and the user connects with the hub's phone link.
  final known = previous != null && previous.accountId == a && previous.apiToken.isNotEmpty ? previous : null;
  final secrets = updating
      ? null
      : {
          'API_TOKEN': known?.apiToken ?? _random(32, hex: true),
          'TOKEN_KEY': known?.tokenKey ?? _random(32),
          'NTFY_TOPIC': known?.ntfyTopic ?? 'brahma-${_random(12, hex: true)}',
          'PUBLIC_URL': url,
        };
  final vars = obj(bundle.manifest['vars']);
  await cf.uploadScript(
    a,
    name,
    code: bundle.code,
    metadata: {
      'main_module': 'worker.js',
      'compatibility_date': str(bundle.manifest['compatibilityDate']),
      'bindings': [
        {'type': 'kv_namespace', 'name': str(bundle.manifest['kvBinding']), 'namespace_id': kv},
        {'type': 'd1', 'name': str(obj(bundle.manifest['d1'])['binding']), 'id': db},
        {
          'type': 'r2_bucket',
          'name': str(obj(bundle.manifest['r2'])['binding']),
          'bucket_name': bundle.r2Name,
        },
        for (final e in vars.entries) {'type': 'plain_text', 'name': e.key, 'text': '${e.value}'},
        if (secrets != null)
          for (final e in secrets.entries) {'type': 'secret_text', 'name': e.key, 'text': e.value},
      ],
      if (secrets == null) 'keep_bindings': ['secret_text'],
    },
  );

  onStep?.call(DeployStep.schedule);
  await cf.setSchedules(a, name, strs(bundle.manifest['crons']));

  onStep?.call(DeployStep.address);
  await cf.enableWorkersDev(a, name);

  final apiToken = secrets?['API_TOKEN'] ?? known?.apiToken ?? '';
  final deployment = HubDeployment(
    cloudflareToken: cf.token,
    accountId: a,
    url: url,
    apiToken: apiToken,
    tokenKey: secrets?['TOKEN_KEY'] ?? known?.tokenKey ?? '',
    ntfyTopic: secrets?['NTFY_TOPIC'] ?? known?.ntfyTopic ?? '',
  );
  final link = HubLink(url: url, token: apiToken);

  onStep?.call(DeployStep.check);
  if (link.ready) {
    // A new workers.dev address can take a minute or two to answer, and a
    // new version a few seconds to reach every edge.
    final hub = HubClient(url, apiToken, client: client, timeout: const Duration(seconds: 15));
    for (var i = 0; ; i++) {
      try {
        if (await hub.version() == bundle.version) break;
      } on HubException {
        // Not answering yet (or still the old version): wait.
      }
      if (i + 1 >= attempts) {
        throw CloudflareException(
          'The hub is deployed but its address is not answering yet. Wait a few minutes, then tap Set up '
          'again: it carries on where it stopped.',
        );
      }
      await Future<void>.delayed(wait);
    }
  }
  return (deployment: deployment, link: link, updated: updating);
}
