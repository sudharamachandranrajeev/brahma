<script lang="ts">
  // The password changed on another device: the stored login no longer works.
  // Signing in again keeps this browser's lists and unsynced changes.
  import { app, errorText } from "../app/state.svelte.ts";
  import { RecoveryKeyNeeded } from "../lib/account.ts";

  let password = $state("");
  let recovery = $state("");
  let needKey = $state(false);
  let error = $state("");
  let busy = $state(false);

  async function submit(e: SubmitEvent) {
    e.preventDefault();
    error = "";
    busy = true;
    try {
      if (needKey) await app.account.unlockWithRecoveryKey(recovery);
      else await app.account.signIn(app.email, password);
      password = recovery = "";
      app.sync.signInAgain = false;
      await app.syncNow();
    } catch (err) {
      if (err instanceof RecoveryKeyNeeded) needKey = true;
      else error = errorText(err);
    } finally {
      busy = false;
    }
  }
</script>

<section class="banner" aria-labelledby="again">
  <h2 id="again">Sign in again to keep syncing</h2>
  <p>{app.sync.error}</p>
  <form onsubmit={submit} class="row wrap">
    <input type="email" value={app.email} autocomplete="username" hidden readonly />
    {#if needKey}
      <label for="again-key">Recovery key</label>
      <input id="again-key" bind:value={recovery} autocomplete="off" spellcheck="false" class="grow" required />
    {:else}
      <label for="again-pw">Password</label>
      <input id="again-pw" type="password" bind:value={password} autocomplete="current-password" class="grow" required />
    {/if}
    <button type="submit" class="filled" disabled={busy}>{busy ? "Signing in…" : needKey ? "Unlock" : "Sign in"}</button>
  </form>
  <p class="error" role="alert">{error}</p>
</section>
