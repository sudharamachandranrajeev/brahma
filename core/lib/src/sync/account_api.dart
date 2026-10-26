import 'dart:convert';

import 'package:http/http.dart' as http;

import 'pocketbase_api.dart';
import 'pocketbase_remote.dart' show validateServerUrl;
import 'sync_engine.dart';
import 'worker_api.dart';

/// The wrapped keys of an account (see [VaultCrypto]).
class VaultRecord {
  const VaultRecord({required this.wrappedPassword, required this.wrappedRecovery});
  final String wrappedPassword;
  final String wrappedRecovery;
}

/// What a pairing record holds: the new device's sealed request and the old
/// device's sealed answer, each empty until written.
class PairingState {
  const PairingState({required this.request, required this.response});
  final String request;
  final String response;
}

/// What a sync server is, from its health check.
class ServerInfo {
  const ServerInfo({
    required this.worker,
    this.needsSetup = false,
    this.kind,
    this.name = '',
    this.version = '',
  });

  /// From the health check's JSON; null when it is not a Brahma sync server.
  static ServerInfo? fromHealth(Object? body) {
    if (body is! Map || body['service'] != 'brahma-sync') return null;
    final kind = body['kind'];
    return ServerInfo(
      worker: true,
      needsSetup: body['needsSetup'] == true,
      kind: kind == 'home' ? ServerKind.home : ServerKind.cloud,
      name: '${body['name'] ?? ''}',
      version: '${body['version'] ?? ''}',
    );
  }

  /// A Brahma sync server (true; brahma/server, at home or on Cloudflare) or
  /// a PocketBase one (false).
  final bool worker;

  /// A server no one has signed up on yet: the first account is the owner's
  /// and needs the setup code.
  final bool needsSetup;

  /// Where a Brahma sync server runs; null for PocketBase.
  final ServerKind? kind;

  /// The home computer's name (home servers), and the server's version.
  final String name, version;

  /// "Home server "den-laptop", version 1.0.0", for people.
  String get describe => switch (kind) {
    ServerKind.home =>
      'Home server${name.isEmpty ? '' : ' "$name"'}${version.isEmpty ? '' : ', version $version'}',
    ServerKind.cloud => 'Cloud server${version.isEmpty ? '' : ', version $version'}',
    null => 'PocketBase server',
  };
}

enum ServerKind { home, cloud }

/// The pairing record is gone: it expired, was used, or was cancelled.
class PairingClosed extends SyncException {
  PairingClosed(super.message);
}

/// What [AccountService] needs from a sync server: accounts, wrapped keys,
/// pairing records and the change log. A self-hosted PocketBase and the
/// Cloudflare Worker (Bhojana's server/) both speak it; [connect] picks.
abstract interface class AccountApi {
  /// Asks the server at [server] what it is. Plain HTTP is allowed only on
  /// the user's own network (see [validateServerUrl]).
  static Future<AccountApi> connect(String server, {http.Client? client}) async {
    final url = validateServerUrl(server);
    final c = client ?? http.Client();
    try {
      final res = await c.get(url.resolve('/api/health')).timeout(const Duration(seconds: 20));
      final body = res.statusCode == 200 ? jsonDecode(res.body) : null;
      final info = ServerInfo.fromHealth(body);
      if (info != null) return WorkerApi(url, client: c, info: info);
    } on FormatException {
      // Not JSON: treat as PocketBase below.
    } on Exception {
      throw SyncException('Sync server unreachable');
    }
    return PocketBaseApi(url);
  }

  Uri get server;

  ServerInfo get info;

  /// Whether a login is held and still valid.
  bool get signedIn;

  /// Creates the account (or finishes one that stopped half way) and signs in.
  /// Returns the user id.
  Future<String> register(String email, String secret, String invite);

  /// Signs in. Returns the user id.
  Future<String> login(String email, String secret);

  Future<VaultRecord?> vault(String ownerId);
  Future<void> createVault(String ownerId, VaultRecord vault);
  Future<void> rewrapVault(String ownerId, String wrappedPassword);
  Future<void> addDevice(String ownerId, String device, String platform);

  /// Changes the login secret; stays signed in under the new one.
  Future<void> changeSecret(String ownerId, String email, String oldSecret, String newSecret);

  /// E-mails a reset code. [SyncException] where the server cannot e-mail.
  Future<void> requestReset(String email);
  Future<void> confirmReset(String email, String token, String newSecret);

  /// Opens a pairing record and returns its id.
  Future<String> openPairing(String ownerId);
  Future<PairingState> pairing(String id);
  Future<void> writeRequest(String id, String sealed);
  Future<void> writeResponse(String id, String sealed);
  Future<void> closePairing(String id);

  SyncRemote remote(String ownerId);

  /// When the server last made a backup of itself; null when unknown (cloud
  /// and PocketBase servers keep their own history).
  Future<DateTime?> lastBackup();

  /// Whether this login may invite people (the Worker's first account).
  Future<bool> isOwner();

  /// A one-time code that lets one more person create an account.
  Future<String> createInvite();

  /// A one-time code that lets [email] choose a new password (recovery key
  /// still needed). For servers that cannot e-mail.
  Future<String> createResetCode(String email);
}
