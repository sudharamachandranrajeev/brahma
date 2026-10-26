import 'package:pocketbase/pocketbase.dart';

import 'account_api.dart';
import 'pocketbase_remote.dart';
import 'sync_engine.dart';

/// [AccountApi] over the PocketBase collections in Artha's server/pb_migrations.
class PocketBaseApi implements AccountApi {
  PocketBaseApi(this.server) : pb = PocketBase(server.toString());

  @override
  final Uri server;
  final PocketBase pb;

  RecordService get _users => pb.collection('users');
  RecordService get _vaults => pb.collection('vaults');
  RecordService get _pairings => pb.collection('pairings');

  @override
  ServerInfo get info => const ServerInfo(worker: false);

  @override
  bool get signedIn => pb.authStore.isValid;

  @override
  Future<String> register(String email, String secret, String invite) async {
    try {
      await _users.create(
        body: {'email': email, 'password': secret, 'passwordConfirm': secret, 'invite': invite},
      );
    } on ClientException catch (e) {
      if (!isNotUnique(e)) await pbCall(() => Future<void>.error(e));
    }
    return login(email, secret);
  }

  @override
  Future<String> login(String email, String secret) async =>
      (await pbCall(() => _users.authWithPassword(email, secret))).record.id;

  @override
  Future<VaultRecord?> vault(String ownerId) async {
    final r = await pbCall(
      () => _vaults.getList(perPage: 1, skipTotal: true, filter: pb.filter('owner = {:o}', {'o': ownerId})),
    );
    final v = r.items.firstOrNull;
    return v == null
        ? null
        : VaultRecord(
            wrappedPassword: v.getStringValue('wrapped_password'),
            wrappedRecovery: v.getStringValue('wrapped_recovery'),
          );
  }

  Future<String> _vaultId(String ownerId) async {
    final r = await pbCall(
      () => _vaults.getList(perPage: 1, skipTotal: true, filter: pb.filter('owner = {:o}', {'o': ownerId})),
    );
    return r.items.single.id;
  }

  @override
  Future<void> createVault(String ownerId, VaultRecord v) => pbCall(
    () => _vaults.create(
      body: {
        'owner': ownerId,
        'wrapped_password': v.wrappedPassword,
        'wrapped_recovery': v.wrappedRecovery,
        'version': 1,
      },
    ),
  );

  @override
  Future<void> rewrapVault(String ownerId, String wrappedPassword) async {
    final id = await _vaultId(ownerId);
    await pbCall(() => _vaults.update(id, body: {'wrapped_password': wrappedPassword}));
  }

  @override
  Future<void> addDevice(String ownerId, String device, String platform) async {
    try {
      await pb.collection('devices').create(body: {'owner': ownerId, 'device': device, 'platform': platform});
    } on ClientException catch (e) {
      if (!isNotUnique(e)) await pbCall(() => Future<void>.error(e));
    }
  }

  @override
  Future<void> changeSecret(String ownerId, String email, String oldSecret, String newSecret) async {
    await pbCall(
      () => _users.update(
        ownerId,
        body: {'oldPassword': oldSecret, 'password': newSecret, 'passwordConfirm': newSecret},
      ),
    );
    await login(email, newSecret);
  }

  @override
  Future<void> requestReset(String email) => pbCall(() => _users.requestPasswordReset(email));

  @override
  Future<void> confirmReset(String email, String token, String newSecret) =>
      pbCall(() => _users.confirmPasswordReset(token.trim(), newSecret, newSecret));

  @override
  Future<String> openPairing(String ownerId) async =>
      (await pbCall(() => _pairings.create(body: {'owner': ownerId}))).id;

  Future<RecordModel> _pairing(String id) async {
    try {
      return await _pairings.getOne(id);
    } on ClientException catch (e) {
      if (e.statusCode == 404) throw PairingClosed('');
      return pbCall(() => Future<RecordModel>.error(e));
    }
  }

  @override
  Future<PairingState> pairing(String id) async {
    final r = await _pairing(id);
    return PairingState(request: r.getStringValue('request'), response: r.getStringValue('response'));
  }

  Future<void> _write(String id, String field, String sealed) async {
    try {
      await _pairings.update(id, body: {field: sealed});
    } on ClientException catch (e) {
      // Rules hide a used or expired record, so both read as not found.
      if (e.statusCode == 404) throw PairingClosed('');
      await pbCall(() => Future<void>.error(e));
    }
  }

  @override
  Future<void> writeRequest(String id, String sealed) => _write(id, 'request', sealed);

  @override
  Future<void> writeResponse(String id, String sealed) => _write(id, 'response', sealed);

  @override
  Future<void> closePairing(String id) async {
    try {
      await _pairings.delete(id);
    } on ClientException catch (e) {
      if (e.statusCode != 404) await pbCall(() => Future<void>.error(e));
    }
  }

  @override
  SyncRemote remote(String ownerId) => PocketBaseRemote(pb, ownerId);

  @override
  Future<DateTime?> lastBackup() async => null;

  @override
  Future<Map<String, Object?>?> threats() async => null;

  @override
  Future<bool> isOwner() async => false;

  @override
  Future<String> createInvite() => throw SyncException('Invite people on the PocketBase server itself');

  @override
  Future<String> createResetCode(String email) =>
      throw SyncException('Reset passwords on the PocketBase server itself');
}
