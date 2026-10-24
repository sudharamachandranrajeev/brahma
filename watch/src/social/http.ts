// Outbound calls to platforms: one place that classifies failures, so the
// scheduler knows what is worth retrying and what means "reconnect".

// Fields are declared, not parameter properties, so Node can run the tests
// by stripping types.
export class PlatformError extends Error {
  readonly status: number;
  /** Worth retrying later: network trouble, 5xx, rate limits. */
  readonly transient: boolean;
  /** The token is expired or revoked: the account needs reconnecting. */
  readonly auth: boolean;
  /** The token works but lacks this permission (or the app lacks approval for it). */
  readonly permission: boolean;
  constructor(message: string, status: number, transient: boolean, auth: boolean, permission = false) {
    super(message);
    this.status = status;
    this.transient = transient;
    this.auth = auth;
    this.permission = permission;
  }
}

/** A user-facing input problem (bad request to our API). */
export class InputError extends Error {
  readonly problems: string[];
  readonly status: number;
  constructor(message: string, problems: string[] = [], status = 400) {
    super(message);
    this.problems = problems;
    this.status = status;
  }
}

/**
 * Cloudflare caps subrequests per invocation (50 on the free plan). Work that
 * fans out (polling, discovery) takes from a budget and stops cleanly when it
 * runs out; the next run carries on.
 */
export class Budget {
  left: number;
  constructor(left: number) {
    this.left = left;
  }
  take(n = 1): boolean {
    if (this.left < n) return false;
    this.left -= n;
    return true;
  }
}

export class OutOfBudget extends Error {
  constructor() {
    super("subrequest budget used up for this run");
  }
}

/** Takes one subrequest for a raw fetch (call() does this itself). */
export function spend(budget: Budget) {
  if (!budget.take()) throw new OutOfBudget();
}

export interface CallOptions extends RequestInit {
  budget?: Budget;
  /** Names the platform in error messages. */
  label?: string;
}

/** Pulls the platform's own error text out of common error shapes. */
function errorText(body: any): string {
  if (!body || typeof body !== "object") return String(body ?? "").slice(0, 300);
  const e = body.error;
  if (typeof e === "string") return body.error_description ?? body.message ?? e;
  if (e && typeof e === "object") return e.error_user_msg ?? e.message ?? JSON.stringify(e).slice(0, 300);
  return body.message ?? body.detail ?? JSON.stringify(body).slice(0, 300);
}

function isAuthFailure(status: number, body: any): boolean {
  // Graph API code 190 = invalid or expired token.
  return status === 401 || body?.error?.code === 190;
}

function isPermissionFailure(status: number, body: any): boolean {
  // Graph API: 10 and 200-299 = permission missing.
  const code = body?.error?.code;
  if (typeof code === "number" && (code === 10 || (code >= 200 && code < 300))) return true;
  return status === 403 && /scope|permission|not allowed|forbidden|quota/i.test(errorText(body));
}

/** fetch + JSON with classified errors. Returns null for 204. */
export async function call<T = any>(url: string | URL, opts: CallOptions = {}): Promise<T> {
  const { budget, label = new URL(url).hostname, ...init } = opts;
  if (budget && !budget.take()) throw new OutOfBudget();
  let res: Response;
  try {
    res = await fetch(url, init);
  } catch (err) {
    throw new PlatformError(`${label}: ${err instanceof Error ? err.message : err}`, 0, true, false);
  }
  const text = await res.text();
  let body: any = null;
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
  }
  if (!res.ok || (body && typeof body === "object" && body.error && !Array.isArray(body))) {
    const status = res.ok ? 400 : res.status;
    const graphTransient = [1, 2, 4, 17, 32, 341, 613].includes(body?.error?.code) || body?.error?.is_transient === true;
    throw new PlatformError(
      `${label}: ${errorText(body)}`,
      status,
      status === 429 || status >= 500 || graphTransient,
      isAuthFailure(status, body),
      isPermissionFailure(status, body),
    );
  }
  return body as T;
}

export const form = (data: Record<string, string | number | boolean | undefined | null>) => {
  const f = new URLSearchParams();
  for (const [k, v] of Object.entries(data)) if (v !== undefined && v !== null) f.set(k, String(v));
  return f;
};

export const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));
