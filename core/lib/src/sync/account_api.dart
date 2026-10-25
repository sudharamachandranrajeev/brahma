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
  const ServerInfo({required this.worker, this.needsSetup = false});

  /// A Bhojana/Brahma Worker server (true) or a PocketBase one (false).
  final bool worker;

  /// A Worker no one has signed up on yet: the first account is the owner's
  /// and needs the setup code.
  final bool needsSetup;
}

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
      if (body is Map && body['service'] == 'brahma-sync') {
        return WorkerApi(url, client: c, needsSetup: body['needsSetup'] == true);
      }
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

  /// Whether this login may invite people (the Worker's first account).
  Future<bool> isOwner();

  /// A one-time code that lets one more person create an account.
  Future<String> createInvite();

  /// A one-time code that lets [email] choose a new password (recovery key
  /// still needed). For servers that cannot e-mail.
  Future<String> createResetCode(String email);
}
