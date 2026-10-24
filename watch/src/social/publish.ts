// Posts: validation, scheduling, and the publishing state machine.
//
// Reliability rules (the failures people hate most in schedulers):
// - every failure raises an alert; nothing fails silently;
// - transient errors before the point of no return retry with backoff,
//   reusing platform containers;
// - an error after the post may already be live is never retried blindly:
//   the target is marked `maybePosted` and waits for the owner;
// - a run holds a lock on the post, so two runs never publish it twice.

import { z } from "zod";
import { markBroken } from "./accounts.ts";
import { raise, type NewAlert } from "./alerts.ts";
import { InputError, OutOfBudget, PlatformError } from "./http.ts";
import { mediaFiles } from "./media.ts";
import { platformInfo, type Ctx } from "./platforms/adapter.ts";
import { adapters } from "./platforms/index.ts";
import { nextSlot } from "./schedule.ts";
import { getSettings } from "./settings.ts";
import { newId, type Store } from "./store.ts";
import type { Post, Target, TargetStatus } from "./types.ts";

const maxAttempts = 5;

export const postInput = z.object({
  text: z.string().max(70000),
  media: z.array(z.string().max(64)).max(10),
  targets: z
    .array(
      z.object({
        accountId: z.string().max(64),
        format: z.enum(["post", "carousel", "reel", "story", "video", "short"]),
        text: z.string().max(70000).optional(),
        title: z.string().max(200).optional(),
        firstComment: z.string().max(5000).optional(),
      }),
    )
    .min(1)
    .max(30),
  scheduledAt: z.iso.datetime({ offset: true }).nullable().optional(),
  queue: z.boolean().optional(),
  draft: z.boolean().optional(),
  recycleDays: z.number().int().min(1).max(365).optional(),
  tags: z.array(z.string().max(60)).max(30).optional(),
});
export type PostInput = z.infer<typeof postInput>;

const graphemes = (s: string) => [...new Intl.Segmenter().segment(s)].length;

/** Everything a platform would reject, found before the post is saved. */
export async function problemsWith(store: Store, input: PostInput): Promise<string[]> {
  const problems: string[] = [];
  const accounts = new Map((await store.accounts()).map((a) => [a.id, a]));
  const media = await Promise.all(input.media.map((id) => store.media(id)));
  media.forEach((m, i) => {
    if (!m) problems.push(`media ${input.media[i]} does not exist`);
    else if (m.status !== "ready") problems.push(`${m.filename} is still uploading`);
  });
  const videos = media.filter((m) => m?.contentType.startsWith("video/")).length;
  const images = media.filter((m) => m?.contentType.startsWith("image/")).length;
  const seen = new Set<string>();
  for (const t of input.targets) {
    const a = accounts.get(t.accountId);
    if (!a) {
      problems.push(`account ${t.accountId} is not connected`);
      continue;
    }
    if (seen.has(t.accountId)) problems.push(`${a.name} is listed twice`);
    seen.add(t.accountId);
    const info = platformInfo[a.platform];
    const where = `${info.name} (${a.handle})`;
    const text = t.text ?? input.text;
    if (!info.formats.includes(t.format)) problems.push(`${where} can't take a ${t.format}`);
    const length = a.platform === "bluesky" ? graphemes(text) : text.length;
    if (length > info.maxText) problems.push(`${where}: text is ${length} characters, the limit is ${info.maxText}`);
    if (info.mediaRequired.includes(t.format) && !input.media.length) problems.push(`${where}: a ${t.format} needs a photo or video`);
    if (input.media.length > info.maxMedia) problems.push(`${where} takes at most ${info.maxMedia} files`);
    if ((t.format === "reel" || t.format === "video" || t.format === "short") && videos !== 1) problems.push(`${where}: a ${t.format} needs exactly one video`);
    if (t.format === "story" && input.media.length !== 1) problems.push(`${where}: a story takes exactly one photo or video`);
    if (t.format === "carousel" && input.media.length < 2) problems.push(`${where}: a carousel needs 2 or more files`);
    if (t.format === "post" && a.platform === "instagram" && input.media.length > 1) problems.push(`${where}: use a carousel for several files`);
    if (a.platform === "youtube" && !t.title?.trim()) problems.push(`${where}: a title is needed`);
    if (a.platform === "bluesky" && videos > 0) problems.push(`${where}: video is not supported here yet`);
    if (a.platform === "linkedin" && videos > 0 && images > 0) problems.push(`${where}: a post has either images or one video`);
    if (!text.trim() && !input.media.length) problems.push(`${where}: nothing to post`);
    if (!a.capabilities.includes("publish")) problems.push(`${where} can't publish`);
  }
  return problems;
}

