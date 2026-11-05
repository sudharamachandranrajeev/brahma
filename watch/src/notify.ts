import { portals } from "./email.ts";
import type { WatchEvent } from "./watch.ts";

/** Push message for the ntfy app (https://docs.ntfy.sh/publish/#publish-as-json). */
export function ntfyMessage(topic: string, e: WatchEvent, watchName: string) {
  const l = e.listing;
  // Alert-email adverts: say which portal, and never attach its photo (ntfy
  // would fetch it from the portal).
  const portal = portals.find((p) => p.source === l.source);
  const on = portal ? ` on ${portal.label}` : "";
  const money = (p: number | null | undefined) => (p == null ? "price not shown" : `£${p.toLocaleString("en-GB")}`);
  const price = l.price == null ? "Price not shown" : `${money(l.price)} ${l.priceSuffix}`.trim();
  const title =
    e.kind === "new"
      ? `New${on}: ${l.address || "address not given"}`
      : e.kind === "price"
        ? `Price ${money(e.previousPrice)} → ${money(l.price)}: ${l.address}`
        : `${l.status === "letAgreed" ? "Let agreed" : l.status}: ${l.address}`;
  const facts = [
    price,
    l.beds != null ? `${l.beds} bed` : null,
    l.style,
    l.furnished,
    e.distanceKm != null ? `${e.distanceKm.toFixed(1)} km` : null,
    l.availableFrom ? `from ${l.availableFrom}` : null,
  ].filter(Boolean);
  const actions: object[] = [{ action: "view", label: portal ? `Open on ${portal.label}` : "Open listing", url: l.url }];
  if (l.agentPhone) actions.push({ action: "view", label: `Call ${l.agent}`, url: `tel:${l.agentPhone}` });
  return {
    topic,
    title,
    message: `${facts.join(" · ")}\n${[l.agent, watchName].filter(Boolean).join(" · ")}`,
    click: l.url,
    tags: [e.kind === "new" ? "house" : e.kind === "price" ? "pound" : "bell"],
    priority: e.kind === "new" ? 4 : 3,
    actions,
    ...(l.image && !portal ? { attach: l.image } : {}),
  };
}

export async function sendNtfy(server: string, token: string | undefined, body: object): Promise<void> {
  const res = await fetch(server, {
    method: "POST",
    headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`ntfy answered ${res.status}: ${await res.text()}`);
}
