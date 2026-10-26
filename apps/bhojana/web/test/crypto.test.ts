// Cross-implementation vectors: everything in dart-vectors.json was made by
// brahma_core's Dart code (see fixtures-gen/generate_test.dart).
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import {
  fromHex,
  fromPassword,
  hex,
  newRecoveryKey,
  open,
  recoveryKek,
  seal,
  toBase64,
  unwrapKey,
  wrapKey,
} from "../src/lib/crypto.ts";
import { HlcClock } from "../src/lib/hlc.ts";
import { newKeyPair, openGrant, openRequest, pairingCode, pairingLinkText, parseLink, type PairingLink } from "../src/lib/pairing.ts";

const dart = JSON.parse(readFileSync(new URL("fixtures/dart-vectors.json", import.meta.url), "utf8"));

test("Argon2id + HKDF give the same login secret and KEK as Dart", async () => {
  const keys = await fromPassword(dart.password.email, dart.password.password);
  assert.equal(keys.authSecret, dart.password.authSecret);
  assert.equal(hex(keys.kek), dart.password.kek);
});

test("short passwords are refused, as in Dart", async () => {
  await assert.rejects(fromPassword("me@example.com", "short"), /at least 12/);
});

test("Dart-wrapped keys unwrap, and wrong purposes or keys fail", () => {
  const kek = fromHex(dart.password.kek);
  assert.equal(hex(unwrapKey(dart.wrap.wrappedPassword, kek, "password")), dart.wrap.dek);
  assert.throws(() => unwrapKey(dart.wrap.wrappedPassword, kek, "recovery"), /Wrong password/);
  const rk = recoveryKek(dart.wrap.recoveryKey);
  assert.equal(hex(rk), dart.wrap.recoveryKek);
  assert.equal(hex(recoveryKek(dart.wrap.recoveryLoose)), dart.wrap.recoveryKek);
  assert.equal(hex(unwrapKey(dart.wrap.wrappedRecovery, rk, "recovery")), dart.wrap.dek);
  assert.throws(() => unwrapKey(dart.wrap.wrappedRecovery, fromHex(dart.password.kek), "recovery"));
});

test("recovery keys are 13 groups of Crockford base32 and parse back", () => {
  const k = newRecoveryKey();
  assert.match(k, /^([0-9A-HJKMNP-TV-Z]{4}-){12}[0-9A-HJKMNP-TV-Z]{4}$/);
  assert.equal(recoveryKek(k).length, 32);
  assert.throws(() => recoveryKek("not a key"), /not valid/);
  assert.throws(() => recoveryKek(k.slice(0, -5)), /not valid/);
});

test("a Dart-sealed change batch opens; a moved one does not", async () => {
  const dek = fromHex(dart.wrap.dek);
  assert.deepEqual(await open(dart.batch.sealed, dek, dart.batch.aad), dart.batch.json);
  await assert.rejects(open(dart.batch.sealed, dek, dart.batch.aad.replace(/1$/, "2")), /integrity/);
  const again = await seal(dart.batch.json, dek, dart.batch.aad);
  assert.deepEqual(await open(again, dek, dart.batch.aad), dart.batch.json);
});

test("Dart pairing links, requests, codes and grants are read here", () => {
  const link = parseLink(dart.pairing.link) as PairingLink;
  assert.equal(link.kind, "pair");
  assert.equal(link.server, "https://sync.example.com");
  assert.equal(link.scheme, "bhojana");
  assert.equal(pairingLinkText(link), dart.pairing.link);

  const joiner = newKeyPair(fromHex(dart.pairing.joinerSeed));
  assert.equal(toBase64(joiner.publicKey), dart.pairing.joinerPublic);
  const request = openRequest(link, dart.pairing.request);
  assert.equal(request.name, "Phone");
  assert.equal(request.platform, "android");
  assert.equal(toBase64(request.publicKey), dart.pairing.joinerPublic);
  assert.equal(pairingCode(link, joiner.publicKey), dart.pairing.code);

  const grant = openGrant(link, joiner, dart.pairing.grant);
  assert.equal(grant.email, "me@example.com");
  assert.equal(grant.secret, dart.password.authSecret);
  assert.equal(hex(grant.dataKey), dart.wrap.dek);

  // Someone who only saw the QR code lacks the joiner's private key.
  assert.throws(() => openGrant(link, newKeyPair(), dart.pairing.grant), /could not be opened/);
  const other = { ...link, id: "otherotherother" };
  assert.throws(() => openRequest(other, dart.pairing.request), /did not come from/);
});

test("links: setup links, spaces from chat apps, and refusals", () => {
  const setup = parseLink("bhojana://setup?s=https%3A%2F%2Fsync.example.com&i=ABCD-EFGH");
  assert.deepEqual(setup, { kind: "setup", server: "https://sync.example.com", invite: "ABCD-EFGH" });
  assert.equal((parseLink(` ${dart.pairing.link.slice(0, 20)}\n${dart.pairing.link.slice(20)} `) as PairingLink).id, "pairpairpair123");
  assert.throws(() => parseLink("https://example.com"), /not a sync link/);
  assert.throws(() => parseLink("bhojana://pair?s=http%3A%2F%2Fsync.example.com&p=pairpairpair123&k=AA"), /incomplete|https/);
  assert.throws(() => parseLink("bhojana://setup?s=http%3A%2F%2Fsync.example.com&i=X"), /https/);
  assert.equal((parseLink("bhojana://setup?s=http%3A%2F%2F192.168.1.5%3A8787&i=X") as { server: string }).server, "http://192.168.1.5:8787");
});

test("HLC stamps match Dart's clock step for step", () => {
  let t = 1760000000000;
  const c = new HlcClock("n0de", () => t);
  const a = c.tick(), b = c.tick();
  c.receive("001760000000005-000007-other");
  const d = c.tick();
  t = 1760000000009;
  assert.deepEqual([a, b, d, c.tick()], dart.hlc.ticks);
});

test("TS-wrapped keys round-trip (Dart opens them in test/web_interop_test.dart)", () => {
  const kek = fromHex(dart.password.kek);
  const dek = fromHex(dart.wrap.dek);
  assert.equal(hex(unwrapKey(wrapKey(dek, kek, "password"), kek, "password")), dart.wrap.dek);
});