/** A post's overall status from its targets. */
export function overall(targets: Target[]): TargetStatus {
  const has = (s: TargetStatus) => targets.some((t) => t.status === s);
  if (has("publishing")) return "publishing";
  if (has("scheduled")) return "scheduled";
  if (has("failed")) return "failed";
  if (has("draft")) return "draft";
  return "published";
}

async function scheduleTime(store: Store, input: PostInput, now: Date): Promise<string | null> {
  if (input.draft) return null;
  if (input.queue) {
    const settings = await getSettings(store);
    const slot = nextSlot(settings.timezone, settings.queue, await store.scheduledTimes(now.toISOString()), now);
    if (!slot) throw new InputError("no free queue slot: add posting times in Settings");
    return slot.toISOString();
  }
  return input.scheduledAt ? new Date(input.scheduledAt).toISOString() : now.toISOString();
}

export async function savePost(store: Store, input: PostInput, existing: Post | null, now = new Date()): Promise<Post> {
  if (existing && (existing.status === "publishing" || existing.status === "published")) {
    throw new InputError(`this post is ${existing.status} and can't be changed`, [], 409);
  }
  const problems = await problemsWith(store, input);
  if (problems.length) throw new InputError("the post can't go out as it is", problems);
  const scheduledAt = await scheduleTime(store, input, now);
  const status: TargetStatus = input.draft ? "draft" : "scheduled";
  const post: Post = {
    id: existing?.id ?? newId(),
    text: input.text,
    media: input.media,
    targets: input.targets.map((t) => ({ ...t, status, attempts: 0 })),
    scheduledAt,
    status,
    recycleDays: input.recycleDays,
    tags: input.tags ?? [],
    createdAt: existing?.createdAt ?? now.toISOString(),
    updatedAt: now.toISOString(),
  };
  await store.savePost(post);
  return post;
}

/** Makes failed targets due again. Ones that may already be live need [force]. */
export async function retryPost(store: Store, post: Post, force: boolean, now = new Date()): Promise<Post> {
  let any = false;
  for (const t of post.targets) {
    if (t.status !== "failed" || (t.maybePosted && !force)) continue;
    Object.assign(t, { status: "scheduled", attempts: 0, error: undefined, maybePosted: undefined });
    any = true;
  }
  if (!any) throw new InputError("nothing to retry (targets that may have posted need force)", [], 409);
  post.status = overall(post.targets);
  if (!post.scheduledAt || post.scheduledAt > now.toISOString()) post.scheduledAt = now.toISOString();
  post.updatedAt = now.toISOString();
  await store.savePost(post);
  await store.setLock(post.id, null);
  return post;
}

