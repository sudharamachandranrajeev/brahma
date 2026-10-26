<script lang="ts">
  import { app, href } from "../app/state.svelte.ts";
  import { bestPrice, complete, costByShop, pounds, sortItems, type Item } from "../lib/book.ts";
  import { shopName } from "../lib/shops.ts";
  import Dialog from "./Dialog.svelte";
  import Icon from "./Icon.svelte";

  const lists = $derived(app.snap.lists);
  const list = $derived(lists.find((l) => l.id === app.listId) ?? lists[0] ?? null);
  const items = $derived(list ? sortItems(app.snap.items.filter((i) => i.listId === list.id)) : []);
  const left = $derived(items.filter((i) => !i.done));
  const costs = $derived(costByShop(left, app.snap.prices));

  let adding = $state("");
  let addField: HTMLInputElement | undefined = $state();

  // List dialogs: new, rename, delete.
  let listDialog = $state<"new" | "rename" | "delete" | null>(null);
  let listName = $state("");
  let listError = $state("");

  // Item editor.
  let editing = $state<Item | null>(null);
  let editName = $state("");
  let editQty = $state("1");
  let editNote = $state("");
  let editError = $state("");

  const label = (i: Item) => `${i.qty > 1 ? `${i.qty} × ` : ""}${i.name}`;

  async function add(e: SubmitEvent) {
    e.preventDefault();
    const text = adding.trim();
    if (!list || !text) return;
    adding = "";
    await app.act(() => app.book.addItem(list.id, text), `Added ${text}`);
    addField?.focus();
  }

  function openList(kind: "new" | "rename" | "delete") {
    listName = kind === "new" ? (lists.length ? "" : "Weekly shop") : (list?.name ?? "");
    listError = "";
    listDialog = kind;
  }

  async function saveList(e: SubmitEvent) {
    e.preventDefault();
    if (listDialog === "delete") {
      const gone = list!;
      if (await app.act(() => app.book.removeList(gone.id), `Deleted ${gone.name}`)) app.listId = null;
      listDialog = null;
      return;
    }
    if (!listName.trim()) {
      listError = "Give the list a name.";
      return;
    }
    if (listDialog === "new") {
      let id = "";
      if (await app.act(async () => (id = await app.book.addList(listName)))) app.listId = id;
    } else if (list) {
      const current = list;
      await app.act(() => app.book.renameList(current.id, listName));
    }
    listDialog = null;
  }

  function edit(i: Item) {
    editing = i;
    editName = i.name;
    editQty = String(i.qty);
    editNote = i.note;
    editError = "";
  }

  async function saveItem(e: SubmitEvent) {
    e.preventDefault();
    const qty = Math.round(Number(editQty));
    if (!editName.trim()) return void (editError = "Give the item a name.");
    if (!Number.isFinite(qty) || qty < 1) return void (editError = "How many must be 1 or more.");
    const i = editing!;
    await app.act(() => app.book.saveItem({ ...i, name: editName.trim(), qty: Math.min(qty, 999), note: editNote.trim() }));
    editing = null;
  }

  async function removeItem() {
    const i = editing!;
    editing = null;
    await app.act(() => app.book.removeItem(i.id), `Deleted ${i.name}`);
  }
</script>

