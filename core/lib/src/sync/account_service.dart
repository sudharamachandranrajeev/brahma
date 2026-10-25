import '../db/store.dart';
import '../security/crypto.dart';
import '../security/key_vault.dart';
import 'account_api.dart';
import 'pairing.dart';
import 'sync_engine.dart';

/// Signed in, but the password no longer opens the vault (it was reset by
/// e-mail): the recovery key is needed once to re-wrap the data key.
class RecoveryKeyNeeded implements Exception {
  @override
  String toString() => 'Enter your recovery key to unlock your synced data';
}

/// Sync account lifecycle. The password never leaves this class: the server
/// gets a derived login secret, and the data key is only stored wrapped.
class AccountService {
  AccountService(this.vault, {required this.deviceId, this.deviceName = '', this.platform = ''});

  final KeyVault vault;
  final String deviceId;

  /// Shown to the other device when pairing, inside the sealed request
  /// only: the server's device list stays nameless.
  final String deviceName;
  final String platform;

  AccountApi? _api;
  PasswordKeys? _pendingKeys;
  String? _pendingEmail, _pendingOwner;

  static const _password = 'password', _recovery = 'recovery';

  /// Creates the account and its vault. Returns the recovery key, which the
  /// user must write down: it is shown once and never stored.
  ///
  /// Repeating a sign-up that stopped before its vault was created finishes it.
  Future<String> signUp({
    required String server,
    required String email,
    required String password,
    required String invite,
  }) async {
    final keys = await VaultCrypto.fromPassword(email, password);
    final mail = email.trim().toLowerCase();
    final api = await AccountApi.connect(server);
    final ownerId = await api.register(mail, keys.authSecret, invite);
    if (await api.vault(ownerId) != null) {
      throw SyncException('This e-mail already has an account: sign in instead');
    }
    final dek = VaultCrypto.newDataKey();
    final recovery = VaultCrypto.newRecoveryKey();
    await api.createVault(
      ownerId,
      VaultRecord(
        wrappedPassword: await VaultCrypto.wrapKey(dek, keys.kek, _password),
        wrappedRecovery: await VaultCrypto.wrapKey(dek, await VaultCrypto.recoveryKek(recovery), _recovery),
      ),
    );
    await _finish(api, mail, keys.authSecret, ownerId, dek);
    return recovery;
  }

  /// Signs in on this device. Throws [RecoveryKeyNeeded] when the vault was
  /// wrapped under an older password; then call [unlockWithRecoveryKey].
  Future<void> signIn({required String server, required String email, required String password}) async {
    final keys = await VaultCrypto.fromPassword(email, password);
    final mail = email.trim().toLowerCase();
    final api = await AccountApi.connect(server);
    final ownerId = await api.login(mail, keys.authSecret);
    final v = await api.vault(ownerId);
    if (v == null) throw SyncException('Account setup did not finish: sign up again with the same details');
    final List<int> dek;
    try {
      dek = await VaultCrypto.unwrapKey(v.wrappedPassword, keys.kek, _password);
    } on CryptoException {
      _api = api;
      _pendingKeys = keys;
      _pendingEmail = mail;
      _pendingOwner = ownerId;
      throw RecoveryKeyNeeded();
    }
    await _finish(api, mail, keys.authSecret, ownerId, dek);
  }

  /// After [RecoveryKeyNeeded]: opens the vault with the recovery key and
  /// re-wraps the data key under the current password.
  Future<void> unlockWithRecoveryKey(String recoveryKey) async {
    final api = _api, keys = _pendingKeys, mail = _pendingEmail, ownerId = _pendingOwner;
    if (api == null || keys == null || mail == null || ownerId == null) throw SyncException('Sign in first');
    final v = (await api.vault(ownerId))!;
    final dek = await VaultCrypto.unwrapKey(
      v.wrappedRecovery,
      await VaultCrypto.recoveryKek(recoveryKey),
      _recovery,
    );
    await api.rewrapVault(ownerId, await VaultCrypto.wrapKey(dek, keys.kek, _password));
    await _finish(api, mail, keys.authSecret, ownerId, dek);
  }

