<script lang="ts">
  import { createEventDispatcher, onDestroy } from 'svelte';

  export let open = false;
  export let title = '';
  export let sizeClass = 'modal-size-md';

  const dispatch = createEventDispatcher<{ close: void }>();
  const labelledBy = 'modal-title-' + Math.random().toString(36).slice(2, 8);

  function close() {
    dispatch('close');
  }

  function onKeydown(e: KeyboardEvent) {
    if (!open) return;
    if (e.key === 'Escape') {
      e.preventDefault();
      close();
    }
  }

  // Attach a keydown listener on mount
  const handler = (e: KeyboardEvent) => onKeydown(e);
  if (typeof window !== 'undefined') {
    window.addEventListener('keydown', handler);
  }
  onDestroy(() => {
    if (typeof window !== 'undefined') {
      window.removeEventListener('keydown', handler);
    }
  });
</script>

{#if open}
  <div class="modal-root">
    <div
      class="modal-backdrop"
      role="button"
      tabindex="0"
      aria-label="Close modal"
      on:click={close}
      on:keydown|preventDefault={(e) => (e.key === 'Enter' || e.key === ' ') && close()}
    ></div>

    <div role="dialog" aria-modal="true" aria-labelledby={labelledBy} class="modal-dialog {sizeClass}">
      <div class="modal-surface">
        {#if title}
          <h2 id={labelledBy} class="modal-title">{title}</h2>
        {/if}
        <div class="modal-body">
          <slot />
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-root {
    position: fixed;
    inset: 0;
    z-index: 50;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1.5rem;
  }

  .modal-backdrop {
    position: absolute;
    inset: 0;
    background: rgba(15, 23, 42, 0.6);
    backdrop-filter: blur(8px);
  }

  .modal-dialog {
    position: relative;
    width: 100%;
  }

  .modal-size-md {
    max-width: 32rem;
  }

  .modal-surface {
    position: relative;
    border-radius: 22px;
    padding: clamp(1.75rem, 4vw, 2.5rem);
    background: linear-gradient(135deg, rgba(255, 255, 255, 0.18), rgba(255, 255, 255, 0.07));
    border: 1px solid rgba(255, 255, 255, 0.24);
    box-shadow: 0 35px 65px -30px rgba(30, 64, 175, 0.35);
    backdrop-filter: blur(28px);
  }

  .modal-title {
    margin: 0;
    font-size: 1.35rem;
    font-weight: 600;
    color: rgba(255, 255, 255, 0.95);
    text-shadow: 0 8px 24px rgba(15, 23, 42, 0.45);
  }

  .modal-body {
    margin-top: 1.5rem;
  }

  @media (max-width: 480px) {
    .modal-root {
      padding: 1rem;
    }

    .modal-surface {
      padding: 1.5rem;
    }
  }
</style>
