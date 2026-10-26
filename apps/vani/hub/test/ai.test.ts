// AI services other than Claude, device answers, and model lists.
import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.ts";
import { mockFetch, testEnv } from "./shims.ts";

const env = () => ({ ...testEnv(), SUBREQUEST_BUDGET: "45" });
const exec = { waitUntil: () => {}, passThroughOnException: () => {} } as unknown as ExecutionContext;
const call = (e: ReturnType<typeof env>, path: string, init: RequestInit & { headers?: Record<string, string> } = {}) =>
  worker.fetch(
    new Request(`https://hub.test${path}`, {
      ...init,
      headers: { authorization: "Bearer test-token", "content-type": "application/json", ...init.headers },
    }),
    e as never,
    exec,
  );

const put = (e: ReturnType<typeof env>, path: string, body: unknown) => call(e, path, { method: "PUT", body: JSON.stringify(body) });
const translate = (e: ReturnType<typeof env>, headers: Record<string, string> = {}) =>
  call(e, "/social/ai/translate", { method: "POST", body: JSON.stringify({ text: "Hola", to: "English" }), headers });

const answers = (list: unknown[]) => Buffer.from(JSON.stringify(list)).toString("base64url");

test("without any key AI answers 412", async () => {
  const e = env();
  assert.equal((await translate(e)).status, 412);
  const meta = await (await call(e, "/social/meta")).json() as any;
  assert.equal(meta.ai, false);
  assert.deepEqual(meta.aiProviders, ["anthropic", "openai", "gemini", "openrouter", "compatible"]);
});

test("OpenAI answers through the Responses API with a strict schema", async () => {
  const e = env();
  assert.equal((await put(e, "/social/credentials/openai", { secret: "sk-o" })).status, 200);
  assert.equal((await translate(e)).status, 412, "no model picked yet");
  await put(e, "/social/settings", { timezone: "Europe/London", queue: [], savedReplies: [], aiModels: { openai: "gpt-test" } });
  let sent: any;
  const net = mockFetch({
    "https://api.openai.com/v1/responses": (_u, init) => {
      sent = { auth: (init.headers as Record<string, string>).authorization, body: JSON.parse(String(init.body)) };
      return { status: "completed", output: [{ type: "message", content: [{ type: "output_text", text: '{"lang":"ES","text":"Hello"}' }] }] };
    },
  });
  try {
    const res = await translate(e);
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { lang: "es", text: "Hello" });
    assert.equal(sent.auth, "Bearer sk-o");
    assert.equal(sent.body.model, "gpt-test");
    assert.equal(sent.body.text.format.strict, true);
    assert.equal(sent.body.store, false);
  } finally {
    net.restore();
  }
});

test("Gemini answers through generateContent with a JSON schema", async () => {
  const e = env();
  await put(e, "/social/credentials/gemini", { secret: "g-key" });
  await put(e, "/social/settings", { timezone: "Europe/London", queue: [], savedReplies: [], aiProvider: "gemini", aiModels: { gemini: "gemini-test" } });
  let key = "";
  const net = mockFetch({
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent": (_u, init) => {
      key = (init.headers as Record<string, string>)["x-goog-api-key"];
      assert.ok(JSON.parse(String(init.body)).generationConfig.responseJsonSchema);
      return { candidates: [{ finishReason: "STOP", content: { parts: [{ text: '```json\n{"lang":"es","text":"Hello"}\n```' }] } }] };
    },
  });
  try {
    const res = await translate(e);
    assert.equal(res.status, 200);
    assert.equal(((await res.json()) as any).text, "Hello");
    assert.equal(key, "g-key");
  } finally {
    net.restore();
  }
});

test("an OpenAI-compatible service must be public https, then speaks Chat Completions", async () => {
  const e = env();
  for (const bad of ["http://api.example.com/v1", "https://localhost:11434/v1", "https://192.168.1.5/v1"]) {
    assert.equal((await put(e, "/social/credentials/compatible", { publicId: bad, secret: "k" })).status, 400, bad);
  }
  assert.equal((await put(e, "/social/credentials/compatible", { publicId: "https://llm.example.com/v1/", secret: "k" })).status, 200);
  await put(e, "/social/settings", { timezone: "Europe/London", queue: [], savedReplies: [], aiProvider: "compatible", aiModels: { compatible: "llama-x" } });
  const net = mockFetch({
    "https://llm.example.com/v1/chat/completions": () => ({ choices: [{ finish_reason: "stop", message: { content: '{"lang":"es","text":"Hello"}' } }] }),
    "https://llm.example.com/v1/models": () => ({ data: [{ id: "llama-x" }, { id: "bad id!" }, { id: "a-model" }] }),
  });
  try {
    assert.equal((await translate(e)).status, 200);
    const models = await (await call(e, "/social/ai/models?provider=compatible")).json();
    assert.deepEqual(models, { models: ["a-model", "llama-x"] });
  } finally {
    net.restore();
  }
});

test("a rejected key is worded for the owner", async () => {
  const e = env();
  await put(e, "/social/credentials/openrouter", { secret: "bad" });
  await put(e, "/social/settings", { timezone: "Europe/London", queue: [], savedReplies: [], aiModels: { openrouter: "x/y" } });
  const net = mockFetch({
    "https://openrouter.ai/api/v1/chat/completions": () => Response.json({ error: { message: "No auth credentials found" } }, { status: 401 }),
  });
  try {
    const res = await translate(e);
    assert.equal(res.status, 412);
    assert.match(((await res.json()) as any).error, /OpenRouter key was rejected/);
  } finally {
    net.restore();
  }
});

test("device AI: the hub hands over the prompt, then uses the device's answer", async () => {
  const e = env();
  const net = mockFetch({});
  try {
    // No key on the hub at all: the device answers instead.
    const first = await translate(e, { "x-vani-ai": "device" });
    assert.equal(first.status, 409);
    const { needsAi } = (await first.json()) as any;
    assert.match(needsAi.system, /Translate the text into English/);
    assert.match(needsAi.prompt, /Hola/);
    assert.deepEqual(needsAi.images, []);
    assert.equal(needsAi.schema.type, "object");

    const done = await translate(e, { "x-vani-ai": "device", "x-vani-ai-answers": answers([{ lang: "ES", text: "Hello" }]) });
    assert.equal(done.status, 200);
    assert.deepEqual(await done.json(), { lang: "es", text: "Hello" });

    const wrong = await translate(e, { "x-vani-ai": "device", "x-vani-ai-answers": answers([{ nope: 1 }]) });
    assert.equal(wrong.status, 422);
    assert.equal(net.sent.length, 0, "nothing left the hub");
  } finally {
    net.restore();
  }
});

test("settings from before 0.3 keep their Claude model", async () => {
  const e = env();
  await e.DB.prepare("INSERT INTO docs (key, value) VALUES ('settings', ?)")
    .bind(JSON.stringify({ timezone: "Europe/London", queue: [], savedReplies: [], model: "claude-sonnet-5-5", language: "English" }))
    .run();
  const s = (await (await call(e, "/social/settings")).json()) as any;
  assert.equal(s.aiProvider, null);
  assert.deepEqual(s.aiModels, { anthropic: "claude-sonnet-5-5" });
  assert.ok(!("model" in s));
});
