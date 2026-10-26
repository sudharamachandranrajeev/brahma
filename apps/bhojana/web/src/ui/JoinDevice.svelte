<script lang="ts">
  // The new device's side of pairing: read the link the signed-in device
  // shows, show the matching code, wait for approval, then sign in with the
  // keys it sends.
  import { onDestroy } from "svelte";
  import { app, errorText } from "../app/state.svelte.ts";
  import type { JoinTicket } from "../lib/account.ts";
  import { parseLink } from "../lib/pairing.ts";
  import Scanner, { canScan } from "./Scanner.svelte";

  let { onjoined, onback }: { onjoined: () => void; onback: () => void } = $props();

  let text = $state("");
  let remember = $state(true);
  let scanning = $state(false);
  let error = $state("");
  let busy = $state(false);
  let ticket = $state.raw<JoinTicket | null>(null);
  let joining = $state("");
  let stopped = false;
  onDestroy(() => (stopped = true));

  async function submit(e?: SubmitEvent) {
    e?.preventDefault();
    error = "";
    busy = true;
    try {
      const link = parseLink(text);
      if (link.kind === "setup") throw new Error("That is a setup link: use it to create an account instead.");
      app.useMemoryKeys(remember);
      ticket = await app.account.requestJoin(link);
      void wait(ticket);
    } catch (err) {
      error = errorText(err);
    } finally {
      busy = false;
    }
  }

  async function wait(t: JoinTicket) {
    const deadline = Date.now() + 10 * 60_000;
    while (!stopped && Date.now() < deadline) {
      await new Promise((r) => setTimeout(r, 2000));
      if (stopped || ticket !== t) return;
      try {
        const grant = await app.account.joinGrant(t);
        if (!grant) continue;
        joining = grant.email;
        await app.account.join(t, grant);
        onjoined();
        return;
      } catch (err) {
        error = errorText(err);
        ticket = null;
        return;
      }
    }
    if (!stopped && ticket === t) {
      error = "The code expired. Make a new one on your other device.";
      ticket = null;
    }
  }
</script>

<h1 tabindex="-1">Join from a device you already use</h1>
{#if !ticket}
  <ol class="steps">
    <li>On the device that already syncs, open Settings, Sync, <strong>Add a device</strong>.</li>
    <li>Copy the link under its QR code and paste it here{canScan() ? ", or scan the code" : ""}.</li>
  </ol>
  {#if scanning}
    <Scanner
      onfound={(v) => {
        scanning = false;
        text = v;
        void submit();
      }}
      onclose={() => (scanning = false)}
    />
  {/if}
  <form onsubmit={submit}>
    <label for="pair-link">Pairing link</label>
    <textarea id="pair-link" bind:value={text} rows="3" placeholder="bhojana://pair?…" spellcheck="false" aria-describedby="pair-error"
    ></textarea>
    <label class="check"><input type="checkbox" bind:checked={remember} /> Keep me signed in on this browser</label>
    <p id="pair-error" class="error" role="alert">{error}</p>
    <div class="buttons">
      <button type="button" class="text" onclick={onback}>Back</button>
      {#if canScan() && !scanning}<button type="button" class="tonal" onclick={() => (scanning = true)}>Scan the code</button>{/if}
      <button type="submit" class="filled" disabled={busy || !text.trim()}>{busy ? "Asking…" : "Ask to join"}</button>
    </div>
  </form>
{:else}
  <div class="pair-code" role="status">
    {#if joining}
      <p>Approved. Signing in as {joining}…</p>
    {:else}
      <p>Check that your other device shows this code, then approve there:</p>
      <p class="code" aria-label="Code {ticket.code.split('').join(' ')}">{ticket.code}</p>
      <p class="muted">Waiting for approval…</p>
    {/if}
  </div>
  <div class="buttons">
    <button type="button" class="text" onclick={() => (ticket = null)}>Cancel</button>
  </div>
{/if}
