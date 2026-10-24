import { z } from "zod";
import { validZone } from "./schedule.ts";
import type { Store } from "./store.ts";
import type { DiscoveryWatch, InboxRule, Settings } from "./types.ts";

export const defaultModel = "claude-opus-5-5";

const defaults: Settings = { timezone: "Europe/London", queue: [], savedReplies: [], model: defaultModel };

export const settingsInput = z.object({
  timezone: z.string().max(64).refine(validZone, "unknown time zone"),
  queue: z.array(z.object({ day: z.number().int().min(0).max(6), time: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/) })).max(100),
  savedReplies: z.array(z.object({ id: z.string().max(64), title: z.string().max(100), text: z.string().max(5000) })).max(200),
  model: z.string().regex(/^claude-[a-z0-9-]+$/).max(64),
});

export async function getSettings(store: Store): Promise<Settings> {
  return { ...defaults, ...(await store.doc<Partial<Settings>>("settings", {})) };
}

export const rulesInput = z
  .array(
    z.object({
      id: z.string().regex(/^[\w-]{1,64}$/),
      name: z.string().min(1).max(100),
      enabled: z.boolean(),
      accountIds: z.array(z.string().max(64)).max(50).nullable(),
      keywords: z.array(z.string().min(1).max(100)).max(50),
      description: z.string().max(500).optional(),
      reply: z.string().max(2000).optional(),
      privateReply: z.string().max(1000).optional(),
      alert: z.boolean(),
    }),
  )
  .max(100);

export const getRules = (store: Store) => store.doc<InboxRule[]>("rules", []);

const source = z.discriminatedUnion("type", [
  z.object({
    type: z.literal("ebay"),
    query: z.string().min(1).max(200),
    categoryId: z.string().regex(/^\d{1,10}$/).optional(),
    postcode: z.string().max(12).optional(),
    radiusKm: z.number().min(1).max(500).optional(),
    maxPrice: z.number().min(0).optional(),
  }),
  z.object({
    type: z.literal("donedeal"),
    path: z.string().regex(/^\/[a-z0-9-]+(\/[a-z0-9-]+)*(\?[\w=&%+.,-]*)?$/i).max(300),
    maxPrice: z.number().min(0).optional(),
  }),
  z.object({ type: z.literal("instagram_hashtag"), accountId: z.string().max(64), hashtags: z.array(z.string().regex(/^[\p{L}\p{N}_]{1,100}$/u)).min(1).max(10) }),
  z.object({ type: z.literal("instagram_business"), accountId: z.string().max(64), usernames: z.array(z.string().regex(/^[\w.]{1,30}$/)).min(1).max(20) }),
  z.object({ type: z.literal("bluesky"), query: z.string().min(1).max(200) }),
  z.object({ type: z.literal("youtube"), accountId: z.string().max(64), query: z.string().min(1).max(200) }),
]);

export const watchInput = z.object({
  id: z.string().regex(/^[\w-]{1,64}$/),
  name: z.string().min(1).max(100),
  description: z.string().max(1000),
  sources: z.array(source).min(1).max(10),
  keywords: z.array(z.string().min(1).max(100)).max(50),
  ai: z.boolean(),
  everyMinutes: z.number().int().min(10).max(10080),
  paused: z.boolean(),
});

export const discoveryInput = z.array(watchInput).max(50);

export const getWatches = (store: Store) => store.doc<DiscoveryWatch[]>("discovery", []);
