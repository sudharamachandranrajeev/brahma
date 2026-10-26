<script lang="ts">
  import { app } from "../app/state.svelte.ts";
  import { myShops, POSTCODE_PREF, SHOPS_PREF, tidyPostcode } from "../lib/book.ts";
  import { SELLING_LABEL, SHOP_KINDS, SHOPS, searchable, type Shop } from "../lib/shops.ts";
  import Dialog from "./Dialog.svelte";
  import Icon from "./Icon.svelte";

  const mine = $derived(new Set(myShops(app.snap.prefs.get(SHOPS_PREF) ?? null).map((s) => s.id)));
  const postcode = $derived(app.snap.prefs.get(POSTCODE_PREF) ?? "");

  let editing = $state(false);
  let draft = $state("");
  let error = $state("");

  function toggle(s: Shop) {
    const next = new Set(mine);
    if (next.has(s.id)) next.delete(s.id);
    else next.add(s.id);
    // Catalogue order, as the native app writes it.
    const ids = SHOPS.filter((x) => next.has(x.id)).map((x) => x.id);
    void app.act(() => app.book.setPref(SHOPS_PREF, ids.join(",")), next.has(s.id) ? `Comparing ${s.name}` : `Stopped comparing ${s.name}`);
  }

  async function savePostcode(e: SubmitEvent) {
    e.preventDefault();
    const p = tidyPostcode(draft);
    if (p === null) return void (error = "That does not look like a UK postcode.");
    await app.act(() => app.book.setPref(POSTCODE_PREF, p));
    editing = false;
  }

  const sub = (s: Shop) =>
    [SELLING_LABEL[s.selling], s.loyalty ? `${s.loyalty} prices when signed in` : "", searchable(s) ? "" : "no online search"]
      .filter(Boolean)
      .join(" · ");
</script>

<div class="page-head"><h1 tabindex="-1">Shops</h1></div>

<section class="card" aria-labelledby="postcode">
  <h2 id="postcode">Your postcode</h2>
  <div class="row">
    <p class="muted grow">
      {postcode
        ? `${postcode}. Give the same postcode to each shop when it asks.`
        : "Not set. Shops price and stock by area, and slots depend on it."}
    </p>
    <button
      type="button"
      class="tonal"
      onclick={() => {
        draft = postcode;
        error = "";
        editing = true;
      }}>{postcode ? "Change" : "Set"}<span class="sr-only"> postcode</span></button
    >
  </div>
</section>

<p class="muted">
  Shops open in a new tab, signed in there with your own shop account. Star the shops you want to compare; the
  Android and Windows apps search the starred ones for live prices.
</p>

{#each SHOP_KINDS as kind (kind)}
  <section class="card" aria-labelledby="kind-{kind}">
    <h2 id="kind-{kind}">{kind}</h2>
    <ul class="shops">
      {#each SHOPS.filter((s) => s.kind === kind) as s (s.id)}
        {@const on = mine.has(s.id)}
        <li>
          <button
            type="button"
            class="icon-btn star"
            class:on
            aria-pressed={on}
            aria-label="Compare {s.name}"
            disabled={!searchable(s)}
            onclick={() => toggle(s)}><Icon name={on ? "star" : "starOff"} /></button
          >
          <div class="what">
            <span class="title">{s.name}</span>
            <span class="sub">{sub(s)}</span>
          </div>
          {#if s.slots}
            <a class="icon-btn" href={s.slots} target="_blank" rel="noopener noreferrer" aria-label="{s.name} delivery slots (new tab)"
              ><Icon name="truck" /></a
            >
          {/if}
          <a class="icon-btn" href={s.home} target="_blank" rel="noopener noreferrer" aria-label="Open {s.name} (new tab)"
            ><Icon name="open" /></a
          >
        </li>
      {/each}
    </ul>
  </section>
{/each}

<Dialog open={editing} title="Your postcode" onclose={() => (editing = false)}>
  <form onsubmit={savePostcode}>
    <label for="postcode-field">Postcode</label>
    <!-- svelte-ignore a11y_autofocus -->
    <input id="postcode-field" bind:value={draft} placeholder="BT74 7AA" autocomplete="postal-code" autofocus aria-describedby="postcode-error" />
    <p id="postcode-error" class="error" role="alert">{error}</p>
    <div class="buttons">
      <button type="button" class="text" onclick={() => (editing = false)}>Cancel</button>
      <button type="submit" class="filled">Save</button>
    </div>
  </form>
</Dialog>
