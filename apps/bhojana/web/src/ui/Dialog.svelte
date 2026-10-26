<script lang="ts">
  // A modal <dialog>: the browser traps focus inside, closes it on Escape and
  // hands focus back to whatever opened it.
  import type { Snippet } from "svelte";

  let {
    open = $bindable(false),
    title,
    children,
    onclose,
  }: { open?: boolean; title: string; children: Snippet; onclose?: () => void } = $props();

  let dialog: HTMLDialogElement | undefined = $state();
  const id = `dialog-${Math.random().toString(36).slice(2, 10)}`;

  $effect(() => {
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    else if (!open && dialog.open) dialog.close();
  });
</script>

<dialog
  bind:this={dialog}
  aria-labelledby={id}
  onclose={() => {
    open = false;
    onclose?.();
  }}
>
  {#if open}
    <h2 {id}>{title}</h2>
    {@render children()}
  {/if}
</dialog>
