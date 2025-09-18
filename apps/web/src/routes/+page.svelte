<script lang="ts">
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import Modal from '$lib/components/Modal.svelte';

  let roomId = '';
  let username = '';
  let rememberMe = false;
  let isJoinOpen = false;

  onMount(() => {
    try {
      const saved = localStorage.getItem('scribal:username');
      if (saved) {
        username = saved;
        rememberMe = true;
      }
    } catch {}
  });

  function openJoin() {
    isJoinOpen = true;
  }

  function closeJoin() {
    isJoinOpen = false;
  }

  function join() {
    if (!roomId || !username) return;
    try {
      if (rememberMe) localStorage.setItem('scribal:username', username);
      else localStorage.removeItem('scribal:username');
    } catch {}

    const url = `/call/${encodeURIComponent(roomId)}?u=${encodeURIComponent(username)}`;
    goto(url);
  }

  function signIn() {
    goto('/demo/lucia/login');
  }

  function signUp() {
    goto('/demo/lucia');
  }
</script>

<!-- Hero Section -->
<section class="hero">
  <div class="hero__gradient"></div>
  <div class="hero__blob hero__blob--left"></div>
  <div class="hero__blob hero__blob--right"></div>

  <div class="hero__content">
    <div class="hero-card">
      <h1 class="app-title">Scribal</h1>

      <div class="hero-actions">
        <button class="btn btn-primary" on:click={openJoin}>Join a Meeting</button>
        <button class="btn btn-ghost" on:click={signIn}>Sign in</button>
        <button class="btn btn-ghost" on:click={signUp}>Sign up</button>
      </div>
    </div>
  </div>
</section>

<Modal open={isJoinOpen} title="Join a Meeting" on:close={closeJoin}>
  <form class="join-form" on:submit|preventDefault={join}>
    <div class="input-group">
      <label for="room">Meeting ID</label>
      <input
        id="room"
        class="input"
        placeholder="e.g. team-standup"
        bind:value={roomId}
        autocomplete="off"
      />
    </div>

    <div class="input-group">
      <label for="name">Your name</label>
      <input
        id="name"
        class="input"
        placeholder="Jane Doe"
        bind:value={username}
        autocomplete="name"
      />
    </div>

    <label class="checkbox">
      <input type="checkbox" bind:checked={rememberMe} />
      <span>Remember my name for future meetings</span>
    </label>

    <p class="disclaimer">
      by clicking "Join" you agree to our Terms of Service and Privacy Statement
    </p>

    <div class="form-actions">
      <button type="button" class="btn btn-outline" on:click={closeJoin}>Cancel</button>
      <button type="submit" class="btn btn-primary" disabled={!roomId || !username}>Join</button>
    </div>
  </form>
</Modal>

