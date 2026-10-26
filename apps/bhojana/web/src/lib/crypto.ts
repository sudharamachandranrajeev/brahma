// End-to-end encryption for sync, byte for byte the same as brahma_core's
// VaultCrypto (core/lib/src/security/crypto.dart), so the browser is one more
// device of the same account:
//
// password --Argon2id--> master --HKDF--> auth secret (server login)
//                                    \--> KEK, which wraps a random data key
// The data key (DEK) encrypts every change with XChaCha20-Poly1305. A
// recovery key wraps the same DEK so a forgotten password loses nothing.
import { xchacha20poly1305 } from "@noble/ciphers/chacha.js";
import { hkdf } from "@noble/hashes/hkdf.js";
import { sha256 } from "@noble/hashes/sha2.js";
import { argon2id } from "hash-wasm";

export class CryptoError extends Error {}

/// Shortest password accepted for a sync account. The password derives the
/// key that wraps the data key, so it is the main defence if the server leaks.
export const MIN_PASSWORD_LENGTH = 12;

/// Protocol label bound into every key derivation and ciphertext. It names the
/// first Brahma app, which created the format; it can never change.
export const VERSION = "artha/v1";

const utf8 = new TextEncoder();
const fromUtf8 = new TextDecoder("utf-8", { fatal: true });
export const encodeUtf8 = (s: string) => utf8.encode(s);
export const decodeUtf8 = (b: Uint8Array) => fromUtf8.decode(b);

export interface PasswordKeys {
  /// The only thing the server sees, as the account's login secret.
  authSecret: string;
  /// Never leaves this device.
  kek: Uint8Array;
}

export const randomBytes = (n: number) => crypto.getRandomValues(new Uint8Array(n));
export const newDataKey = () => randomBytes(32);

export const hex = (b: Uint8Array) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");

export function fromHex(s: string): Uint8Array {
  if (!/^(?:[0-9a-f]{2})*$/i.test(s)) throw new CryptoError("Not hex");
  return Uint8Array.from(s.match(/../g) ?? [], (h) => parseInt(h, 16));
}

/// Standard base64 with padding, as Dart's `base64.encode`.
export function toBase64(b: Uint8Array): string {
  let s = "";
  for (let i = 0; i < b.length; i += 0x8000) s += String.fromCharCode(...b.subarray(i, i + 0x8000));
  return btoa(s);
}

/// Reads standard or URL-safe base64, padded or not (Dart's base64 decoders
/// with `normalize` accept both).
export function fromBase64(s: string): Uint8Array {
  const std = s.replace(/-/g, "+").replace(/_/g, "/");
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(std) || std.replace(/=+$/, "").length % 4 === 1) {
    throw new CryptoError("Not base64");
  }
  const padded = std.replace(/=+$/, "").padEnd(Math.ceil(std.replace(/=+$/, "").length / 4) * 4, "=");
  return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
}

export const toBase64Url = (b: Uint8Array) => toBase64(b).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

/// HKDF-SHA256 to 32 bytes. An empty salt is HMAC with an empty key, which
/// RFC 5869 makes equal to the default all-zero salt; Dart's Hkdf does the same.
export const deriveKey = (secret: Uint8Array, info: string, salt: Uint8Array = new Uint8Array(0)) =>
  hkdf(sha256, secret, salt, utf8.encode(info), 32);

/// OWASP's minimum Argon2id profile (19 MiB, 2 passes); the salt is per
/// account, derived from the e-mail address.
export async function fromPassword(email: string, password: string): Promise<PasswordKeys> {
  if (password.length < MIN_PASSWORD_LENGTH) {
    throw new CryptoError(`Use a password of at least ${MIN_PASSWORD_LENGTH} characters`);
  }
  // Dart's String.length counts UTF-16 code units, as JS does, so the rule
  // above accepts exactly the same passwords.
  const salt = sha256(utf8.encode(`${VERSION}/${email.trim().toLowerCase()}`));
  const master = await argon2id({
    password: utf8.encode(password),
    salt,
    parallelism: 1,
    iterations: 2,
    memorySize: 19456,
    hashLength: 32,
    outputType: "binary",
  });
  return {
    authSecret: hex(deriveKey(master, "artha auth v1")),
    kek: deriveKey(master, "artha kek v1"),
  };
}

const ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