function describe(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

/**
 * Publishes every due target of [post]. Takes the post's lock first; returns
 * the post as it ended up (or null if another run holds it).
 */
export async function publishPost(ctx: Ctx, postId: string): Promise<Post | null> {
  const { store } = ctx;
  const now = ctx.now;
  if (!(await store.lockPost(postId, now.toISOString(), new Date(now.getTime() + 15 * 60000).toISOString()))) return null;
  const post = await store.post(postId);
  if (!post) return null;
  const alerts: NewAlert[] = [];
  let retryInMinutes = 0;
  let outOfBudget = false;
  let media: Awaited<ReturnType<typeof mediaFiles>> | null = null;

  for (const target of post.targets) {
    if (target.status !== "scheduled" || outOfBudget) continue;
    const account = await store.account(target.accountId);
    if (!account) {
      Object.assign(target, { status: "failed", error: "The account was removed" });
      continue;
    }
    let committed = false;
    target.status = "publishing";
    target.attempts += 1;
    post.status = "publishing";
    await store.savePost(post);
    try {
      media ??= await mediaFiles(store, post.media);
      const result = await adapters[account.platform].publish(
        ctx,
        account,
        { post, target, text: target.text ?? post.text, media },
        {
          saveContainer: async (id) => {
            target.containerId = id;
            await store.savePost(post);
          },
          commit: () => {
            committed = true;
          },
        },
      );
      Object.assign(target, {
        status: "published",
        remoteId: result.remoteId,
        permalink: result.permalink ?? undefined,
        publishedAt: new Date().toISOString(),
        error: undefined,
        maybePosted: undefined,
      });
      if (target.firstComment?.trim()) {
        try {
          await adapters[account.platform].comment?.(ctx, account, result.remoteId, target.firstComment);
        } catch (err) {
          target.error = `Posted, but the first comment failed: ${describe(err)}`;
        }
      }
    } catch (err) {
      if (err instanceof OutOfBudget) {
        target.attempts -= 1;
        target.status = "scheduled";
        outOfBudget = true;
        continue;
      }
      const platformErr = err instanceof PlatformError ? err : null;
      const transient = platformErr?.transient ?? false;
      if (platformErr?.auth) await markBroken(ctx, account, platformErr.message, alerts);
      if (committed && transient) {
        Object.assign(target, { status: "failed", error: describe(err), maybePosted: true });
      } else if (transient && !committed && target.attempts < maxAttempts) {
        Object.assign(target, { status: "scheduled", error: describe(err) });
        retryInMinutes = Math.max(retryInMinutes, 2 ** target.attempts);
        continue;
      } else {
        Object.assign(target, { status: "failed", error: describe(err) });
      }
      alerts.push({
        kind: "publish",
        title: `Post failed on ${platformInfo[account.platform].name} (${account.handle})`,
        body: target.maybePosted
          ? `${target.error}\nIt may have gone out anyway: check before retrying.`
          : (target.error ?? ""),
        url: null,
        image: null,
        ref: post.id,
      });
    } finally {
      await store.savePost(post);
    }
  }

  post.status = overall(post.targets);
  post.updatedAt = new Date().toISOString();
  await store.savePost(post);
  // Out of budget: carry on next minute. Transient failures: back off.
  const holdMinutes = outOfBudget ? 1 : retryInMinutes;
  await store.setLock(post.id, holdMinutes ? new Date(now.getTime() + holdMinutes * 60000).toISOString() : null);
  if (post.status === "published" && post.recycleDays) await recycle(store, post, now);
  if (alerts.length) await raise(ctx.env, store, alerts);
  return post;
}

/** Evergreen posts go back in the queue [recycleDays] after publishing. */
async function recycle(store: Store, post: Post, now: Date) {
  const settings = await getSettings(store);
  const after = new Date(now.getTime() + post.recycleDays! * 86400_000);
  const slot = nextSlot(settings.timezone, settings.queue, await store.scheduledTimes(after.toISOString()), after) ?? after;
  await store.savePost({
    ...post,
    id: newId(),
    targets: post.targets.map((t) => ({
      accountId: t.accountId,
      format: t.format,
      text: t.text,
      title: t.title,
      firstComment: t.firstComment,
      status: "scheduled",
      attempts: 0,
    })),
    scheduledAt: slot.toISOString(),
    status: "scheduled",
    createdAt: now.toISOString(),
    updatedAt: now.toISOString(),
  });
}

/** The cron's publishing pass. */
export async function publishDue(ctx: Ctx): Promise<number> {
  let n = 0;
  for (const p of await ctx.store.duePosts(ctx.now.toISOString())) {
    if (ctx.budget.left < 3) break;
    if (await publishPost(ctx, p.id)) n++;
  }
  return n;
}
