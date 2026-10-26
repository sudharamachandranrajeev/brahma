// Sync account lifecycle, as brahma_core's AccountService. The password never
// leaves this module: the server gets a derived login secret, and the data
// key is only stored wrapped there.
import { PairingClosed, SignInAgain, WorkerApi } from "./api.ts";
import {
  CryptoError,
  fromBase64,
  fromPassword,
  newDataKey,
  newRecoveryKey,
  randomBytes,
  recoveryKek,
  toBase64,
  unwrapKey,
  wrapKey,
} from "./crypto.ts";
import {
  LinkError,
  newKeyPair,
  openGrant,
  openRequest,
  pairingCode,
  sealGrant,
  sealRequest,
  type JoinRequest,
  type KeyPair,
  type PairingGrant,
  type PairingLink,
} from "./pairing.ts";
import { req, type Store } from "./store.ts";
import { SyncEngine, SyncError } from "./sync.ts";

/// Signed in, but the password no longer opens the vault (it was reset): the
/// recovery key is needed once to re-wrap the data key.
export class RecoveryKeyNeeded extends Error {
  constructor() {
    super("Enter your recovery key to unlock your synced data");
  }
}

/// What a signed-in device keeps: the same as the native apps' keychain.
export interface Session {
  email: string;
  userId: string;
  /// The server login secret derived from the password (never the password).
  secret: string;
  dataKey: Uint8Array;
}

/// Where the session lives: IndexedDB, or memory only for "forget me when I
/// close this tab".
export interface KeyStore {
  load(): Promise<Session | null>;
  save(s: Session): Promise<void>;
  clear(): Promise<void>;
}

export class MemoryKeyStore implements KeyStore {
  private s: Session | null = null;
  async load() {
    return this.s;
  }
  async save(s: Session) {
    this.s = s;
  }
  async clear() {
    this.s = null;
  }
}

/// The `keys` store of the local database. Plain IndexedDB: see SECURITY in
/// web/README.md for what that does and does not protect.
export class IdbKeyStore implements KeyStore {
  private store: Store;
  constructor(store: Store) {
    this.store = store;
  }
  async load(): Promise<Session | null> {
    const r = (await this.store.tx(["keys"], "readonly", (t) => req(t.objectStore("keys").get("session")))) as
      | { email: string; userId: string; secret: string; dataKey: string }
      | undefined;
    return r ? { email: r.email, userId: r.userId, secret: r.secret, dataKey: fromBase64(r.dataKey) } : null;
  }
  async save(s: Session) {
    const row = { key: "session", email: s.email, userId: s.userId, secret: s.secret, dataKey: toBase64(s.dataKey) };
    await this.store.tx(["keys"], "readwrite", (t) => req(t.objectStore("keys").put(row)));
  }
  async clear() {
    await this.store.tx(["keys"], "readwrite", (t) => req(t.objectStore("keys").delete("session")));
  }
}

/// The new device's side of a pairing in progress.
export interface JoinTicket {
  link: PairingLink;
  keyPair: KeyPair;
  /// Must match the code on the other device.
  code: string;
}

const PASSWORD = "password", RECOVERY = "recovery";

export class AccountService {
  readonly store: Store;
  keys: KeyStore;
  readonly server: string;
  /// Shown to the other device when pairing, inside the sealed request only.
  readonly deviceName: string;
  readonly platform = "web";
  private client: WorkerApi | null = null;
  private pending: { api: WorkerApi; kek: Uint8Array; secret: string; email: string; owner: string } | null = null;

  constructor(store: Store, keys: KeyStore, server: string, deviceName = "Web browser") {
    this.store = store;
    this.keys = keys;
    this.server = server;
    this.deviceName = deviceName;
  }

  session(): Promise<Session | null> {
    return this.keys.load();
  }

  /// Creates the account and its vault. Returns the recovery key, which the
  /// user must write down: it is shown once and never stored. Repeating a
  /// sign-up that stopped before its vault was created finishes it.
  async signUp(email: string, password: string, invite: string): Promise<string> {
    const keys = await fromPassword(email, password);
    const mail = email.trim().toLowerCase();
    const api = new WorkerApi(this.server);
    const ownerId = await api.register(mail, keys.authSecret, invite.trim());
    if ((await api.vault()) !== null) throw new SyncError("This e-mail already has an account: sign in instead");
    const dek = newDataKey();
    const recovery = newRecoveryKey();
    await api.createVault({
      wrappedPassword: wrapKey(dek, keys.kek, PASSWORD),
      wrappedRecovery: wrapKey(dek, recoveryKek(recovery), RECOVERY),
    });
    await this.finish(api, mail, keys.authSecret, ownerId, dek);
    return recovery;
  }

