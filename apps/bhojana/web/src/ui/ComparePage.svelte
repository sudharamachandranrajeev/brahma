<script lang="ts">
  import { app, href } from "../app/state.svelte.ts";
  import { myShops, niceDate, parsePounds, pounds, SHOPS_PREF } from "../lib/book.ts";
  import { SHOPS, searchable, searchUrl, shopName } from "../lib/shops.ts";
  import Icon from "./Icon.svelte";
  import { extensionVersion, rank, searchWithExtension, type Offer } from "../lib/extension.ts";

  let { itemId }: { itemId: string } = $props();

  const item = $derived(app.snap.items.find((i) => i.id === itemId) ?? null);
  const mine = $derived(myShops(app.snap.prefs.get(SHOPS_PREF) ?? null));
  // Prices found by the native reader carry the product link the shop page
  // gave; only web links are followed (never javascript: and the like).
  const kept = $derived(app.snap.prices.filter((p) => p.itemId === itemId));

  let query = $state("");
  let shop = $state("");
  let title = $state("");
  let price = $state("");
  let error = $state("");

  // Start the fields from the item once it is known (it may arrive by sync).
  let seeded = false;
  $effect(() => {
    if (item && !seeded) {
      seeded = true;
      query = item.name;
      title = item.name;
      shop = (mine[0] ?? SHOPS[0]).id;
    }
  });

  // The browser extension, when installed and allowed on this server, reads
  // the shops' pages in the user's own signed-in browser.
  let extension = $state<string | null>(null);
  extensionVersion().then((v) => (extension = v));

  type Found = { state: "loading" } | { state: "done"; offers: Offer[] } | { state: "error"; message: string };
  let searched = $state("");
  let found = $state<Record<string, Found>>({});

  async function liveSearch(e: SubmitEvent) {
    e.preventDefault();
    const q = (query || item!.name).trim();
    const targets = mine.filter(searchable);
    searched = q;
    found = Object.fromEntries(targets.map((s) => [s.id, { state: "loading" } as Found]));
    // Three at a time: each shop is a whole web page in a background tab.
    for (let i = 0; i < targets.length; i += 3) {
      await Promise.all(
        targets.slice(i, i + 3).map(async (s) => {
          let r: Found;
          try {
            r = { state: "done", offers: rank(q, await searchWithExtension(searchUrl(s, q))) };
          } catch (err) {
            r = { state: "error", message: (err as Error).message };
          }
          if (searched === q) found[s.id] = r;
        }),
      );
    }
  }

  async function keepOffer(shopId: string, o: Offer) {
    const it = item!;
    await app.act(
      () => app.book.keepOffer({ itemId: it.id, query: searched, shop: shopId, offer: o }),
      `Kept ${pounds(o.pence)} at ${shopName(shopId)}`,
    );
  }

  async function keep(e: SubmitEvent) {
    e.preventDefault();
    const pence = parsePounds(price);
    if (!title.trim()) return void (error = "Name the product.");
    if (pence === null) return void (error = "Type the price, like 1.25.");
    error = "";
    const it = item!;
    const t = title.trim();
    const saved = await app.act(
      () => app.book.keepTypedPrice({ itemId: it.id, query: t, shop, title: t, pence }),
      `Kept ${pounds(pence)} at ${shopName(shop)}`,
    );
    if (saved) price = "";
  }
</script>

<div class="page-head">
  <a class="back" href={href({ page: "list" })}>Back to the list</a>
  <h1 tabindex="-1">{item ? `Compare ${item.name}` : "Compare"}</h1>
</div>

