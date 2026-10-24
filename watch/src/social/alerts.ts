import { sendNtfy } from "../notify.ts";
import { newId, type SocialEnv, type Store } from "./store.ts";
import type { Alert, AlertKind } from "./types.ts";

export type NewAlert = Omit<Alert, "id" | "at" | "read"> & { at?: string };

const tags: Record<AlertKind, string> = {
  discovery: "mag",
  inbox: "speech_balloon",
  publish: "warning",
  account: "key",
  system: "gear",
};

/** Records alerts and pushes each to the phone. A failed push does not lose the alert. */
export async function raise(env: SocialEnv, store: Store, alerts: NewAlert[], now = new Date().toISOString()): Promise<Alert[]> {
  const full: Alert[] = alerts.map((a) => ({ ...a, id: newId(), at: a.at ?? now, read: false }));
  await store.addAlerts(full);
  for (const a of full) {
    await sendNtfy(env.NTFY_SERVER ?? "https://ntfy.sh", env.NTFY_TOKEN, {
      topic: env.NTFY_TOPIC,
      title: a.title.slice(0, 200),
      message: a.body.slice(0, 1000) || a.title,
      tags: [tags[a.kind]],
      priority: a.kind === "publish" || a.kind === "account" ? 4 : 3,
      ...(a.url ? { click: a.url, actions: [{ action: "view", label: "Open", url: a.url }] } : {}),
      ...(a.image ? { attach: a.image } : {}),
    }).catch((err) => console.error("ntfy push failed", err));
  }
  return full;
}
