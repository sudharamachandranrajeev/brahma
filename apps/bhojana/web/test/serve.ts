// The Worker as Cloudflare runs it, on a local port: the real handler with an
// in-memory database for /api, and the built app from server/public as the
// ASSETS binding (SPA fallback and the _headers policy included), so the
// smoke test sees the same origin, routes and CSP as a deployment.
//   node test/serve.ts 8788      (after npm run build)
import { readFileSync } from "node:fs";
import { createServer, type Server } from "node:http";
import { extname, join, normalize } from "node:path";

// Loaded by URL so this project's typecheck stays out of the server's code,
// which needs the Workers types and is checked by its own tsconfig.
const fromServer = (path: string) => import(new URL(`../../server/${path}`, import.meta.url).href);
const { handle } = await fromServer("src/app.ts");
const { memoryD1 } = await fromServer("test/d1.ts");

const root = new URL("../../server/public/", import.meta.url).pathname;

const TYPES: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript",
  ".css": "text/css",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".webmanifest": "application/manifest+json",
};

/// Only the `/*` block of _headers is used by this app.
function headerRules(): Record<string, string> {
  const out: Record<string, string> = {};
  for (const line of readFileSync(join(root, "_headers"), "utf8").split("\n")) {
    const m = line.match(/^\s+([\w-]+):\s*(.+)$/);
    if (m) out[m[1]] = m[2];
  }
  return out;
}

function assets() {
  const headers = headerRules();
  const file = (path: string) => {
    const body = readFileSync(join(root, path));
    return new Response(body, { headers: { ...headers, "content-type": TYPES[extname(path)] ?? "application/octet-stream" } });
  };
  return {
    fetch: async (req: Request | string) => {
      const path = normalize(decodeURIComponent(new URL(typeof req === "string" ? req : req.url).pathname));
      if (path.includes("..") || path.startsWith("/_headers")) return new Response("Not found", { status: 404 });
      try {
        return file(path === "/" ? "index.html" : path.slice(1));
      } catch {
        // not_found_handling = "single-page-application"
        return file("index.html");
      }
    },
  };
}

export function serve(port: number): Promise<Server> {
  const env = { DB: memoryD1(), TOKEN_KEY: "dev-token-key", SETUP_CODE: "TEST-SETUP-CODE", ASSETS: assets() };
  const server = createServer(async (req, res) => {
    const chunks: Buffer[] = [];
    for await (const c of req) chunks.push(c as Buffer);
    const out = await handle(
      new Request(`http://localhost:${port}${req.url}`, {
        method: req.method,
        headers: req.headers as Record<string, string>,
        body: req.method === "GET" || req.method === "HEAD" || !chunks.length ? undefined : Buffer.concat(chunks),
      }),
      env,
    );
    res.writeHead(out.status, Object.fromEntries(out.headers));
    res.end(Buffer.from(await out.arrayBuffer()));
  });
  return new Promise((done) => server.listen(port, "127.0.0.1", () => done(server)));
}

if (import.meta.main && process.argv[2]) {
  await serve(Number(process.argv[2]));
  console.log(`http://localhost:${process.argv[2]}/  (setup code TEST-SETUP-CODE)`);
}
