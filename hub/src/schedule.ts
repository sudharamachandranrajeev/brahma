// Queue slots in the owner's time zone ("Mondays 09:30 Europe/London").

import type { QueueSlot } from "./types.ts";

/** Offset of [zone] from UTC at [at], in minutes. */
function offsetMinutes(zone: string, at: Date): number {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-GB", {
      timeZone: zone,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    })
      .formatToParts(at)
      .map((p) => [p.type, p.value]),
  );
  const asUtc = Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour, +parts.minute);
  return Math.round((asUtc - Math.floor(at.getTime() / 60000) * 60000) / 60000);
}

/** UTC instant of a wall-clock time in [zone] (DST-safe: re-checks the offset at the result). */
export function zonedToUtc(zone: string, y: number, m: number, d: number, hh: number, mm: number): Date {
  const guess = Date.UTC(y, m - 1, d, hh, mm);
  let t = guess - offsetMinutes(zone, new Date(guess)) * 60000;
  t = guess - offsetMinutes(zone, new Date(t)) * 60000;
  return new Date(t);
}

/** Local calendar date of [at] in [zone], with weekday 0 = Monday. */
function localDate(zone: string, at: Date) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-GB", { timeZone: zone, year: "numeric", month: "2-digit", day: "2-digit", weekday: "short" })
      .formatToParts(at)
      .map((p) => [p.type, p.value]),
  );
  const weekday = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].indexOf(parts.weekday);
  return { y: +parts.year, m: +parts.month, d: +parts.day, weekday };
}

/**
 * The first queue slot after [after] that no post takes yet (within 5 minutes
 * of another post counts as taken). Looks up to 8 weeks ahead.
 */
export function nextSlot(zone: string, slots: QueueSlot[], taken: string[], after: Date): Date | null {
  if (!slots.length) return null;
  const takenMs = taken.map((t) => new Date(t).getTime());
  const start = localDate(zone, after);
  for (let day = 0; day < 56; day++) {
    const base = new Date(Date.UTC(start.y, start.m - 1, start.d + day, 12));
    const weekday = (start.weekday + day) % 7;
    const times = slots
      .filter((s) => s.day === weekday)
      .map((s) => s.time)
      .sort();
    for (const time of times) {
      const [hh, mm] = time.split(":").map(Number);
      const at = zonedToUtc(zone, base.getUTCFullYear(), base.getUTCMonth() + 1, base.getUTCDate(), hh, mm);
      if (at.getTime() <= after.getTime()) continue;
      if (takenMs.some((t) => Math.abs(t - at.getTime()) < 5 * 60000)) continue;
      return at;
    }
  }
  return null;
}

export function validZone(zone: string): boolean {
  try {
    new Intl.DateTimeFormat("en-GB", { timeZone: zone });
    return true;
  } catch {
    return false;
  }
}
