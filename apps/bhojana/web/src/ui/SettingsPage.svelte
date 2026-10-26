<script lang="ts">
  import { onMount } from "svelte";
  import { app, errorText } from "../app/state.svelte.ts";
  import { MIN_PASSWORD_LENGTH } from "../lib/crypto.ts";
  import AddDevice from "./AddDevice.svelte";
  import Dialog from "./Dialog.svelte";
  import Icon from "./Icon.svelte";

  let owner = $state(false);
  let devices = $state<string[] | null>(null);
  let members = $state<{ email: string; owner: boolean }[]>([]);
  let pairing = $state(false);
  let confirmOut = $state(false);

  let oldPw = $state("");
  let newPw = $state("");
  let repeatPw = $state("");
  let pwError = $state("");
  let pwBusy = $state(false);

  let invite = $state<{ code: string; expires: number } | null>(null);
  let resetEmail = $state("");
  let resetCode = $state<{ code: string; expires: number } | null>(null);
  let ownerError = $state("");

  async function load() {
    try {
      const api = await app.account.api();
      owner = (await api.me()).owner;
      devices = await api.deviceIds();
      if (owner) members = await api.members();
    } catch {
      // Offline or signed out elsewhere: the sync card says which.
    }
  }
  onMount(load);

  const when = (t: number) =>
    t ? new Date(t).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" }) : "not yet";
  const until = (s: number) => new Date(s * 1000).toLocaleDateString(undefined, { dateStyle: "medium" });

  async function changePassword(e: SubmitEvent) {
    e.preventDefault();
    if (newPw.length < MIN_PASSWORD_LENGTH) return void (pwError = `Use at least ${MIN_PASSWORD_LENGTH} characters.`);
    if (newPw !== repeatPw) return void (pwError = "The new passwords differ.");
    pwError = "";
    pwBusy = true;
    try {
      await app.account.changePassword(oldPw, newPw);
      oldPw = newPw = repeatPw = "";
      app.notice = "Password changed. Your other devices ask for it the next time they sync.";
    } catch (err) {
      pwError = errorText(err);
    } finally {
      pwBusy = false;
    }
  }

  async function makeInvite() {
    ownerError = "";
    try {
      invite = await (await app.account.api()).createInvite();
    } catch (e) {
      ownerError = errorText(e);
    }
  }

  async function makeReset(e: SubmitEvent) {
    e.preventDefault();
    ownerError = "";
    try {
      resetCode = await (await app.account.api()).createResetCode(resetEmail);
    } catch (err) {
      ownerError = errorText(err);
    }
  }

  const inviteLink = (code: string) => `bhojana://setup?${new URLSearchParams({ s: location.origin, i: code })}`;
</script>

<div class="page-head"><h1 tabindex="-1">Settings</h1></div>