{#if !item}
  <p class="empty muted">This item is no longer on any list.</p>
{:else}
  {#if extension === null}
    <section class="card note" aria-labelledby="live">
      <h2 id="live">Live prices</h2>
      <p>
        A web page cannot read shop websites for you. The Bhojana browser extension (on a computer) and the Android
        and Windows apps read live prices, including your loyalty prices when you are signed in to the shop, and the
        prices they keep sync here.
      </p>
      <p>Without them, open each shop's search in a new tab and type in what you find.</p>
    </section>
  {:else}
    <section class="card" aria-labelledby="live">
      <h2 id="live">Live prices</h2>
      <p class="muted">
        The Bhojana extension reads each starred shop in a background tab of this browser, with your shop sign-ins.
      </p>
      <form onsubmit={liveSearch} class="row-form">
        <label for="live-query" class="sr-only">Product to search for</label>
        <input id="live-query" bind:value={query} placeholder="semi-skimmed milk 4 pints" />
        <button type="submit" class="filled" disabled={!mine.some(searchable)}>Search shops</button>
      </form>
      <div aria-live="polite">
        {#each Object.entries(found) as [shopId, r] (shopId)}
          <h3>{shopName(shopId)}</h3>
          {#if r.state === "loading"}
            <p class="muted">Reading…</p>
          {:else if r.state === "error"}
            <p class="error">{r.message}</p>
          {:else if !r.offers.length}
            <p class="muted">Nothing found. Open the shop, accept its cookie banner or sign in, and search again.</p>
          {:else}
            <ul class="prices">
              {#each r.offers.slice(0, 5) as o, n (n)}
                <li>
                  <div class="what">
                    <span class="title">{o.title}</span>
                    <span class="sub">{[o.offer, o.unit, o.inStock ? "" : "out of stock"].filter(Boolean).join(" · ")}</span>
                  </div>
                  <span class="total">{pounds(o.pence)}</span>
                  <button type="button" class="tonal" onclick={() => keepOffer(shopId, o)}
                    >Keep<span class="sr-only"> {o.title} at {shopName(shopId)}</span></button
                  >
                </li>
              {/each}
            </ul>
          {/if}
        {/each}
      </div>
    </section>
  {/if}

  <section class="card" aria-labelledby="search">
    <h2 id="search">Search the shops</h2>
    <label for="query">Product</label>
    <input id="query" bind:value={query} placeholder="semi-skimmed milk 4 pints" />
    {#if mine.some(searchable)}
      <ul class="chips" aria-label="Open a shop's search in a new tab">
        {#each mine.filter(searchable) as s (s.id)}
          <li>
            <a class="chip" href={searchUrl(s, query || item.name)} target="_blank" rel="noopener noreferrer"
              >{s.name} <Icon name="open" size={16} /><span class="sr-only"> (opens in a new tab)</span></a
            >
          </li>
        {/each}
      </ul>
    {:else}
      <p class="muted">Star some shops on the <a href={href({ page: "shops" })}>Shops</a> page to search them here.</p>
    {/if}
  </section>

  <section class="card" aria-labelledby="type">
    <h2 id="type">Type a price</h2>
    <form onsubmit={keep} class="grid-form">
      <div>
        <label for="price-shop">Shop</label>
        <select id="price-shop" bind:value={shop}>
          {#each SHOPS as s (s.id)}<option value={s.id}>{s.name}</option>{/each}
        </select>
      </div>
      <div>
        <label for="price-title">Product</label>
        <input id="price-title" bind:value={title} />
      </div>
      <div>
        <label for="price-pence">Price in £</label>
        <input id="price-pence" bind:value={price} inputmode="decimal" placeholder="1.25" aria-describedby="price-error" />
      </div>
      <p id="price-error" class="error" role="alert">{error}</p>
      <div class="buttons start"><button type="submit" class="filled">Keep this price</button></div>
    </form>
  </section>

  {#if kept.length}
    <section class="card" aria-labelledby="kept">
      <h2 id="kept">Prices kept</h2>
      <ul class="prices">
        {#each kept as p (p.id)}
          <li>
            <div class="what">
              <span class="title">{p.title}</span>
              <span class="sub"
                >{[shopName(p.shop), niceDate(p.day), p.offer, p.unitPrice, p.source === "signed-in" ? "your prices" : "", p.inStock ? "" : "out of stock"]
                  .filter(Boolean)
                  .join(" · ")}</span
              >
            </div>
            <span class="total">{pounds(p.pence)}</span>
            {#if /^https?:\/\//i.test(p.url)}
              <a class="icon-btn" href={p.url} target="_blank" rel="noopener noreferrer" aria-label="Open {p.title} at {shopName(p.shop)} (new tab)"
                ><Icon name="open" /></a
              >
            {/if}
            <button
              type="button"
              class="icon-btn"
              aria-label="Forget {pounds(p.pence)} at {shopName(p.shop)}"
              onclick={() => app.act(() => app.book.removePrice(p.id), "Price forgotten")}><Icon name="close" /></button
            >
          </li>
        {/each}
      </ul>
    </section>
  {/if}
{/if}
