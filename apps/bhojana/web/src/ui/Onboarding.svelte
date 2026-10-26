<script lang="ts">
  // First run in this browser, mirroring the native sync wizard. The server is
  // the one serving this page, so there is no address to type: the first
  // account uses the setup code, later ones an invite code from the owner.
  import { onMount, tick } from "svelte";
  import { app, errorText } from "../app/state.svelte.ts";
  import { RecoveryKeyNeeded } from "../lib/account.ts";
  import { WorkerApi } from "../lib/api.ts";
  import { MIN_PASSWORD_LENGTH } from "../lib/crypto.ts";
  import { parseLink } from "../lib/pairing.ts";
  import JoinDevice from "./JoinDevice.svelte";

  type Step = "welcome" | "account" | "recovery" | "recover" | "reset" | "join";
  let step = $state<Step>("welcome");
  let create = $state(false);
  let needsSetup = $state(false);
  let reachable = $state<boolean | null>(null);

  let email = $state("");
  let password = $state("");
  let repeat = $state("");
  let code = $state("");
  let recoveryInput = $state("");
  let remember = $state(true);
  let error = $state("");
  let busy = $state(false);
  let recovery = $state("");
  let saved = $state(false);
  let root: HTMLElement | undefined = $state();

  onMount(async () => {
    try {
      needsSetup = (await new WorkerApi(location.origin).health()).needsSetup;
      reachable = true;
    } catch {
      reachable = false;
    }
  });

  async function go(next: Step, mode?: boolean) {
    if (mode !== undefined) create = mode;
    error = "";
    step = next;
    // New step, new heading: put focus there so it is read out.
    await tick();
    root?.querySelector<HTMLElement>("h1")?.focus();
  }

  /// A pasted setup link fills in its invite code.
  function readCode() {
    if (!/^[a-z][a-z0-9]*:\/\//i.test(code.trim())) return;
    try {
      const link = parseLink(code);
      if (link.kind === "setup") {
        code = link.invite;
        if (link.server !== location.origin) error = `That link is for the server at ${link.server}.`;
      }
    } catch (e) {
      error = errorText(e);
    }
  }

  async function run(work: () => Promise<void>) {
    error = "";
    busy = true;
    try {
      await work();
    } catch (e) {
      if (e instanceof RecoveryKeyNeeded) await go("recover");
      else {
        error = errorText(e);
        await tick();
        root?.querySelector<HTMLElement>(".error")?.focus();
      }
    } finally {
      busy = false;
    }
  }

  function account(e: SubmitEvent) {
    e.preventDefault();
    if (create && password.length < MIN_PASSWORD_LENGTH) return void (error = `Use at least ${MIN_PASSWORD_LENGTH} characters.`);
    if (create && password !== repeat) return void (error = "The passwords differ.");
    if (create && !code.trim()) return void (error = "Enter the code.");
    void run(async () => {
      app.useMemoryKeys(remember);
      if (create) {
        recovery = await app.account.signUp(email, password, code);
        await go("recovery");
      } else {
        await app.account.signIn(email, password);
        await app.enter();
      }
    });
  }

  function unlock(e: SubmitEvent) {
    e.preventDefault();
    void run(async () => {
      await app.account.unlockWithRecoveryKey(recoveryInput);
      await app.enter();
    });
  }

  function reset(e: SubmitEvent) {
    e.preventDefault();
    if (password.length < MIN_PASSWORD_LENGTH) return void (error = `Use at least ${MIN_PASSWORD_LENGTH} characters.`);
    if (password !== repeat) return void (error = "The passwords differ.");
    void run(async () => {
      app.useMemoryKeys(remember);
      await app.account.resetPassword(email, code, password, recoveryInput);
      await app.enter();
    });
  }

  async function copyKey() {
    try {
      await navigator.clipboard.writeText(recovery);
    } catch {
      // The key stays selectable on screen.
    }
  }

  function downloadKey() {
    const blob = new Blob(
      [`Bhojana recovery key for ${email.trim().toLowerCase()}\n\n${recovery}\n\nWith your password it is the only way to unlock your synced lists.\n`],
      { type: "text/plain" },
    );
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "bhojana-recovery-key.txt";
    a.click();
    URL.revokeObjectURL(a.href);
  }
</script>

<main class="onboarding" bind:this={root}>
  <img class="logo" src="/icon.svg" alt="" width="72" height="72" />

  {#if step === "welcome"}
    <h1 tabindex="-1">Bhojana on the web</h1>
    <p>Your shopping lists, in step with Bhojana on your phone and computer. They are end-to-end encrypted: this server only ever holds ciphertext.</p>
    {#if reachable === false}
      <p class="error" role="alert">The sync server is not answering. Check your connection and reload.</p>
    {:else if reachable && needsSetup}
      <p class="muted">No one has signed up on this server yet: you will create the owner account with the setup code printed when it was deployed.</p>
      <div class="stack"><button type="button" class="filled" onclick={() => go("account", true)}>Create the owner account</button></div>
    {:else if reachable}
      <div class="stack">
        <button type="button" class="filled" onclick={() => go("account", false)}>Sign in</button>
        <button type="button" class="tonal" onclick={() => go("join")}>Join from a device I already use</button>
        <button type="button" class="text" onclick={() => go("account", true)}>Create an account with an invite code</button>
      </div>
    {:else}
      <p role="status">Checking the server…</p>
    {/if}
  {:else if step === "account"}
    <h1 tabindex="-1">{create ? (needsSetup ? "Create the owner account" : "Create your account") : "Sign in"}</h1>
    <p class="muted">
      {create
        ? needsSetup
          ? "You deployed this server, so this account is its owner: it can invite everyone else."
          : "The owner of the server gives you an invite code."
        : "Use the e-mail and password of your sync account."}
    </p>
    <form onsubmit={account}>
      <label for="email">E-mail</label>
      <input id="email" type="email" bind:value={email} autocomplete="username" required />
      <label for="password">Password</label>
      <input
        id="password"
        type="password"
        bind:value={password}
        autocomplete={create ? "new-password" : "current-password"}
        minlength={create ? MIN_PASSWORD_LENGTH : undefined}
        aria-describedby={create ? "password-help" : undefined}
        required
      />
      {#if create}
        <p id="password-help" class="help">At least {MIN_PASSWORD_LENGTH} characters; a passphrase is best. It cannot be recovered by anyone.</p>
        <label for="repeat">Repeat password</label>
        <input id="repeat" type="password" bind:value={repeat} autocomplete="new-password" required />
        <label for="code">{needsSetup ? "Setup code" : "Invite code"}</label>
        <input id="code" bind:value={code} onchange={readCode} autocomplete="off" spellcheck="false" aria-describedby="code-help" required />
        <p id="code-help" class="help">
          {needsSetup ? "Printed by npm run setup; you can paste the whole setup link." : "From the server owner."}
        </p>
      {/if}
      <label class="check"><input type="checkbox" bind:checked={remember} /> Keep me signed in on this browser</label>
      <p class="help">Untick on a shared computer: closing the tab then signs you out and removes your lists from this browser.</p>
      <p class="error" role="alert" tabindex="-1">{error}</p>
      <div class="buttons">
        <button type="button" class="text" onclick={() => go("welcome")}>Back</button>
        <button type="submit" class="filled" disabled={busy}>
          {busy ? "Working…" : create ? "Create account" : "Sign in"}
        </button>
      </div>
      {#if !create}
        <p><button type="button" class="link" onclick={() => go("reset")}>Forgot your password? I have a reset code</button></p>
      {/if}
    </form>
  {:else if step === "recovery"}
    <h1 tabindex="-1">Save your recovery key</h1>
    <p>If you forget your password, this key is the only way to unlock your synced lists. It is shown once and is not stored anywhere.</p>
    <p class="recovery" aria-label="Recovery key">{recovery}</p>
    <div class="buttons start">
      <button type="button" class="tonal" onclick={copyKey}>Copy</button>
      <button type="button" class="tonal" onclick={downloadKey}>Download as a text file</button>
    </div>
    <label class="check"><input type="checkbox" bind:checked={saved} /> I have saved my recovery key somewhere safe</label>
    <div class="buttons"><button type="button" class="filled" disabled={!saved} onclick={() => app.enter()}>Continue</button></div>
  {:else if step === "recover"}
    <h1 tabindex="-1">Enter your recovery key</h1>
    <p class="muted">Your password was changed or reset, so the key that unlocks your lists needs your recovery key once.</p>
    <form onsubmit={unlock}>
      <label for="recovery-key">Recovery key</label>
      <!-- svelte-ignore a11y_autofocus -->
      <input id="recovery-key" bind:value={recoveryInput} autocomplete="off" spellcheck="false" autofocus required />
      <p class="error" role="alert" tabindex="-1">{error}</p>
      <div class="buttons">
        <button type="button" class="text" onclick={() => go("account", false)}>Back</button>
        <button type="submit" class="filled" disabled={busy}>{busy ? "Unlocking…" : "Unlock"}</button>
      </div>
    </form>
  {:else if step === "reset"}
    <h1 tabindex="-1">Choose a new password</h1>
    <p class="muted">Ask the server owner for a reset code (Settings, Reset a member's login). You also need your recovery key.</p>
    <form onsubmit={reset}>
      <label for="r-email">E-mail</label>
      <input id="r-email" type="email" bind:value={email} autocomplete="username" required />
      <label for="r-code">Reset code</label>
      <input id="r-code" bind:value={code} autocomplete="off" spellcheck="false" required />
      <label for="r-password">New password</label>
      <input id="r-password" type="password" bind:value={password} autocomplete="new-password" minlength={MIN_PASSWORD_LENGTH} required />
      <label for="r-repeat">Repeat new password</label>
      <input id="r-repeat" type="password" bind:value={repeat} autocomplete="new-password" required />
      <label for="r-key">Recovery key</label>
      <input id="r-key" bind:value={recoveryInput} autocomplete="off" spellcheck="false" required />
      <label class="check"><input type="checkbox" bind:checked={remember} /> Keep me signed in on this browser</label>
      <p class="error" role="alert" tabindex="-1">{error}</p>
      <div class="buttons">
        <button type="button" class="text" onclick={() => go("account", false)}>Back</button>
        <button type="submit" class="filled" disabled={busy}>{busy ? "Working…" : "Set password"}</button>
      </div>
    </form>
  {:else}
    <JoinDevice onjoined={() => app.enter()} onback={() => go("welcome")} />
  {/if}
</main>