<section class="card" aria-labelledby="sync">
  <h2 id="sync">Sync</h2>
  <p>Signed in as <strong>{app.email}</strong>.</p>
  <dl class="facts">
    <dt>Status</dt>
    <dd>
      {#if app.sync.busy}Syncing…{:else if app.sync.error}<span class="error-text">{app.sync.error}</span>{:else}Up to date{/if}
    </dd>
    <dt>Last synced</dt>
    <dd>{when(app.sync.last)}</dd>
    <dt>Waiting to send</dt>
    <dd>{app.sync.pending === 0 ? "nothing" : `${app.sync.pending} change${app.sync.pending === 1 ? "" : "s"}`}</dd>
  </dl>
  <p class="muted small">Syncs when it opens, shortly after each change, when you come back to the tab, and every 15 minutes.</p>
  <div class="buttons start">
    <button type="button" class="filled" disabled={app.sync.busy} onclick={() => app.syncNow()}><Icon name="sync" /> Sync now</button>
  </div>
</section>

<section class="card" aria-labelledby="devices">
  <h2 id="devices">Devices</h2>
  <p>
    {#if devices === null}
      The device list loads when the server answers.
    {:else}
      This account syncs {devices.length} device{devices.length === 1 ? "" : "s"}: this browser{devices.length > 1 ? ` and ${devices.length - 1} other${devices.length > 2 ? "s" : ""}` : ""}.
    {/if}
  </p>
  <p class="muted small">The server keeps device numbers only; names are never sent to it.</p>
  <div class="buttons start">
    <button type="button" class="tonal" onclick={() => (pairing = true)}>Add a device</button>
  </div>
</section>

<section class="card" aria-labelledby="browser">
  <h2 id="browser">This browser</h2>
  <label class="check">
    <input type="checkbox" checked={app.remember} onchange={(e) => app.setRemember(e.currentTarget.checked)} />
    Keep me signed in on this browser
  </label>
  <p class="muted small">
    {app.remember
      ? "Your keys and lists stay in this browser's storage until you sign out."
      : "Your keys are held in this tab only. Closing it signs you out and removes your lists from this browser; changes that have not synced yet are lost."}
  </p>
</section>

<section class="card" aria-labelledby="password">
  <h2 id="password">Change password</h2>
  <form onsubmit={changePassword}>
    <input type="email" value={app.email} autocomplete="username" hidden readonly />
    <label for="old-pw">Current password</label>
    <input id="old-pw" type="password" bind:value={oldPw} autocomplete="current-password" required />
    <label for="new-pw">New password</label>
    <input id="new-pw" type="password" bind:value={newPw} autocomplete="new-password" minlength={MIN_PASSWORD_LENGTH} required />
    <label for="repeat-pw">Repeat new password</label>
    <input id="repeat-pw" type="password" bind:value={repeatPw} autocomplete="new-password" required />
    <p class="error" role="alert">{pwError}</p>
    <div class="buttons start">
      <button type="submit" class="filled" disabled={pwBusy}>{pwBusy ? "Changing…" : "Change password"}</button>
    </div>
  </form>
</section>

{#if owner}
  <section class="card" aria-labelledby="people">
    <h2 id="people">People</h2>
    <p class="muted small">You own this server. Nobody can sign up without a code from you.</p>
    <ul class="plain">
      {#each members as m (m.email)}<li>{m.email}{m.owner ? " (owner)" : ""}</li>{/each}
    </ul>
    <h3>Invite someone</h3>
    <p class="muted small">A one-time code, valid for 7 days, that lets one more person create their own account.</p>
    <div class="buttons start"><button type="button" class="tonal" onclick={makeInvite}>Make an invite code</button></div>
    {#if invite}
      <p role="status">Code <strong class="mono">{invite.code}</strong>, valid until {until(invite.expires)}.</p>
      <label for="invite-link">Setup link for the apps</label>
      <textarea id="invite-link" readonly rows="2" value={inviteLink(invite.code)}></textarea>
    {/if}
    <h3>Reset a member's login</h3>
    <p class="muted small">For someone who forgot their password. They still need their recovery key.</p>
    <form onsubmit={makeReset} class="row">
      <label for="reset-email" class="sr-only">Their e-mail</label>
      <input id="reset-email" type="email" bind:value={resetEmail} placeholder="their e-mail" autocomplete="off" required class="grow" />
      <button type="submit" class="tonal">Make a reset code</button>
    </form>
    {#if resetCode}
      <p role="status">Reset code <strong class="mono">{resetCode.code}</strong>, valid until {until(resetCode.expires)}.</p>
    {/if}
    <p class="error" role="alert">{ownerError}</p>
  </section>
{/if}

<section class="card" aria-labelledby="out">
  <h2 id="out">Sign out</h2>
  <p class="muted small">Removes your keys and lists from this browser. Your account and other devices keep everything.</p>
  <div class="buttons start"><button type="button" class="text danger" onclick={() => (confirmOut = true)}>Sign out</button></div>
</section>

<Dialog open={pairing} title="Add a device" onclose={() => (pairing = false)}>
  <AddDevice onclose={() => (pairing = false)} />
</Dialog>

<Dialog open={confirmOut} title="Sign out of this browser?" onclose={() => (confirmOut = false)}>
  {#if app.sync.pending > 0}
    <p class="error-text">{app.sync.pending} change{app.sync.pending === 1 ? " has" : "s have"} not reached the server yet and will be lost. Sync first if you can.</p>
  {:else}
    <p>Everything here is on the server. Sign in again any time.</p>
  {/if}
  <div class="buttons">
    <button type="button" class="text" onclick={() => (confirmOut = false)}>Cancel</button>
    <button type="button" class="filled danger" onclick={() => app.signOut()}>Sign out</button>
  </div>
</Dialog>
