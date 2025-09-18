<script lang="ts">
  import { goto } from '$app/navigation';
  let roomId = '';
  let username = '';

  function join() {
    if (!roomId || !username) return;
    const url = `/call/${encodeURIComponent(roomId)}?u=${encodeURIComponent(username)}`;
    goto(url);
  }
</script>

<div class="container">
  <header>
    <h1>Scribal</h1>
  </header>
  <main>
    <div class="card">
      <h2>Join a room</h2>
      <label>
        Room ID
        <input bind:value={roomId} placeholder="e.g. team-standup" />
      </label>
      <label>
        Username
        <input bind:value={username} placeholder="Your name" />
      </label>
      <button on:click={join} disabled={!roomId || !username}>Join</button>
    </div>
  </main>
</div>

<style>
  .card { display: grid; gap: .75rem; max-width: 420px; }
  input { width: 100%; padding: .5rem; font-size: 1rem; }
  button { padding: .6rem .8rem; font-size: 1rem; }
  label { display: grid; gap: .25rem; font-size: .9rem; }
  h2 { margin: .5rem 0; }
</style>