<div class="page-head">
  <h1 tabindex="-1">{list?.name ?? "Lists"}</h1>
  {#if list}
    <div class="toolbar" role="group" aria-label="List">
      {#if lists.length > 1}
        <label class="inline">
          <span class="sr-only">Show list</span>
          <select bind:value={() => list.id, (v) => (app.listId = v)}>
            {#each lists as l (l.id)}<option value={l.id}>{l.name}</option>{/each}
          </select>
        </label>
      {/if}
      <button type="button" class="tonal" onclick={() => openList("new")}><Icon name="add" /> New list</button>
      <button type="button" class="text" onclick={() => openList("rename")}>Rename</button>
      <button
        type="button"
        class="text"
        disabled={!items.some((i) => i.done)}
        onclick={() => app.act(() => app.book.resetList(list.id), "Everything unticked")}>Untick all</button
      >
      <button type="button" class="text danger" onclick={() => openList("delete")}>Delete list</button>
    </div>
  {/if}
</div>

{#if !list}
  <section class="empty">
    <h2>Start a shopping list</h2>
    <p class="muted">Add what you need, then compare it across shops.</p>
    <button type="button" class="filled" onclick={() => openList("new")}><Icon name="add" /> New list</button>
  </section>
{:else}
  <form class="add" onsubmit={add}>
    <label for="add-item">Add an item</label>
    <div class="field-row">
      <input
        id="add-item"
        bind:this={addField}
        bind:value={adding}
        placeholder="2 milk, bread, washing-up liquid"
        autocomplete="off"
        enterkeyhint="done"
      />
      <button type="submit" class="filled" aria-label="Add"><Icon name="add" /></button>
    </div>
  </form>

  {#if items.length === 0}
    <p class="empty muted">Nothing on this list yet.</p>
  {:else}
    <section class="card" aria-labelledby="to-buy">
      <h2 id="to-buy">{left.length} to buy</h2>
      <ul class="items">
        {#each items as i (i.id)}
          {@const best = bestPrice(i.id, app.snap.prices)}
          {@const group = items.filter((x) => x.done === i.done)}
          {@const at = group.indexOf(i)}
          <li class:done={i.done}>
            <input
              type="checkbox"
              id="item-{i.id}"
              checked={i.done}
              onchange={(e) => app.act(() => app.book.tick(i, e.currentTarget.checked))}
            />
            <div class="what">
              <label for="item-{i.id}">{label(i)}</label>
              <span class="sub">
                {#if best}
                  <span class="price">{pounds(best.pence)} at {shopName(best.shop)}{best.offer ? ` · ${best.offer}` : ""}</span>
                {:else if i.note}
                  {i.note}
                {/if}
                <a href={href({ page: "compare", itemId: i.id })}>Compare prices<span class="sr-only"> for {i.name}</span></a>
              </span>
            </div>
            <div class="actions">
              <button
                type="button"
                class="icon-btn"
                aria-label="Move {i.name} up"
                disabled={at === 0}
                onclick={() => app.act(() => app.book.move(list.id, i.id, -1))}><Icon name="up" /></button
              >
              <button
                type="button"
                class="icon-btn"
                aria-label="Move {i.name} down"
                disabled={at === group.length - 1}
                onclick={() => app.act(() => app.book.move(list.id, i.id, 1))}><Icon name="down" /></button
              >
              <button type="button" class="icon-btn" aria-label="Edit {i.name}" onclick={() => edit(i)}
                ><Icon name="edit" /></button
              >
            </div>
          </li>
        {/each}
      </ul>
    </section>
  {/if}

  {#if left.length}
    <section class="card" aria-labelledby="where">
      <h2 id="where">Where to shop</h2>
      {#if costs.length === 0}
        <p class="muted">No prices yet. Use "Compare prices" on an item to cost the list.</p>
      {:else}
        <ul class="costs">
          {#each costs as c (c.shop)}
            <li>
              <span class="shop">{shopName(c.shop)}</span>
              <span class="muted">{complete(c) ? "Every item priced" : `${c.priced} of ${c.items} items priced`}</span>
              <span class="total">{pounds(c.pence)}</span>
            </li>
          {/each}
        </ul>
      {/if}
      <p class="muted small">Filling a shop's basket for you needs the Android or Windows app.</p>
    </section>
  {/if}
{/if}

<Dialog
  open={listDialog !== null}
  title={listDialog === "new" ? "New list" : listDialog === "rename" ? "Rename list" : `Delete ${list?.name ?? "list"}?`}
  onclose={() => (listDialog = null)}
>
  <form onsubmit={saveList}>
    {#if listDialog === "delete"}
      <p>Its items go too. Prices you kept stay.</p>
    {:else}
      <label for="list-name">Name</label>
      <!-- svelte-ignore a11y_autofocus -->
      <input id="list-name" bind:value={listName} autofocus aria-describedby="list-error" />
      <p id="list-error" class="error" role="alert">{listError}</p>
    {/if}
    <div class="buttons">
      <button type="button" class="text" onclick={() => (listDialog = null)}>Cancel</button>
      <button type="submit" class={listDialog === "delete" ? "filled danger" : "filled"}
        >{listDialog === "new" ? "Create" : listDialog === "delete" ? "Delete" : "Save"}</button
      >
    </div>
  </form>
</Dialog>

<Dialog open={editing !== null} title="Edit item" onclose={() => (editing = null)}>
  <form onsubmit={saveItem}>
    <label for="item-name">Name</label>
    <!-- svelte-ignore a11y_autofocus -->
    <input id="item-name" bind:value={editName} autofocus />
    <label for="item-qty">How many</label>
    <input id="item-qty" type="number" inputmode="numeric" min="1" max="999" bind:value={editQty} />
    <label for="item-note">Note</label>
    <input id="item-note" bind:value={editNote} placeholder='Brand, size, "only if on offer"' />
    <p class="error" role="alert">{editError}</p>
    <div class="buttons">
      <button type="button" class="text danger" onclick={removeItem}><Icon name="delete" /> Delete</button>
      <span class="spacer"></span>
      <button type="button" class="text" onclick={() => (editing = null)}>Cancel</button>
      <button type="submit" class="filled">Save</button>
    </div>
  </form>
</Dialog>
