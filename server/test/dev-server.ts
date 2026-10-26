// Runs the handler on a local port with an in-memory database. The Dart
// sync tests start it: `node test/dev-server.ts <port>`.
import { createServer } from "node:http";
import { handle } from "../src/app.ts";
import { memoryD1 } from "../src/sqlite.ts";

export const SETUP_CODE = "TEST-SETUP-CODE";
const env = { DB: memoryD1(), TOKEN_KEY: "dev-token-key", SETUP_CODE };

export function serve(port: number) {
  return createServer(async (req, res) => {
    const chunks: Buffer[] = [];
    for await (const c of req) chunks.push(c as Buffer);
    const body = chunks.length ? Buffer.concat(chunks) : undefined;
    const out = await handle(
      new Request(`http://localhost:${port}${req.url}`, {
        method: req.method,
        headers: req.headers as Record<string, string>,
        body: req.method === "GET" || req.method === "HEAD" ? undefined : body,
      }),
      env,
    );
    res.writeHead(out.status, Object.fromEntries(out.headers));
    res.end(Buffer.from(await out.arrayBuffer()));
  }).listen(port);
}

if (process.argv[2]) {
  serve(Number(process.argv[2]));
  console.log("ready");
}
