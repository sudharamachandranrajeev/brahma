// Media library on R2. Uploads are always multipart (Workers take request
// bodies up to 100 MB, videos can be far bigger), parts of `partSize` bytes.

import { signMedia } from "./crypto.ts";
import { InputError } from "./http.ts";
import type { MediaFile } from "./platforms/adapter.ts";
import { newId, nowIso, type Store } from "./store.ts";
import type { Media } from "./types.ts";

export const partSize = 20 * 1024 * 1024;
const maxSize = 4 * 1024 * 1024 * 1024;
const allowed = /^(image\/(jpeg|png|webp|gif|heic)|video\/(mp4|quicktime|webm))$/;

export const mediaKey = (id: string) => `media/${id}`;
const key = mediaKey;

/** A link platforms (and the app) can fetch for [hours] without the API token. */
export async function signedUrl(store: Store, id: string, hours = 24): Promise<string> {
  const exp = Math.floor(Date.now() / 1000) + hours * 3600;
  const sig = await signMedia(store.env.TOKEN_KEY, id, exp);
  return `${store.env.PUBLIC_URL}/media/${id}?exp=${exp}&sig=${sig}`;
}

export async function withUrl(store: Store, m: Omit<Media, "url">): Promise<Media> {
  return { ...m, url: await signedUrl(store, m.id) };
}

export async function startUpload(store: Store, input: { filename: string; contentType: string; size: number }) {
  const problems: string[] = [];
  if (!allowed.test(input.contentType)) problems.push(`${input.contentType} is not a supported image or video type`);
  if (!(input.size > 0 && input.size <= maxSize)) problems.push("size must be between 1 byte and 4 GB");
  if (problems.length) throw new InputError("media rejected", problems);
  const id = newId();
  const upload = await store.env.MEDIA.createMultipartUpload(key(id), { httpMetadata: { contentType: input.contentType } });
  const media: Omit<Media, "url"> = {
    id,
    filename: input.filename.replace(/[^\w.\- ]+/g, "_").slice(0, 120) || "file",
    contentType: input.contentType,
    size: input.size,
    status: "uploading",
    createdAt: nowIso(),
  };
  await store.putMedia(media, upload.uploadId);
  return { media: await withUrl(store, media), partSize };
}

async function pending(store: Store, id: string) {
  const m = await store.media(id);
  if (!m) throw new InputError("no such media", [], 404);
  if (!m.uploadId) throw new InputError("upload already complete", [], 409);
  return { m, upload: store.env.MEDIA.resumeMultipartUpload(key(id), m.uploadId) };
}

export async function uploadPart(store: Store, id: string, n: number, body: ReadableStream | null, length: number) {
  const { m, upload } = await pending(store, id);
  const parts = Math.ceil(m.size / partSize);
  if (!Number.isInteger(n) || n < 1 || n > parts) throw new InputError(`part must be 1..${parts}`);
  const expected = n < parts ? partSize : m.size - partSize * (parts - 1);
  if (!body || length !== expected) throw new InputError(`part ${n} must be ${expected} bytes`);
  const part = await upload.uploadPart(n, body);
  return { etag: part.etag };
}

export async function completeUpload(store: Store, id: string, parts: { n: number; etag: string }[]) {
  const { m, upload } = await pending(store, id);
  if (parts.length !== Math.ceil(m.size / partSize)) throw new InputError("every part must be uploaded first");
  await upload.complete(parts.map((p) => ({ partNumber: p.n, etag: p.etag })));
  const done: Omit<Media, "url"> = { ...m, status: "ready" };
  delete (done as { uploadId?: string }).uploadId;
  await store.putMedia(done, null);
  return withUrl(store, done);
}

export async function setAlt(store: Store, id: string, alt: string): Promise<Media> {
  const m = await store.media(id);
  if (!m) throw new InputError("no such media", [], 404);
  const { uploadId, ...media } = m;
  const next = { ...media, alt: alt.trim() || undefined };
  await store.putMedia(next, uploadId);
  return withUrl(store, next);
}

export async function deleteMedia(store: Store, id: string) {
  const m = await store.media(id);
  if (!m) return;
  if (m.uploadId) await store.env.MEDIA.resumeMultipartUpload(key(id), m.uploadId).abort().catch(() => {});
  await store.env.MEDIA.delete(key(id));
  await store.deleteMedia(id);
}

/** Files for publishing, in the post's order. Links last a few hours: long enough for platforms to fetch. */
export async function mediaFiles(store: Store, ids: string[]): Promise<MediaFile[]> {
  const out: MediaFile[] = [];
  for (const id of ids) {
    const m = await store.media(id);
    if (!m || m.status !== "ready") throw new InputError(`media ${id} is missing or still uploading`);
    out.push({ id, key: key(id), url: await signedUrl(store, id, 6), contentType: m.contentType, size: m.size, filename: m.filename, alt: m.alt ?? "" });
  }
  return out;
}

/** Serves a signed media link (range requests too: video players and platforms use them). */
export async function serve(store: Store, id: string, req: Request): Promise<Response> {
  const range = req.headers.get("range");
  const obj = await store.env.MEDIA.get(key(id), range ? { range: req.headers } : undefined);
  if (!obj) return new Response("not found", { status: 404 });
  const headers = new Headers();
  obj.writeHttpMetadata(headers);
  headers.set("etag", obj.httpEtag);
  headers.set("accept-ranges", "bytes");
  headers.set("cache-control", "private, max-age=3600");
  if (range && obj.range && "offset" in obj.range) {
    const offset = obj.range.offset ?? 0;
    const length = obj.range.length ?? obj.size - offset;
    headers.set("content-range", `bytes ${offset}-${offset + length - 1}/${obj.size}`);
    return new Response(obj.body, { status: 206, headers });
  }
  return new Response(obj.body, { headers });
}