  /// Throws [RecoveryKeyNeeded] when the vault was wrapped under an older
  /// password; then call [unlockWithRecoveryKey].
  async signIn(email: string, password: string): Promise<void> {
    const keys = await fromPassword(email, password);
    const mail = email.trim().toLowerCase();
    const api = new WorkerApi(this.server);
    const ownerId = await api.login(mail, keys.authSecret);
    const v = await api.vault();
    if (!v) throw new SyncError("Account setup did not finish: sign up again with the same details");
    let dek: Uint8Array;
    try {
      dek = unwrapKey(v.wrappedPassword, keys.kek, PASSWORD);
    } catch (e) {
      if (!(e instanceof CryptoError)) throw e;
      this.pending = { api, kek: keys.kek, secret: keys.authSecret, email: mail, owner: ownerId };
      throw new RecoveryKeyNeeded();
    }
    await this.finish(api, mail, keys.authSecret, ownerId, dek);
  }

  /// After [RecoveryKeyNeeded]: opens the vault with the recovery key and
  /// re-wraps the data key under the current password.
  async unlockWithRecoveryKey(recoveryKey: string): Promise<void> {
    const p = this.pending;
    if (!p) throw new SyncError("Sign in first");
    const v = await p.api.vault();
    if (!v) throw new SyncError("Account setup did not finish: sign up again with the same details");
    const dek = unwrapKey(v.wrappedRecovery, recoveryKek(recoveryKey), RECOVERY);
    await p.api.rewrapVault(wrapKey(dek, p.kek, PASSWORD));
    await this.finish(p.api, p.email, p.secret, p.owner, dek);
  }

  /// Sets a new password from a reset code the owner made; the recovery key
  /// then re-opens the vault.
  async resetPassword(email: string, code: string, newPassword: string, recoveryKey: string): Promise<void> {
    // Reject a mistyped recovery key before anything changes on the server.
    recoveryKek(recoveryKey);
    const keys = await fromPassword(email, newPassword);
    await new WorkerApi(this.server).confirmReset(email.trim().toLowerCase(), code.trim(), keys.authSecret);
    try {
      await this.signIn(email, newPassword);
    } catch (e) {
      if (!(e instanceof RecoveryKeyNeeded)) throw e;
      await this.unlockWithRecoveryKey(recoveryKey);
    }
  }

  /// Changes the password and re-wraps the data key. If this stops half way,
  /// signing in with the new password asks for the recovery key once.
  async changePassword(oldPassword: string, newPassword: string): Promise<void> {
    const s = await this.keys.load();
    if (!s) throw new SyncError("Not signed in");
    const oldKeys = await fromPassword(s.email, oldPassword);
    const newKeys = await fromPassword(s.email, newPassword);
    const api = await this.api();
    const v = await api.vault();
    if (!v) throw new SyncError("No vault on the server");
    // Checked here too so a wrong old password fails before any change.
    unwrapKey(v.wrappedPassword, oldKeys.kek, PASSWORD);
    const wrapped = wrapKey(s.dataKey, newKeys.kek, PASSWORD);
    await api.changeSecret(oldKeys.authSecret, newKeys.authSecret);
    await this.keys.save({ ...s, secret: newKeys.authSecret });
    await api.rewrapVault(wrapped);
  }

  // Pairing. On the signed-in device: offerPairing, then poll pairingRequest,
  // then approvePairing or cancelPairing. On the new device: requestJoin,
  // poll joinGrant, then join.

  /// Opens a pairing record and returns the link to show as a QR code.
  async offerPairing(scheme = "bhojana"): Promise<PairingLink> {
    const api = await this.api();
    return { kind: "pair", server: this.server, id: await api.openPairing(), secret: randomBytes(32), scheme };
  }

  /// The request waiting on [link], or null while there is none.
  async pairingRequest(link: PairingLink): Promise<JoinRequest | null> {
    const r = await this.pairing(await this.api(), link.id, "This code has expired. Make a new one.");
    return r.request === "" ? null : openRequest(link, r.request);
  }

  /// Sends this account's keys to the device that made [request].
  async approvePairing(link: PairingLink, request: JoinRequest): Promise<void> {
    const s = await this.keys.load();
    if (!s) throw new SyncError("Not signed in");
    const grant: PairingGrant = { email: s.email, userId: s.userId, secret: s.secret, dataKey: s.dataKey };
    await (await this.api()).writeResponse(link.id, sealGrant(link, request.publicKey, grant));
  }

