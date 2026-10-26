// Device pairing and sync links, as brahma_core's pairing.dart:
//
// * `<app>://setup?s=<server>&i=<invite>`: printed by the server, to create
//   the first account.
// * `<app>://pair?s=<server>&p=<record>&k=<secret>`: shown by a signed-in
//   device so another one can join it.
//
// 1. The old device opens a pairing record (10 minutes, one request) and
//    shows its link as a QR code.
// 2. The new device makes an X25519 key pair and writes its name and public
//    key into the record, sealed under a key derived from the link secret.
// 3. Both show a 6-digit code from the secret and that public key; the user
//    checks they match and approves on the old device.
// 4. The old device seals the account keys to the new device's public key
//    (X25519 with a fresh key, HKDF salted with the link secret).
// 5. The new device opens them, signs in and deletes the record.
import { x25519 } from "@noble/curves/ed25519.js";
import { sha256 } from "@noble/hashes/sha2.js";
import {
  CryptoError,
  deriveKey,
  encodeUtf8,
  fromBase64,
  openJson,
  sealJson,
  toBase64,
  toBase64Url,
  VERSION,
} from "./crypto.ts";

export class LinkError extends Error {}

const OTHER_SCHEMES = new Set(["http", "https", "file", "mailto", "tel", "sms", "data", "content", "intent"]);

/// Any Brahma app's scheme is accepted: the links are about the shared account.
export const isBrahmaScheme = (s: string) => /^[a-z][a-z0-9]*$/.test(s) && !OTHER_SCHEMES.has(s);

export interface SetupLink {
  kind: "setup";
  server: string;
  invite: string;
}

export interface PairingLink {
  kind: "pair";
  server: string;
  /// The pairing record on the server.
  id: string;
  /// 32 random bytes the server never sees.
  secret: Uint8Array;
  scheme: string;
}

/// Origin of a server address, refusing what the native apps refuse: plain
/// http outside the user's own network.
export function serverOrigin(input: string): string {
  let url: URL;
  try {
    url = new URL(input.trim());
  } catch {
    throw new LinkError("Enter a server address like https://sync.example.com");
  }
  if (!url.hostname || url.username || url.password) {
    throw new LinkError("Enter a server address like https://sync.example.com");
  }
  if (url.protocol === "https:" || (url.protocol === "http:" && isLocalHost(url.hostname))) return url.origin;
  throw new LinkError("Use https:// for servers outside your own network");
}

function isLocalHost(host: string): boolean {
  if (host === "localhost" || host.endsWith(".local")) return true;
  const v4 = /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/.exec(host)?.slice(1).map(Number);
  if (v4) {
    const [a, b] = v4;
    return a === 127 || a === 10 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127);
  }
  const v6 = host.replace(/^\[|\]$/g, "").toLowerCase();
  return v6 === "::1" || /^f[cd]/.test(v6) || /^fe[89ab]/.test(v6);
}

