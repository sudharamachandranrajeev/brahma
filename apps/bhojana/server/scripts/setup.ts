// Deploys your own Bhojana sync server to Cloudflare (free plan is enough):
//   npx wrangler login     (once, opens the browser)
//   npm install && npm run setup
// Creates the database, builds the web app, deploys, stores the signing key as a secret, and
// prints the setup link that creates the owner account. Safe to run again:
// it redeploys and only makes a new setup code while no one has signed up.
import { execFileSync, spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";

const here = new URL("..", import.meta.url).pathname;
const wrangler = (args: string[], input?: string) =>
  execFileSync("npx", ["wrangler", ...args], { cwd: here, input, encoding: "utf8", stdio: [input ? "pipe" : "inherit", "pipe", "inherit"] });

if (spawnSync("npx", ["wrangler", "whoami"], { cwd: here, encoding: "utf8" }).stdout.includes("not authenticated")) {
  console.error("Run `npx wrangler login` first.");
  process.exit(1);
}

const tomlPath = `${here}wrangler.toml`;
let toml = readFileSync(tomlPath, "utf8");
if (toml.includes("REPLACE_WITH_D1_ID")) {
  const out = wrangler(["d1", "create", "bhojana"]);
  const id = out.match(/"?database_id"?\s*[=:]\s*"([0-9a-f-]{36})"/)?.[1];
  if (!id) throw new Error(`Could not read the database id from:\n${out}`);
  toml = toml.replace("REPLACE_WITH_D1_ID", id);
  writeFileSync(tomlPath, toml);
  console.log("Created the database.");
}
wrangler(["d1", "execute", "bhojana", "--remote", "--file", "schema.sql"]);

// The Worker also serves the web app, so it is built into ./public first;
// wrangler refuses to deploy while that folder is missing.
const npm = (args: string[]) => execFileSync("npm", ["--prefix", "../web", ...args], { cwd: here, stdio: "inherit" });
npm(["ci"]);
npm(["run", "build"]);
console.log("Built the web app.");

const deployed = wrangler(["deploy"]);
const url = deployed.match(/https:\/\/[\w.-]+\.workers\.dev/)?.[0];
if (!url) throw new Error(`Deployed, but no workers.dev URL in the output:\n${deployed}`);

const secrets = wrangler(["secret", "list"]);
if (!secrets.includes("TOKEN_KEY")) wrangler(["secret", "put", "TOKEN_KEY"], randomBytes(32).toString("base64url"));

const health = (await (await fetch(`${url}/api/health`)).json()) as { needsSetup?: boolean };
console.log(`\nYour Bhojana server: ${url}`);
if (health.needsSetup) {
  const code = (randomBytes(12).toString("base64url").match(/[A-Za-z0-9]/g) ?? []).join("").slice(0, 16);
  wrangler(["secret", "put", "SETUP_CODE"], code);
  const link = `bhojana://setup?s=${encodeURIComponent(url)}&i=${code}`;
  console.log(`\nOne-time setup code (shown only now): ${code}`);
  console.log(`Setup link for the app:  ${link}`);
  console.log("In Bhojana choose 'Set up sync', paste the link, and create your account.");
  console.log(`Or open ${url} in a browser and create it there with the code.`);
} else {
  console.log("Redeployed. Your account already exists; invite people from the app's Settings.");
}