  /// Whether the new device has finished with [link] (it deletes the record).
  async pairingFinished(link: PairingLink): Promise<boolean> {
    try {
      await this.pairing(await this.api(), link.id, "");
      return false;
    } catch (e) {
      if (e instanceof PairingClosed) return true;
      throw e;
    }
  }

  /// Withdraws [link]; a device waiting on it is told it was declined.
  async cancelPairing(link: PairingLink): Promise<void> {
    await (await this.api()).closePairing(link.id);
  }

  /// On a new device: asks to join through [link]. The ticket's code must
  /// match the one the other device shows.
  async requestJoin(link: PairingLink): Promise<JoinTicket> {
    if (await this.keys.load()) throw new SyncError("This device already syncs. Sign out first.");
    if (link.server !== this.server) {
      throw new LinkError(`That link is for the server at ${link.server}. Open Bhojana there to join it.`);
    }
    const keyPair = newKeyPair();
    const sealed = sealRequest(link, { name: this.deviceName, platform: this.platform, publicKey: keyPair.publicKey });
    try {
      await new WorkerApi(link.server).writeRequest(link.id, sealed);
    } catch (e) {
      if (e instanceof PairingClosed) {
        throw new PairingClosed("This code has expired or was already used. Make a new one on your other device.");
      }
      throw e;
    }
    return { link, keyPair, code: pairingCode(link, keyPair.publicKey) };
  }

  /// The account the other device sent, once it approved; null while waiting.
  async joinGrant(ticket: JoinTicket): Promise<PairingGrant | null> {
    const r = await this.pairing(
      new WorkerApi(ticket.link.server),
      ticket.link.id,
      "The other device declined, or the code expired.",
    );
    return r.response === "" ? null : openGrant(ticket.link, ticket.keyPair, r.response);
  }

  /// Signs this device in with [grant] and closes the pairing.
  async join(ticket: JoinTicket, grant: PairingGrant): Promise<void> {
    const api = new WorkerApi(ticket.link.server);
    const ownerId = await api.login(grant.email, grant.secret);
    if (ownerId !== grant.userId || (await api.vault()) === null) {
      throw new SyncError("The other device sent keys for an account this server does not know");
    }
    await this.finish(api, grant.email, grant.secret, ownerId, grant.dataKey);
    try {
      await api.closePairing(ticket.link.id);
    } catch {
      // It expires on its own.
    }
  }

  private async pairing(api: WorkerApi, id: string, gone: string) {
    try {
      return await api.pairing(id);
    } catch (e) {
      if (e instanceof PairingClosed) throw new PairingClosed(gone);
      throw e;
    }
  }

  /// A sync engine for the signed-in account, or null when signed out. Ask for
  /// one per sync run: it signs in again when the server token expired.
  async engine(): Promise<SyncEngine | null> {
    const s = await this.keys.load();
    if (!s) return null;
    return new SyncEngine(this.store, (await this.api()).remote(), s.dataKey, s.userId);
  }

  /// Forgets the keys. The caller wipes the local copy of the data.
  async signOut(): Promise<void> {
    this.client = null;
    this.pending = null;
    await this.keys.clear();
  }

  /// The signed-in server connection.
  async api(): Promise<WorkerApi> {
    const s = await this.keys.load();
    if (!s) throw new SyncError("Not signed in");
    const api = (this.client ??= new WorkerApi(this.server));
    if (!api.signedIn) {
      try {
        await api.login(s.email, s.secret);
      } catch (e) {
        if (e instanceof SignInAgain) {
          throw new SignInAgain("Your password changed on another device. Sign in again with the new one.");
        }
        throw e;
      }
    }
    return api;
  }

  /// Keeps the keys on this device and registers it with the account.
  private async finish(api: WorkerApi, email: string, secret: string, ownerId: string, dek: Uint8Array) {
    // Another account's change log must not continue this device's numbers
    // or receive its rows: start over as a new device.
    const had = await this.store.setting("sync.owner");
    if (had && had !== ownerId) await this.store.resetDevice();
    await this.store.setSetting("sync.owner", ownerId);
    await api.addDevice(this.store.deviceId, this.platform);
    await this.keys.save({ email, userId: ownerId, secret, dataKey: dek });
    this.client = api;
    this.pending = null;
  }
}
