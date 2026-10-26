<script lang="ts">
  import { onMount, tick } from "svelte";
  import { app, href } from "./app/state.svelte.ts";
  import ComparePage from "./ui/ComparePage.svelte";
  import Icon from "./ui/Icon.svelte";
  import ListPage from "./ui/ListPage.svelte";
  import Onboarding from "./ui/Onboarding.svelte";
  import SettingsPage from "./ui/SettingsPage.svelte";
  import ShopsPage from "./ui/ShopsPage.svelte";
  import SignInAgain from "./ui/SignInAgain.svelte";

  let main: HTMLElement | undefined = $state();
  let toast = $state("");
  let toastTimer: ReturnType<typeof setTimeout> | undefined;

  onMount(() => void app.start());

  // A new page: move focus to its heading so screen readers announce it and
  // keyboard users start at the top (not on the first page load).
  let shown: string | null = null;
  $effect(() => {
    const key = href(app.route);
    if (shown !== null && shown !== key) void tick().then(() => main?.querySelector<HTMLElement>("h1")?.focus());
    shown = key;
  });

  $effect(() => {
    if (!app.notice) return;
    toast = app.notice;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => {
      toast = "";
      app.notice = "";
    }, 4000);
  });

  const tabs = [
    { page: "list", label: "Lists" },
    { page: "shops", label: "Shops" },
    { page: "settings", label: "Settings" },
  ] as const;
  const current = (page: string) => (app.route.page === "compare" ? "list" : app.route.page) === page;
  const syncLabel = $derived(
    app.sync.busy ? "Syncing" : app.sync.error ? "Not synced" : app.sync.pending ? "Changes waiting" : "Synced",
  );
</script>

{#if app.phase === "loading"}
  <p class="center" role="status">Opening Bhojana…</p>
{:else if app.phase === "failed"}
  <main class="center">
    <h1>Bhojana cannot open here</h1>
    <p>This browser did not let Bhojana use its storage ({app.failure}). Private windows in some browsers block it; try a normal window.</p>
  </main>
{:else if app.phase === "onboarding"}
  <Onboarding />
{:else}
  <button type="button" class="skip" onclick={() => main?.focus()}>Skip to content</button>
  <header class="bar">
    <a class="brand" href={href({ page: "list" })}><img src="/icon.svg" alt="" width="28" height="28" /><span>Bhojana</span></a>
    <nav aria-label="Main">
      <ul>
        {#each tabs as t (t.page)}
          <li><a href={href({ page: t.page })} aria-current={current(t.page) ? "page" : undefined}>{t.label}</a></li>
        {/each}
      </ul>
    </nav>
    <button
      type="button"
      class="icon-btn sync-state"
      class:spin={app.sync.busy}
      class:bad={!!app.sync.error}
      aria-label="{syncLabel}. Sync now"
      title={app.sync.error || syncLabel}
      onclick={() => app.syncNow()}><Icon name={app.sync.error ? "warn" : "sync"} /></button
    >
  </header>
  {#if app.sync.signInAgain}<SignInAgain />{/if}
  <main id="main" tabindex="-1" bind:this={main}>
    {#if app.route.page === "compare"}
      <ComparePage itemId={app.route.itemId} />
    {:else if app.route.page === "shops"}
      <ShopsPage />
    {:else if app.route.page === "settings"}
      <SettingsPage />
    {:else}
      <ListPage />
    {/if}
  </main>
{/if}

<div class="toast" class:show={!!toast} role="status" aria-live="polite">{toast}</div>
