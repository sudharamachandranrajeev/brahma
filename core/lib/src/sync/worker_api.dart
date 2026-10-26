import 'dart:convert';

import 'package:http/http.dart' as http;

import 'account_api.dart';
import 'sync_engine.dart';

/// [AccountApi] over the HTTP API of the Brahma sync server (brahma/server:
/// at home on Node, or the Cloudflare Worker).
class WorkerApi implements AccountApi {
  WorkerApi(this.server, {http.Client? client, this.info = const ServerInfo(worker: true)})
    : _client = client ?? http.Client();

  @override
  final ServerInfo info;

  @override
  final Uri server;
  final http.Client _client;
  String? _token;

  @override
  bool get signedIn {
    final exp = int.tryParse(_token?.split('.')[1] ?? '');
    return exp != null && exp > DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
  }

  Future<Map<String, Object?>> _call(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
    bool auth = true,
    Set<int> allow = const {},
  }) async {
    final uri = server.replace(path: path, queryParameters: query);
    final req = http.Request(method, uri)..headers['content-type'] = 'application/json';
    if (auth && _token != null) req.headers['authorization'] = 'Bearer $_token';
    if (body != null) req.body = jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 30)));
    } on Exception {
      throw SyncException('Sync server unreachable');
    }
    Map<String, Object?> data = {};
    if (res.body.isNotEmpty) {
      try {
        final v = jsonDecode(res.body);
        if (v is Map<String, Object?>) data = v;
      } on FormatException {
        // Not ours (a proxy error page): reported below by status.
      }
    }
    data['_status'] = res.statusCode;
    if (res.statusCode >= 400 && !allow.contains(res.statusCode)) {
      final message = data['message'];
      throw SyncException(message is String ? message : 'Sync server error ${res.statusCode}');
    }
    return data;
  }

  Future<String> _session(Future<Map<String, Object?>> call) async {
    final r = await call;
    _token = r['token']! as String;
    return r['userId']! as String;
  }

  @override
  Future<String> register(String email, String secret, String invite) => _session(
    _call('POST', '/api/register', body: {'email': email, 'secret': secret, 'invite': invite}, auth: false),
  );

  @override
  Future<String> login(String email, String secret) =>
      _session(_call('POST', '/api/login', body: {'email': email, 'secret': secret}, auth: false));

  @override
  Future<VaultRecord?> vault(String ownerId) async {
    final r = await _call('GET', '/api/vault', allow: {404});
    if (r['_status'] == 404) return null;
    return VaultRecord(
      wrappedPassword: r['wrappedPassword']! as String,
      wrappedRecovery: r['wrappedRecovery']! as String,
    );
  }

  @override
  Future<void> createVault(String ownerId, VaultRecord v) => _call(
    'POST',
    '/api/vault',
    body: {'wrappedPassword': v.wrappedPassword, 'wrappedRecovery': v.wrappedRecovery},
  );

  @override
  Future<void> rewrapVault(String ownerId, String wrappedPassword) =>
      _call('PUT', '/api/vault', body: {'wrappedPassword': wrappedPassword});

  @override
  Future<void> addDevice(String ownerId, String device, String platform) =>
      _call('POST', '/api/devices', body: {'device': device, 'platform': platform});

  @override
  Future<void> changeSecret(String ownerId, String email, String oldSecret, String newSecret) async {
    await _session(_call('POST', '/api/password', body: {'oldSecret': oldSecret, 'newSecret': newSecret}));
  }

  @override
  Future<void> requestReset(String email) => throw SyncException(
    'This server cannot send e-mail. Ask the server owner for a reset code, then choose "I have a reset code".',
  );

  @override
  Future<void> confirmReset(String email, String token, String newSecret) => _session(
    _call('POST', '/api/reset', body: {'email': email, 'code': token, 'secret': newSecret}, auth: false),
  );

  @override
  Future<String> openPairing(String ownerId) async => (await _call('POST', '/api/pairings'))['id']! as String;

  @override
  Future<PairingState> pairing(String id) async {
    final r = await _call('GET', '/api/pairings/$id', auth: false, allow: {404});
    if (r['_status'] == 404) throw PairingClosed('');
    return PairingState(request: r['request']! as String, response: r['response']! as String);
  }

  @override
  Future<void> writeRequest(String id, String sealed) async {
    final r = await _call(
      'PUT',
      '/api/pairings/$id/request',
      body: {'request': sealed},
      auth: false,
      allow: {404},
    );
    if (r['_status'] == 404) throw PairingClosed('');
  }

  @override
  Future<void> writeResponse(String id, String sealed) async {
    final r = await _call('PUT', '/api/pairings/$id/response', body: {'response': sealed}, allow: {404});
    if (r['_status'] == 404) throw PairingClosed('');
  }

  @override
  Future<void> closePairing(String id) async {
    await _call('DELETE', '/api/pairings/$id', allow: {404});
  }

  @override
  SyncRemote remote(String ownerId) => WorkerRemote(this);

  @override
  Future<DateTime?> lastBackup() async =>
      DateTime.tryParse('${(await _call('GET', '/api/me'))['lastBackup'] ?? ''}');

  @override
  Future<Map<String, Object?>?> threats() async {
    final r = await _call('GET', '/api/threats', allow: {404});
    return r['_status'] == 404 ? null : r;
  }

  @override
  Future<Map<String, Object?>?> rules() async {
    final r = await _call('GET', '/api/rules', allow: {404});
    return r['_status'] == 404 ? null : r;
  }

  @override
  Future<bool> isOwner() async => (await _call('GET', '/api/me'))['owner'] == true;

  @override
  Future<String> createInvite() async => (await _call('POST', '/api/invites'))['code']! as String;

  @override
  Future<String> createResetCode(String email) async =>
      (await _call('POST', '/api/members/reset', body: {'email': email.trim().toLowerCase()}))['code']!
          as String;
}

/// [SyncRemote] over the Worker's change log.
class WorkerRemote implements SyncRemote {
  WorkerRemote(this._api);
  final WorkerApi _api;

  @override
  Future<bool> push(String device, int seq, String payload) async {
    final r = await _api._call(
      'POST',
      '/api/changes',
      body: {'device': device, 'seq': seq, 'payload': payload},
      allow: {409},
    );
    return r['_status'] != 409;
  }

  @override
  Future<String?> fetch(String device, int seq) async {
    final r = await _api._call(
      'GET',
      '/api/changes/one',
      query: {'device': device, 'seq': '$seq'},
      allow: {404},
    );
    return r['_status'] == 404 ? null : r['payload']! as String;
  }

  @override
  Future<int> lastSeq(String device) async =>
      (await _api._call('GET', '/api/changes/last', query: {'device': device}))['seq']! as int;

  @override
  Future<List<String>> devices() async {
    final r = await _api._call('GET', '/api/devices');
    return [for (final d in r['devices']! as List) d as String];
  }

  @override
  Future<List<RemoteChange>> pull(String device, int afterSeq, {int limit = 50}) async {
    final r = await _api._call(
      'GET',
      '/api/changes',
      query: {'device': device, 'after': '$afterSeq', 'limit': '$limit'},
    );
    return [
      for (final x in r['items']! as List) RemoteChange((x as Map)['seq'] as int, x['payload'] as String),
    ];
  }
}