/// Reads a link from pasted text or a scanned code. Line breaks and spaces
/// that chat apps add are ignored.
export function parseLink(text: string): SetupLink | PairingLink {
  const clean = text.replace(/\s/g, "");
  const m = /^([a-z][a-z0-9]*):\/\/([^/?#]*)\/?\?(.*)$/i.exec(clean);
  if (!m || !isBrahmaScheme(m[1])) {
    throw new LinkError("That is not a sync link. It starts with an app's name, like bhojana://");
  }
  const q = new URLSearchParams(m[3]);
  const server = q.get("s");
  if (!server) throw new LinkError("That link has no server address");
  switch (m[2]) {
    case "setup": {
      const invite = q.get("i") ?? "";
      if (!invite) throw new LinkError("That setup link has no invite code");
      return { kind: "setup", server: serverOrigin(server), invite };
    }
    case "pair": {
      const id = q.get("p") ?? "";
      let secret: Uint8Array | null = null;
      try {
        secret = fromBase64(q.get("k") ?? "");
      } catch {
        secret = null;
      }
      if (!/^[a-z0-9]{15}$/.test(id) || !secret || secret.length !== 32) {
        throw new LinkError("That pairing link is incomplete. Copy the whole link again");
      }
      return { kind: "pair", server: serverOrigin(server), id, secret, scheme: m[1] };
    }
  }
  throw new LinkError("This version does not know that link. Update the app and try again");
}

/// The link text, as Dart's `Uri(queryParameters: …)` writes it.
export function pairingLinkText(l: PairingLink): string {
  const q = new URLSearchParams({ s: l.server, p: l.id, k: toBase64Url(l.secret) });
  return `${l.scheme}://pair?${q}`;
}

export interface JoinRequest {
  name: string;
  platform: string;
  publicKey: Uint8Array;
}

/// What the old device answers with: everything a signed-in device keeps.
export interface PairingGrant {
  email: string;
  userId: string;
  /// The server login secret derived from the password (never the password).
  secret: string;
  dataKey: Uint8Array;
}

export interface KeyPair {
  secretKey: Uint8Array;
  publicKey: Uint8Array;
}

/// A key pair from a 32-byte seed (clamped as X25519 requires), or a fresh one.
export function newKeyPair(seed?: Uint8Array): KeyPair {
  const secretKey = seed ?? x25519.utils.randomSecretKey();
  return { secretKey, publicKey: x25519.getPublicKey(secretKey) };
}

const requestKey = (link: PairingLink) => deriveKey(link.secret, `${VERSION}|pair|request-key|${link.id}`);
const clip = (s: string) => (s.length > 60 ? s.substring(0, 60) : s);

export const sealRequest = (link: PairingLink, r: JoinRequest) =>
  sealJson(
    { name: r.name, platform: r.platform, key: toBase64(r.publicKey) },
    requestKey(link),
    `${VERSION}|pair|request|${link.id}`,
  );

export function openRequest(link: PairingLink, sealed: string): JoinRequest {
  const error = "The join request did not come from this pairing code";
  const json = openJson(sealed, requestKey(link), `${VERSION}|pair|request|${link.id}`, error);
  try {
    const m = json as Record<string, unknown>;
    const key = fromBase64(m.key as string);
    if (key.length !== 32) throw new Error();
    return {
      name: clip(typeof m.name === "string" ? m.name : ""),
      platform: clip(typeof m.platform === "string" ? m.platform : ""),
      publicKey: key,
    };
  } catch {
    throw new CryptoError(error);
  }
}

/// Six digits both devices show, e.g. "482 913". They match only when the
/// approving device received this exact public key.
export function pairingCode(link: PairingLink, publicKey: Uint8Array): string {
  const label = encodeUtf8(`${VERSION}|pair|code|`);
  const h = sha256(Uint8Array.from([...label, ...link.secret, ...publicKey]));
  const n = (((h[0] << 24) >>> 0) + (h[1] << 16) + (h[2] << 8) + h[3]) % 1000000;
  const s = String(n).padStart(6, "0");
  return `${s.substring(0, 3)} ${s.substring(3)}`;
}

/// Both sides derive this from the X25519 secret; [from] and [to] (the
/// sender's and recipient's public keys) are bound in.
function grantKey(link: PairingLink, own: Uint8Array, other: Uint8Array, from: Uint8Array, to: Uint8Array) {
  let shared: Uint8Array;
  try {
    shared = x25519.getSharedSecret(own, other);
  } catch {
    // noble refuses low-order keys, whose secret anyone can compute.
    throw new CryptoError("The other device sent an invalid key");
  }
  if (shared.every((b) => b === 0)) throw new CryptoError("The other device sent an invalid key");
  return deriveKey(shared, `${VERSION}|pair|grant-key|${link.id}|${toBase64(from)}|${toBase64(to)}`, link.secret);
}

export function sealGrant(link: PairingLink, recipient: Uint8Array, g: PairingGrant, mine = newKeyPair()): string {
  const key = grantKey(link, mine.secretKey, recipient, mine.publicKey, recipient);
  const box = sealJson(
    { email: g.email, userId: g.userId, secret: g.secret, dek: toBase64(g.dataKey) },
    key,
    `${VERSION}|pair|grant|${link.id}`,
  );
  return JSON.stringify({ key: toBase64(mine.publicKey), box });
}

export function openGrant(link: PairingLink, keyPair: KeyPair, sealed: string): PairingGrant {
  const error = "The keys from the other device could not be opened";
  try {
    const outer = JSON.parse(sealed) as Record<string, unknown>;
    const sender = fromBase64(outer.key as string);
    const key = grantKey(link, keyPair.secretKey, sender, sender, keyPair.publicKey);
    const m = openJson(outer.box as string, key, `${VERSION}|pair|grant|${link.id}`, error) as Record<string, unknown>;
    const dek = fromBase64(m.dek as string);
    if (dek.length !== 32 || typeof m.email !== "string" || typeof m.userId !== "string" || typeof m.secret !== "string") {
      throw new Error();
    }
    return { email: m.email, userId: m.userId, secret: m.secret, dataKey: dek };
  } catch (e) {
    if (e instanceof CryptoError) throw e;
    throw new CryptoError(error);
  }
}
