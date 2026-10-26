<script lang="ts">
  // The signed-in side of pairing: show the link as a QR code, wait for the
  // new device's request, let the user compare codes and approve.
  import { onMount } from "svelte";
  import { renderSVG } from "uqr";
  import { app, errorText } from "../app/state.svelte.ts";
  import { pairingCode, pairingLinkText, type JoinRequest, type PairingLink } from "../lib/pairing.ts";

  let { onclose }: { onclose: () => void } = $props();

  let link = $state.raw<PairingLink | null>(null);
  let request = $state.raw<JoinRequest | null>(null);
  let phase = $state<"starting" | "waiting" | "request" | "sending" | "finishing" | "done" | "failed">("starting");
  let error = $state("");
  let copied = $state(false);
  const text = $derived(link ? pairingLinkText(link) : "");
  // Built here from the link: nothing about it leaves the page.
  const qr = $derived(text ? renderSVG(text, { ecc: "M", border: 2 }) : "");

  let stopped = false;

  onMount(() => {
    void start();
    return () => {
      stopped = true;
      // Approved records stay: the new device still has to collect its keys.
      if (link && (phase === "waiting" || phase === "request")) void app.account.cancelPairing(link).catch(() => {});
    };
  });

  async function start() {
    try {
      link = await app.account.offerPairing();
      phase = "waiting";
      await poll(link);
    } catch (e) {
      fail(e);
    }
  }

  function fail(e: unknown) {
    error = errorText(e);
    phase = "failed";
  }

  async function poll(l: PairingLink) {
    const deadline = Date.now() + 10 * 60_000;
    while (!stopped && Date.now() < deadline) {
      await new Promise((r) => setTimeout(r, 2000));
      if (stopped) return;
      try {
        if (phase === "waiting") {
          const r = await app.account.pairingRequest(l);
          if (r) {
            request = r;
            phase = "request";
          }
        } else if (phase === "finishing") {
          if (await app.account.pairingFinished(l)) {
            phase = "done";
            void app.syncNow();
            return;
          }
        } else if (phase === "failed") {
          return;
        }
      } catch (e) {
        return fail(e);
      }
    }
    if (!stopped && phase !== "done") fail(new Error("This code has expired. Make a new one."));
  }

  async function approve() {
    phase = "sending";
    try {
      await app.account.approvePairing(link!, request!);
      phase = "finishing";
    } catch (e) {
      fail(e);
    }
  }

  async function decline() {
    if (link) await app.account.cancelPairing(link).catch(() => {});
    link = null;
    onclose();
  }

  async function copy() {
    try {
      await navigator.clipboard.writeText(text);
      copied = true;
    } catch {
      // Clipboard refused (no permission): the text can still be selected.
    }
  }
</script>

{#if phase === "starting"}
  <p role="status">Making a pairing code…</p>
{:else if phase === "waiting"}
  <p>On the new device choose <strong>Join from a device I already use</strong>, then scan this code or paste the link.</p>
  <div class="qr" role="img" aria-label="QR code of the pairing link">{@html qr}</div>
  <label for="pair-text">Pairing link</label>
  <textarea id="pair-text" readonly rows="3" value={text} spellcheck="false"></textarea>
  <div class="buttons start">
    <button type="button" class="tonal" onclick={copy}>{copied ? "Copied" : "Copy link"}</button>
  </div>
  <p class="muted small" role="status">Waiting for the new device… The code works once, for 10 minutes. Anyone with the link can ask to join, so send it only to yourself.</p>
{:else if phase === "request" && request && link}
  <div role="alert">
    <p><strong>{request.name || "A device"}</strong>{request.platform ? ` (${request.platform})` : ""} asks to join.</p>
    <p>Approve only if it shows this code:</p>
    <p class="code">{pairingCode(link, request.publicKey)}</p>
  </div>
  <div class="buttons">
    <button type="button" class="text" onclick={decline}>Decline</button>
    <button type="button" class="filled" onclick={approve}>Approve</button>
  </div>
{:else if phase === "sending" || phase === "finishing"}
  <p role="status">Sending the keys… waiting for the new device to sign in.</p>
{:else if phase === "done"}
  <p role="status">Done. {request?.name || "The new device"} now syncs with this account.</p>
{:else}
  <p class="error" role="alert">{error}</p>
{/if}
{#if phase !== "request"}
  <div class="buttons"><button type="button" class="filled" onclick={onclose}>{phase === "done" ? "Close" : "Cancel"}</button></div>
{/if}
