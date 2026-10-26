// Signs sentinel/rules.json for Sentinel (core's sentinel/rules.dart).
// Stamps "issued" with now, writes the file back and its Ed25519 signature
// to sentinel/rules.json.sig. The private key stays off the repository:
//
//   node scripts/sign-rules.ts [key.pem]   (default ~/.config/brahma/rules-signing.pem)
//
// Make a key once with: openssl genpkey -algorithm ed25519 -out rules-signing.pem
// and put its public half (printed below) in rules.dart's rulesPublicKey.

import { createPrivateKey, createPublicKey, sign } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const root = join(import.meta.dirname, "..");
const keyFile = process.argv[2] ?? join(homedir(), ".config/brahma/rules-signing.pem");
const key = createPrivateKey(readFileSync(keyFile));
const file = join(root, "sentinel/rules.json");

const rules = JSON.parse(readFileSync(file, "utf8"));
if (!Array.isArray(rules.advisories)) throw new Error("rules.json needs an advisories list");
rules.issued = new Date().toISOString();
const text = JSON.stringify(rules, null, 2) + "\n";
writeFileSync(file, text);
writeFileSync(`${file}.sig`, sign(null, Buffer.from(text), key).toString("base64") + "\n");

const pub = createPublicKey(key).export({ format: "der", type: "spki" }).subarray(-32).toString("base64");
console.log(`Signed ${rules.advisories.length} advisories, issued ${rules.issued}. Public key: ${pub}`);
