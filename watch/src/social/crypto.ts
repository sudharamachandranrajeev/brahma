// Secrets at rest and signed links. TOKEN_KEY is 32 random bytes (base64),
// kept as a Worker secret and in ~/.config/brahma/watch.env.

const enc = new TextEncoder();
const dec = new TextDecoder();

const b64 = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes));
const unb64 = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
const b64url = (bytes: Uint8Array) => b64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

function rawKey(tokenKey: string): Uint8Array<ArrayBuffer> {
  const raw = unb64(tokenKey);
  if (raw.byteLength !== 32) throw new Error("TOKEN_KEY must be 32 bytes, base64");
  return raw;
}

const aesKeys = new Map<string, Promise<CryptoKey>>();
const aesKey = (tokenKey: string) => {
  let k = aesKeys.get(tokenKey);
  if (!k) {
    k = crypto.subtle.importKey("raw", rawKey(tokenKey), "AES-GCM", false, ["encrypt", "decrypt"]);
    aesKeys.set(tokenKey, k);
  }
  return k;
};

/** Encrypts a JSON value; the output is "v1.<iv>.<ciphertext>". */
export async function seal(tokenKey: string, value: unknown): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, await aesKey(tokenKey), enc.encode(JSON.stringify(value)));
  return `v1.${b64(iv)}.${b64(new Uint8Array(ct))}`;
}

export async function open<T>(tokenKey: string, sealed: string): Promise<T> {
  const [v, iv, ct] = sealed.split(".");
  if (v !== "v1" || !iv || !ct) throw new Error("unknown secret format");
  const pt = await crypto.subtle.decrypt({ name: "AES-GCM", iv: unb64(iv) }, await aesKey(tokenKey), unb64(ct));
  return JSON.parse(dec.decode(pt)) as T;
}

async function hmac(key: Uint8Array<ArrayBuffer> | string, data: string): Promise<Uint8Array<ArrayBuffer>> {
  const k = await crypto.subtle.importKey(
    "raw",
    typeof key === "string" ? enc.encode(key) : key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(await crypto.subtle.sign("HMAC", k, enc.encode(data)));
}

/** Constant-time comparison, so timing does not leak how much matched. */
export function sameBytes(a: Uint8Array, b: Uint8Array): boolean {
  if (a.byteLength !== b.byteLength) return false;
  let diff = 0;
  for (let i = 0; i < a.byteLength; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

export const sameText = (a: string, b: string) => sameBytes(enc.encode(a), enc.encode(b));

/** Signs a media path so platforms can fetch it without the API token, until it expires. */
export async function signMedia(tokenKey: string, id: string, expiresAt: number): Promise<string> {
  const mediaKey = await hmac(rawKey(tokenKey), "media");
  return b64url(await hmac(mediaKey, `${id}.${expiresAt}`));
}

export async function mediaSignatureOk(tokenKey: string, id: string, exp: string | null, sig: string | null, now = Date.now()) {
  const expiresAt = Number(exp);
  if (!sig || !Number.isFinite(expiresAt) || expiresAt < now / 1000) return false;
  return sameText(sig, await signMedia(tokenKey, id, expiresAt));
}

/** The token Meta echoes when subscribing a webhook; derived, so there is no extra secret to keep. */
export async function webhookVerifyToken(tokenKey: string): Promise<string> {
  return b64url(await hmac(rawKey(tokenKey), "webhook-verify")).slice(0, 32);
}

/** Meta signs webhook bodies with the app secret: X-Hub-Signature-256: sha256=<hex>. */
export async function metaSignatureOk(appSecret: string, body: string, header: string | null): Promise<boolean> {
  if (!header?.startsWith("sha256=")) return false;
  const hex = [...(await hmac(appSecret, body))].map((b) => b.toString(16).padStart(2, "0")).join("");
  return sameText(header.slice(7), hex);
}

export function randomToken(bytes = 24): string {
  return b64url(crypto.getRandomValues(new Uint8Array(bytes)));
}

/** Short stable id from text (for rows keyed by platform ids). */
export async function hashId(text: string): Promise<string> {
  const d = new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(text)));
  return b64url(d.slice(0, 15));
}

/** PKCE (RFC 7636) verifier and S256 challenge. */
export async function pkce(): Promise<{ verifier: string; challenge: string }> {
  const verifier = randomToken(48);
  const challenge = b64url(new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(verifier))));
  return { verifier, challenge };
}