  /// Asks the server to send its password-reset e-mail (needs SMTP on a
  /// PocketBase server; the Worker has none and says so).
  Future<void> requestPasswordReset({required String server, required String email}) async =>
      (await AccountApi.connect(server)).requestReset(email.trim().toLowerCase());

  /// Sets a new password from the reset code; the recovery key then
  /// re-opens the vault.
  Future<void> resetPassword({
    required String server,
    required String email,
    required String token,
    required String newPassword,
    required String recoveryKey,
  }) async {
    // Reject a mistyped recovery key before anything changes on the server.
    await VaultCrypto.recoveryKek(recoveryKey);
    final keys = await VaultCrypto.fromPassword(email, newPassword);
    await (await AccountApi.connect(server)).confirmReset(email.trim().toLowerCase(), token, keys.authSecret);
    try {
      await signIn(server: server, email: email, password: newPassword);
    } on RecoveryKeyNeeded {
      await unlockWithRecoveryKey(recoveryKey);
    }
  }

  /// Changes the password and re-wraps the data key. If this stops half way,
  /// signing in with the new password asks for the recovery key once.
  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    final s = await vault.session();
    final dek = await vault.dataKey();
    if (s == null || dek == null) throw SyncException('Not signed in');
    final mail = s['email']! as String, ownerId = s['userId']! as String;
    final oldKeys = await VaultCrypto.fromPassword(mail, oldPassword);
    final newKeys = await VaultCrypto.fromPassword(mail, newPassword);
    final api = await _signedIn();
    final v = (await api.vault(ownerId))!;
    // Checked here too so a wrong old password fails before any change.
    await VaultCrypto.unwrapKey(v.wrappedPassword, oldKeys.kek, _password);
    final wrapped = await VaultCrypto.wrapKey(dek, newKeys.kek, _password);
    await api.changeSecret(ownerId, mail, oldKeys.authSecret, newKeys.authSecret);
    await vault.setSession({...s, 'secret': newKeys.authSecret});
    await api.rewrapVault(ownerId, wrapped);
  }

  // Pairing (see [PairingCrypto]). On the signed-in device: [offerPairing],
  // then poll [pairingRequest], then [approvePairing] or [cancelPairing].
  // On the new device: [requestJoin], poll [joinGrant], then [join].

  /// Opens a pairing record and returns the link to show as a QR code.
  Future<PairingLink> offerPairing() async {
    final api = await _signedIn();
    final ownerId = (await vault.session())!['userId']! as String;
    return PairingLink(
      api.server,
      await api.openPairing(ownerId),
      VaultCrypto.randomBytes(32),
      scheme: vault.app.linkScheme,
    );
  }

  /// The request waiting on [link], or null while there is none.
  Future<JoinRequest?> pairingRequest(PairingLink link) async {
    final r = await _pairing(await _signedIn(), link.id, 'This code has expired. Make a new one.');
    return r.request.isEmpty ? null : PairingCrypto.openRequest(link, r.request);
  }

  /// Sends this account's keys to the device that made [request].
  Future<void> approvePairing(PairingLink link, JoinRequest request) async {
    final s = await vault.session();
    final dek = await vault.dataKey();
    if (s == null || dek == null) throw SyncException('Not signed in');
    final grant = PairingGrant(
      email: s['email']! as String,
      userId: s['userId']! as String,
      secret: s['secret']! as String,
      dataKey: dek,
    );
    final response = await PairingCrypto.sealGrant(link, request.publicKey, grant);
    await (await _signedIn()).writeResponse(link.id, response);
  }

  /// Whether the new device has finished with [link] (it deletes the record).
  Future<bool> pairingFinished(PairingLink link) async {
    try {
      await _pairing(await _signedIn(), link.id, '');
      return false;
    } on PairingClosed {
      return true;
    }
  }

  /// Withdraws [link]; a device waiting on it is told it was declined.
  Future<void> cancelPairing(PairingLink link) async => (await _signedIn()).closePairing(link.id);

  /// On a new device: asks to join through [link]. The ticket's code must
  /// match the one the other device shows.
  Future<JoinTicket> requestJoin(PairingLink link) async {
    if (await vault.session() != null) throw SyncException('This device already syncs. Sign out first.');
    final keyPair = await PairingCrypto.newKeyPair();
    final publicKey = (await keyPair.extractPublicKey()).bytes;
    final sealed = await PairingCrypto.sealRequest(
      link,
      JoinRequest(name: deviceName, platform: platform, publicKey: publicKey),
    );
    final api = await AccountApi.connect('${link.server}');
    try {
      await api.writeRequest(link.id, sealed);
    } on PairingClosed {
      throw PairingClosed('This code has expired or was already used. Make a new one on your other device.');
    }
    return JoinTicket(link, keyPair, await PairingCrypto.code(link, publicKey));
  }

  /// The account the other device sent, once it approved; null while waiting.
  Future<PairingGrant?> joinGrant(JoinTicket ticket) async {
    final r = await _pairing(
      await AccountApi.connect('${ticket.link.server}'),
      ticket.link.id,
      'The other device declined, or the code expired.',
    );
    return r.response.isEmpty ? null : PairingCrypto.openGrant(ticket, r.response);
  }

  /// Signs this device in with [grant] and closes the pairing.
  Future<void> join(JoinTicket ticket, PairingGrant grant) async {
    final api = await AccountApi.connect('${ticket.link.server}');
    final ownerId = await api.login(grant.email, grant.secret);
    if (ownerId != grant.userId || await api.vault(ownerId) == null) {
      throw SyncException('The other device sent keys for an account this server does not know');
    }
    await _finish(api, grant.email, grant.secret, ownerId, grant.dataKey);
    try {
      await api.closePairing(ticket.link.id);
    } on SyncException {
      // It expires on its own.
    }
  }

  Future<PairingState> _pairing(AccountApi api, String id, String gone) async {
    try {
      return await api.pairing(id);
    } on PairingClosed {
      throw PairingClosed(gone);
    }
  }

  /// A sync engine for the signed-in account, or null when signed out. Ask
  /// for one per sync run: it signs in again when the server token expired.
  Future<SyncEngine?> engine(Store store) async {
    final s = await vault.session();
    final dek = await vault.dataKey();
    if (s == null || dek == null) return null;
    final api = await _signedIn();
    final ownerId = s['userId']! as String;
    return SyncEngine(store, api.remote(ownerId), dek, ownerId);
  }

  Future<void> signOut() async {
    _api = null;
    await vault.signOut();
  }

  /// The signed-in server connection, for what only some servers offer
  /// (inviting people).
  Future<AccountApi> api() => _signedIn();

  Future<AccountApi> _signedIn() async {
    final s = await vault.session();
    if (s == null) throw SyncException('Not signed in');
    final api = _api ??= await AccountApi.connect(s['server']! as String);
    if (!api.signedIn) await api.login(s['email']! as String, s['secret']! as String);
    return api;
  }

  /// Keeps the keys on this device and registers it with the account.
  Future<void> _finish(AccountApi api, String mail, String secret, String ownerId, List<int> dek) async {
    await api.addDevice(ownerId, deviceId, platform);
    await vault.setDataKey(dek);
    await vault.setSession({
      'server': api.server.toString(),
      'email': mail,
      'userId': ownerId,
      'secret': secret,
    });
    _api = api;
    _pendingKeys = null;
    _pendingEmail = null;
    _pendingOwner = null;
  }
}
