import type { Platform, Provider } from "../types.ts";
import type { Adapter, OAuthFlow } from "./adapter.ts";
import { bluesky } from "./bluesky.ts";
import { linkedin, linkedinOAuth } from "./linkedin.ts";
import { mastodon } from "./mastodon.ts";
import { facebook, instagram, metaOAuth } from "./meta.ts";
import { threads, threadsOAuth } from "./threads.ts";
import { telegram } from "./telegram.ts";
import { googleOAuth, youtube } from "./youtube.ts";

export const adapters: Record<Platform, Adapter> = { instagram, facebook, youtube, linkedin, threads, bluesky, mastodon, telegram };

export const oauthFlows: Record<Provider, OAuthFlow> = { meta: metaOAuth, threads: threadsOAuth, google: googleOAuth, linkedin: linkedinOAuth };