<style>
  .hero {
    position: relative;
    min-height: 100svh;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    color: #fff;
  }

  .hero__gradient {
    position: absolute;
    inset: 0;
    background: radial-gradient(circle at top, rgba(76, 29, 149, 0.2), transparent 55%),
      radial-gradient(circle at bottom right, rgba(14, 116, 144, 0.15), transparent 60%),
      linear-gradient(135deg, #020617 0%, #0f172a 35%, #020617 100%);
    z-index: 0;
  }

  .hero__blob {
    position: absolute;
    border-radius: 999px;
    filter: blur(82px);
    pointer-events: none;
    z-index: 0;
  }

  .hero__blob--left {
    width: 22rem;
    height: 22rem;
    top: -6rem;
    left: -8rem;
    background: rgba(168, 85, 247, 0.45);
  }

  .hero__blob--right {
    width: 26rem;
    height: 26rem;
    right: -10rem;
    top: 50%;
    transform: translateY(-50%);
    background: rgba(56, 189, 248, 0.35);
  }

  .hero__content {
    position: relative;
    z-index: 1;
    width: min(100%, 34rem);
    padding: 0 1.5rem;
  }

  .hero-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2.5rem;
    padding: clamp(2.25rem, 4vw, 3rem);
    border-radius: 28px;
    background: linear-gradient(135deg, rgba(255, 255, 255, 0.14), rgba(255, 255, 255, 0.06));
    border: 1px solid rgba(255, 255, 255, 0.18);
    box-shadow: 0 25px 60px -30px rgba(59, 130, 246, 0.6);
    backdrop-filter: blur(28px);
    text-align: center;
  }

  .app-title {
    font-size: clamp(3.25rem, 8vw, 4.5rem);
    font-weight: 800;
    letter-spacing: -0.04em;
    background: linear-gradient(90deg, #c084fc 0%, #818cf8 50%, #38bdf8 100%);
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
    text-shadow: 0 10px 35px rgba(30, 64, 175, 0.35);
    margin: 0;
  }

  .hero-actions {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    width: 100%;
  }

  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0.85rem 1.5rem;
    border-radius: 16px;
    font-size: 0.95rem;
    font-weight: 600;
    border: 1px solid transparent;
    cursor: pointer;
    transition: transform 0.2s ease, box-shadow 0.2s ease, background 0.2s ease, border-color 0.2s ease;
  }

  .hero-actions .btn {
    width: 100%;
  }

  @media (min-width: 640px) {
    .hero-actions {
      flex-direction: row;
      justify-content: center;
    }

    .hero-actions .btn {
      width: auto;
      min-width: 9rem;
    }
  }

  .btn-primary {
    background: linear-gradient(90deg, #7c3aed 0%, #38bdf8 100%);
    color: #fff;
    box-shadow: 0 18px 45px -18px rgba(99, 102, 241, 0.75);
  }

  .btn-primary:hover {
    transform: translateY(-1px);
    background: linear-gradient(90deg, #8b5cf6 0%, #38c4f8 100%);
    box-shadow: 0 24px 55px -18px rgba(129, 140, 248, 0.7);
  }

  .btn-ghost {
    background: rgba(255, 255, 255, 0.12);
    color: #fff;
    border-color: rgba(255, 255, 255, 0.18);
  }

  .btn-ghost:hover {
    background: rgba(255, 255, 255, 0.18);
  }

  .btn-outline {
    background: rgba(2, 6, 23, 0.2);
    color: rgba(255, 255, 255, 0.92);
    border-color: rgba(255, 255, 255, 0.28);
  }

  .btn-outline:hover {
    background: rgba(255, 255, 255, 0.12);
  }

  .btn:focus-visible {
    outline: none;
    box-shadow: 0 0 0 3px rgba(191, 219, 254, 0.65);
  }

  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
    transform: none;
    box-shadow: none;
  }

  .join-form {
    display: grid;
    gap: 1.1rem;
  }

  .input-group label {
    display: block;
    margin-bottom: 0.4rem;
    font-size: 0.85rem;
    font-weight: 500;
    color: rgba(255, 255, 255, 0.9);
  }

  .input {
    width: 100%;
    padding: 0.75rem 1rem;
    border-radius: 14px;
    border: 1px solid rgba(255, 255, 255, 0.25);
    background: rgba(255, 255, 255, 0.15);
    color: #fff;
    font-size: 0.95rem;
    backdrop-filter: blur(22px);
    transition: border-color 0.2s ease, box-shadow 0.2s ease, background 0.2s ease;
  }

  .input::placeholder {
    color: rgba(255, 255, 255, 0.65);
  }

  .input:focus-visible {
    outline: none;
    border-color: rgba(168, 85, 247, 0.65);
    box-shadow: 0 0 0 2px rgba(129, 140, 248, 0.45);
    background: rgba(255, 255, 255, 0.24);
  }

  .checkbox {
    display: flex;
    align-items: center;
    gap: 0.65rem;
    font-size: 0.9rem;
    color: rgba(255, 255, 255, 0.9);
    user-select: none;
  }

  .checkbox input[type='checkbox'] {
    width: 1.05rem;
    height: 1.05rem;
    border-radius: 0.4rem;
    border: 1px solid rgba(255, 255, 255, 0.35);
    background: rgba(255, 255, 255, 0.12);
    accent-color: #8b5cf6;
  }

  .disclaimer {
    font-size: 0.75rem;
    color: rgba(255, 255, 255, 0.7);
    line-height: 1.4;
  }

  .form-actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.75rem;
    margin-top: 0.5rem;
  }

  .form-actions .btn {
    min-width: 7rem;
  }

  @media (max-width: 480px) {
    .form-actions {
      flex-direction: column;
    }

    .form-actions .btn {
      width: 100%;
    }
  }
</style>
