// Writes web/test/fixtures/ts-vectors.json: values made by the web client,
// which test/web_interop_test.dart opens with the real brahma_core code.
// Run when the wire format changes:  node test/fixtures-gen/make-ts-vectors.ts
import { writeFileSync } from "node:fs";
import { fromPassword, hex, newDataKey, newRecoveryKey, randomBytes, recoveryKek, seal, toBase64, wrapKey } from "../../src/lib/crypto.ts";
import { newKeyPair, pairingCode, pairingLinkText, sealGrant, sealRequest, type PairingLink } from "../../src/lib/pairing.ts";

const email = "Someone@Example.com";
const password = "another long password 42";
const keys = await fromPassword(email, password);
const dek = newDataKey();
const recovery = newRecoveryKey();

const owner = "zyxwvutsrqponml";
const device = "c".repeat(32);
const aad = `artha/v1|${owner}|${device}|3`;
const batch = {
  v: 1,
  rows: [
    { t: "food_lists", r: { id: "list-1", hlc: `001770000000000-000000-${device}`, deleted: 0, name: "Weekly shop", created: "2026-10-26" } },
    {
      t: "food_items",
      r: {
        id: "item-1", hlc: `001770000000000-000001-${device}`, deleted: 0, list_id: "list-1", name: "Free-range eggs ✓",
        qty: 12, note: "large", done: 1, ord: 3, added: "2026-10-26",
      },
    },
    { t: "prefs", r: { id: "bhojana.postcode", hlc: `001770000000000-000002-${device}`, deleted: 0, value: "SW1A 1AA" } },
  ],
};

const link: PairingLink = { kind: "pair", server: "https://sync.example.com", id: "tswebpairing123", secret: randomBytes(32), scheme: "bhojana" };
const joinerSeed = randomBytes(32);
const joiner = newKeyPair(joinerSeed);
const recipientSeed = randomBytes(32);
const recipient = newKeyPair(recipientSeed);

const out = {
  note: "Made by web/test/fixtures-gen/make-ts-vectors.ts. Test values only.",
  password: { email, password, authSecret: keys.authSecret, kek: hex(keys.kek) },
  wrap: {
    dek: hex(dek),
    wrappedPassword: wrapKey(dek, keys.kek, "password"),
    recoveryKey: recovery,
    wrappedRecovery: wrapKey(dek, recoveryKek(recovery), "recovery"),
  },
  batch: { aad, json: batch, sealed: await seal(batch, dek, aad) },
  pairing: {
    link: pairingLinkText(link),
    joinerPublic: toBase64(joiner.publicKey),
    code: pairingCode(link, joiner.publicKey),
    request: sealRequest(link, { name: "Firefox on Linux", platform: "web", publicKey: joiner.publicKey }),
    recipientSeed: hex(recipientSeed),
    recipientPublic: toBase64(recipient.publicKey),
    grant: sealGrant(link, recipient.publicKey, { email: "someone@example.com", userId: owner, secret: keys.authSecret, dataKey: dek }),
  },
};
writeFileSync(new URL("../fixtures/ts-vectors.json", import.meta.url), `${JSON.stringify(out, null, 2)}\n`);
console.log("wrote test/fixtures/ts-vectors.json");
