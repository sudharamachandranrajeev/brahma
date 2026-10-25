// Profiles: separate workspaces on one hub. The API works in the profile
// named by the x-vani-profile header; the cron runs every profile in turn
// on one shared subrequest budget.

import { z } from "zod";
import { InputError } from "./http.ts";
import { mediaKey } from "./media.ts";
import type { Ctx } from "./platforms/adapter.ts";
import { defaultProfile, newId, nowIso } from "./store.ts";
import type { Profile } from "./types.ts";

export const profileHeader = "x-vani-profile";

export const profileInput = z.strictObject({ name: z.string().trim().min(1).max(40) });

/** The same request, inside another profile. */
export const inProfile = (ctx: Ctx, profile: string): Ctx => ({ ...ctx, store: ctx.store.forProfile(profile) });

/** The profile a request names (the default when it names none); 404 when there is no such profile. */
export async function requestProfile(ctx: Ctx, req: Request): Promise<Ctx> {
  const id = req.headers.get(profileHeader)?.trim() || defaultProfile;
  if (id !== defaultProfile && !(await ctx.store.profileById(id))) throw new InputError("no such profile", [], 404);
  return inProfile(ctx, id);
}

export async function addProfile(ctx: Ctx, name: string): Promise<Profile> {
  const profiles = await ctx.store.profiles();
  if (profiles.length >= 20) throw new InputError("a hub holds up to 20 profiles", [], 409);
  if (profiles.some((p) => p.name.toLowerCase() === name.toLowerCase())) throw new InputError(`there is already a profile called ${name}`, [], 409);
  const p: Profile = { id: newId(), name, createdAt: nowIso() };
  await ctx.store.putProfile(p);
  return p;
}

export async function renameProfile(ctx: Ctx, id: string, name: string): Promise<Profile> {
  const profiles = await ctx.store.profiles();
  const p = profiles.find((x) => x.id === id);
  if (!p) throw new InputError("no such profile", [], 404);
  if (profiles.some((x) => x.id !== id && x.name.toLowerCase() === name.toLowerCase())) {
    throw new InputError(`there is already a profile called ${name}`, [], 409);
  }
  const renamed = { ...p, name };
  await ctx.store.putProfile(renamed);
  return renamed;
}

/** Deletes a profile with its posts, media, inbox, alerts and settings. Its accounts must be removed first. */
export async function deleteProfile(ctx: Ctx, id: string): Promise<void> {
  if (id === defaultProfile) throw new InputError("the main profile can't be deleted", [], 409);
  if (!(await ctx.store.profileById(id))) throw new InputError("no such profile", [], 404);
  const store = ctx.store.forProfile(id);
  if ((await store.accounts()).length) throw new InputError("remove this profile's accounts first", [], 409);
  const media = await store.mediaIds();
  for (let i = 0; i < media.length; i += 1000) await ctx.env.MEDIA.delete(media.slice(i, i + 1000).map(mediaKey));
  await store.deleteProfile(id);
}

/**
 * Runs [fn] in every profile, each with the shared budget. The starting
 * profile rotates every 10 minutes so a busy one doesn't always go first.
 */
export async function eachProfile(ctx: Ctx, name: string, fn: (ctx: Ctx) => Promise<unknown>): Promise<void> {
  const ids = (await ctx.store.profiles()).map((p) => p.id);
  if (!ids.includes(defaultProfile)) ids.unshift(defaultProfile);
  const start = Math.floor(ctx.now.getTime() / 600_000) % ids.length;
  for (const id of [...ids.slice(start), ...ids.slice(0, start)]) {
    if (ctx.budget.left < 3) break;
    try {
      await fn(inProfile(ctx, id));
    } catch (err) {
      console.log(`${name} (${id}): ${err instanceof Error ? (err.stack ?? err.message) : err}`);
    }
  }
}