function base32(bytes: Uint8Array): string {
  let out = "", buffer = 0, bits = 0;
  for (const b of bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      out += ALPHABET[(buffer >> (bits - 5)) & 31];
      bits -= 5;
    }
    buffer &= (1 << bits) - 1;
  }
  if (bits > 0) out += ALPHABET[(buffer << (5 - bits)) & 31];
  return out;
}

/// Accepts lower case, spaces and dashes, and the usual misreadings (O for 0,
/// I/L for 1).
function unbase32(text: string): Uint8Array | null {
  const clean = text.toUpperCase().replace(/[\s-]/g, "").replace(/O/g, "0").replace(/[IL]/g, "1");
  const out: number[] = [];
  let buffer = 0, bits = 0;
  for (const ch of clean) {
    const v = ALPHABET.indexOf(ch);
    if (v < 0) return null;
    buffer = (buffer << 5) | v;
    bits += 5;
    if (bits >= 8) {
      out.push((buffer >> (bits - 8)) & 255);
      bits -= 8;
      buffer &= (1 << bits) - 1;
    }
  }
  return Uint8Array.from(out);
}

/// A new recovery key, e.g. "7KQ2-M9XD-…": 256 bits in Crockford base32.
export function newRecoveryKey(): string {
  return (base32(randomBytes(32)).match(/.{1,4}/g) as string[]).join("-");
}

export function recoveryKek(recoveryKey: string): Uint8Array {
  const bytes = unbase32(recoveryKey);
  if (!bytes || bytes.length !== 32) throw new CryptoError("That recovery key is not valid");
  return deriveKey(bytes, "artha recovery v1");
}

function encrypt(clear: Uint8Array, key: Uint8Array, aad: string): string {
  const nonce = randomBytes(24);
  const box = xchacha20poly1305(key, nonce, utf8.encode(aad)).encrypt(clear);
  const out = new Uint8Array(24 + box.length);
  out.set(nonce);
  out.set(box, 24);
  return toBase64(out);
}

function decrypt(data: string, key: Uint8Array, aad: string, error: string): Uint8Array {
  try {
    const all = fromBase64(data);
    if (all.length < 24 + 16) throw new CryptoError(error);
    return xchacha20poly1305(key, all.subarray(0, 24), utf8.encode(aad)).decrypt(all.subarray(24));
  } catch {
    throw new CryptoError(error);
  }
}

/// Encrypts [key] under [kek]; [purpose] is bound in, so a password wrap
/// cannot be passed off as a recovery wrap or the reverse.
export const wrapKey = (key: Uint8Array, kek: Uint8Array, purpose: "password" | "recovery") =>
  encrypt(key, kek, `${VERSION}|wrap|${purpose}`);

export const unwrapKey = (wrapped: string, kek: Uint8Array, purpose: "password" | "recovery") =>
  decrypt(wrapped, kek, `${VERSION}|wrap|${purpose}`, "Wrong password or recovery key");

async function pipe(bytes: Uint8Array, stream: CompressionStream | DecompressionStream): Promise<Uint8Array> {
  const out = new Response(new Blob([bytes as BlobPart]).stream().pipeThrough(stream));
  return new Uint8Array(await out.arrayBuffer());
}

export const gzip = (b: Uint8Array) => pipe(b, new CompressionStream("gzip"));
export const gunzip = (b: Uint8Array) => pipe(b, new DecompressionStream("gzip"));

/// Compresses and encrypts a JSON value. [aad] ties the ciphertext to its
/// place (owner, device, sequence), so the server cannot move it around.
export async function seal(json: unknown, dataKey: Uint8Array, aad: string): Promise<string> {
  return encrypt(await gzip(utf8.encode(JSON.stringify(json))), dataKey, aad);
}

export async function open(sealed: string, dataKey: Uint8Array, aad: string): Promise<unknown> {
  const clear = decrypt(sealed, dataKey, aad, "A synced change failed its integrity check");
  try {
    return JSON.parse(decodeUtf8(await gunzip(clear)));
  } catch {
    throw new CryptoError("A synced change failed its integrity check");
  }
}

/// A small JSON value under [key], bound to [aad] (pairing messages).
export const sealJson = (json: unknown, key: Uint8Array, aad: string) =>
  encrypt(utf8.encode(JSON.stringify(json)), key, aad);

export function openJson(sealed: string, key: Uint8Array, aad: string, error: string): unknown {
  const clear = decrypt(sealed, key, aad, error);
  try {
    return JSON.parse(decodeUtf8(clear));
  } catch {
    throw new CryptoError(error);
  }
}
