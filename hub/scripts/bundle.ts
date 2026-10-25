// Builds the Worker into what Vani ships so it can deploy a hub itself, with
// no Node or wrangler on the user's computer:
//   npm run bundle            (into ../assets/hub)
// writes worker.js (one minified ES module) and manifest.json (the version,
// the settings from wrangler.toml and the D1 migrations, in order).
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { hubVersion } from "../src/version.ts";

const here = new URL("..", import.meta.url).pathname;
const at = process.argv.indexOf("--out");
const out = resolve(at > 0 ? process.argv[at + 1] : join(here, "..", "assets", "hub"));

const toml = readFileSync(join(here, "wrangler.toml"), "utf8");
const setting = (re: RegExp, what: string) => {
  const m = toml.match(re);
  if (!m) throw new Error(`wrangler.toml has no ${what}`);
  return m[1];
};

const build = mkdtempSync(join(tmpdir(), "brahma-watch-"));
try {
  execFileSync("npx", ["wrangler", "deploy", "--dry-run", "--minify", "--outdir", build], { cwd: here, stdio: ["ignore", "ignore", "inherit"] });
  mkdirSync(out, { recursive: true });
  writeFileSync(join(out, "worker.js"), readFileSync(join(build, "index.js")));
} finally {
  rmSync(build, { recursive: true, force: true });
}

const migrations = readdirSync(join(here, "migrations"))
  .filter((f) => f.endsWith(".sql"))
  .sort()
  .map((name) => ({ name, sql: readFileSync(join(here, "migrations", name), "utf8") }));

const manifest = {
  version: hubVersion,
  name: setting(/^name\s*=\s*"([^"]+)"/m, "name"),
  compatibilityDate: setting(/^compatibility_date\s*=\s*"([^"]+)"/m, "compatibility_date"),
  crons: JSON.parse(setting(/^crons\s*=\s*(\[[^\]]*\])/m, "crons")) as string[],
  vars: { SUBREQUEST_BUDGET: setting(/^SUBREQUEST_BUDGET\s*=\s*"([^"]+)"/m, "SUBREQUEST_BUDGET") },
  kvBinding: "KV",
  d1: { binding: "DB", name: setting(/^database_name\s*=\s*"([^"]+)"/m, "database_name") },
  r2: { binding: "MEDIA", name: setting(/^bucket_name\s*=\s*"([^"]+)"/m, "bucket_name") },
  migrations,
};
writeFileSync(join(out, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
console.log(`Hub ${hubVersion} bundled into ${out}`);
