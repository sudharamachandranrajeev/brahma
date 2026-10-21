// One-time (and re-runnable) deploy of Brahma Watch to Cloudflare:
//   npx wrangler login     (once, opens the browser)
//   npm run setup
// Creates the KV namespace, generates the ntfy topic and API token (kept in
// ~/.config/brahma/watch.env, mode 600), deploys, stores the secrets, loads
// the searches in ~/.config/brahma/watches.json if there are any (kept out of
// the repository: they say where you live), runs once and sends a test push.
import { execFileSync, spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { chmodSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const here = new URL("..", import.meta.url).pathname;
const wrangler = (args: string[], input?: string) =>
  execFileSync("npx", ["wrangler", ...args], { cwd: here, input, encoding: "utf8", stdio: [input ? "pipe" : "inherit", "pipe", "inherit"] });

if (spawnSync("npx", ["wrangler", "whoami"], { cwd: here, encoding: "utf8" }).stdout.includes("not authenticated")) {
  console.error("Run `npx wrangler login` first.");
  process.exit(1);
}

// KV namespace
const tomlPath = join(here, "wrangler.toml");
let toml = readFileSync(tomlPath, "utf8");
if (toml.includes("REPLACE_WITH_KV_ID")) {
  const out = wrangler(["kv", "namespace", "create", "KV"]);
  const id = out.match(/"?id"?\s*[=:]\s*"([0-9a-f]{32})"/)?.[1];
  if (!id) throw new Error(`Could not read the namespace id from:\n${out}`);
  toml = toml.replace("REPLACE_WITH_KV_ID", id);
  writeFileSync(tomlPath, toml);
  console.log(`KV namespace ${id}`);
}

// Secrets, generated once and kept locally for Anveshana.
const dir = join(homedir(), ".config", "brahma");
const envPath = join(dir, "watch.env");
const env: Record<string, string> = {};
if (existsSync(envPath)) {
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const m = line.match(/^(\w+)=(.*)$/);
    if (m) env[m[1]] = m[2];
  }
}
env.NTFY_TOPIC ??= `brahma-${randomBytes(12).toString("hex")}`;
env.API_TOKEN ??= randomBytes(32).toString("hex");

const deployed = wrangler(["deploy"]);
const url = deployed.match(/https:\/\/[\w.-]+\.workers\.dev/)?.[0];
if (!url) throw new Error(`Deployed, but no workers.dev URL in the output:\n${deployed}`);
env.WATCH_URL = url;

mkdirSync(dir, { recursive: true, mode: 0o700 });
writeFileSync(envPath, Object.entries(env).map(([k, v]) => `${k}=${v}`).join("\n") + "\n", { mode: 0o600 });
chmodSync(envPath, 0o600);

for (const name of ["NTFY_TOPIC", "API_TOKEN"]) wrangler(["secret", "put", name], env[name]);

const call = async (path: string, method = "POST", body?: string) => {
  const res = await fetch(url + path, {
    method,
    body,
    headers: { authorization: `Bearer ${env.API_TOKEN}`, "content-type": "application/json" },
  });
  return `${res.status} ${await res.text()}`;
};
// Secrets can take a few seconds to reach every edge.
await new Promise((r) => setTimeout(r, 5000));
const watchesPath = join(dir, "watches.json");
if (existsSync(watchesPath)) {
  console.log("Searches from", watchesPath, await call("/watches", "PUT", readFileSync(watchesPath, "utf8")));
}
console.log("First run (records what is listed now, no alerts):", await call("/run"));
console.log("Test push:", await call("/test-notify"));

const subscribe = `https://ntfy.sh/${env.NTFY_TOPIC}`;
console.log(`
Brahma Watch is live at ${url}
Settings saved in ${envPath}

On your phone: install "ntfy" (Play Store or F-Droid), tap +, and subscribe to
topic ${env.NTFY_TOPIC}  (or open ${subscribe})
Keep the topic private: anyone who knows it can read the alerts.`);
spawnSync("qrencode", ["-t", "ansiutf8", subscribe], { stdio: "inherit" });
