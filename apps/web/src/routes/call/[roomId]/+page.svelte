<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { page } from '$app/stores';
  import { createSocket } from '$lib/socket';
  import { startSpeechRecognition } from '$lib/speech';
  import { createPeerConnection } from '$lib/webrtc';

  let roomId = '';
  let username = '';
  let serverUrl = (import.meta as any).env?.VITE_SERVER_URL || 'http://localhost:5174';

  $: roomId = $page.params.roomId;
  $: username = new URLSearchParams($page.url.search).get('u') || '';

  type User = { id: string; username: string };
  let users: User[] = [];

  let localStream: MediaStream | null = null;
  let myVideoEl: HTMLVideoElement;
  let remoteVideos: { id: string; el: HTMLVideoElement }[] = [];

  let transcripts: { id: number|string; username: string; content: string; createdAt?: string }[] = [];
  let interimText = '';

  const peers = new Map<string, RTCPeerConnection>();
  const socket = createSocket(serverUrl);

  function addRemoteVideo(id: string) {
    const el = document.createElement('video');
    el.autoplay = true;
    el.playsInline = true;
    el.muted = false;
    el.setAttribute('data-peer', id);
    remoteVideos = [...remoteVideos, { id, el }];
    return el;
  }

  async function createOfferFor(targetId: string) {
    const pc = createPeerConnection();
    peers.set(targetId, pc);

    localStream?.getTracks().forEach((t) => pc.addTrack(t, localStream!));

    pc.onicecandidate = (e) => {
      if (e.candidate) socket.emit('signal', { targetId, data: { candidate: e.candidate } });
    };
    pc.ontrack = (e) => {
      const el = addRemoteVideo(targetId);
      el.srcObject = e.streams[0];
    };

    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    socket.emit('signal', { targetId, data: { sdp: offer } });
  }

  async function handleSignal({ sourceId, data }: any) {
    let pc = peers.get(sourceId);
    if (!pc) {
      pc = createPeerConnection();
      peers.set(sourceId, pc);
      localStream?.getTracks().forEach((t) => pc!.addTrack(t, localStream!));
      pc.onicecandidate = (e) => {
        if (e.candidate) socket.emit('signal', { targetId: sourceId, data: { candidate: e.candidate } });
      };
      pc.ontrack = (e) => {
        const el = addRemoteVideo(sourceId);
        el.srcObject = e.streams[0];
      };
    }
    if (data.sdp) {
      const desc = new RTCSessionDescription(data.sdp);
      await pc.setRemoteDescription(desc);
      if (desc.type === 'offer') {
        const answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        socket.emit('signal', { targetId: sourceId, data: { sdp: answer } });
      }
    } else if (data.candidate) {
      try { await pc.addIceCandidate(data.candidate); } catch {}
    }
  }

  function appendTranscript(username: string, content: string, id?: number | string, createdAt?: string) {
    transcripts = [{ id: id ?? Date.now(), username, content, createdAt }, ...transcripts].slice(0, 200);
  }

  onMount(async () => {
    // Setup media
    localStream = await navigator.mediaDevices.getUserMedia({ audio: true, video: true });
    myVideoEl.srcObject = localStream;

    // Join signaling
    socket.emit('join_room', { roomId, username });

    socket.on('room_users', (list: User[]) => {
      users = list;
      const others = list.filter((u) => u.id !== socket.id);
      for (const u of others) createOfferFor(u.id);
    });
    socket.on('user_joined', (u: User) => {
      users = [...users, u];
      createOfferFor(u.id);
    });
    socket.on('user_left', (u: User) => {
      users = users.filter((x) => x.id !== u.id);
      const peer = peers.get(u.id);
      peer?.close();
      peers.delete(u.id);
      // remove video element
      const v = remoteVideos.find((rv) => rv.id === u.id);
      if (v) {
        v.el.srcObject = null;
        remoteVideos = remoteVideos.filter((rv) => rv.id !== u.id);
      }
    });
    socket.on('signal', handleSignal);

    // Receive transcripts from server
    socket.on('transcript', (t: any) => {
      appendTranscript(t.username, t.content, t.id, t.createdAt);
    });

    // Fetch history
    try {
      const res = await fetch(`/api/rooms/${encodeURIComponent(roomId)}/transcripts`);
      const hist = await res.json();
      for (const t of hist) appendTranscript(t.username, t.content, t.id, t.createdAt);
    } catch (e) {
      console.warn('Failed to load history', e);
    }

    // Start speech recognition
    const recognizer = startSpeechRecognition({
      onTranscript: (text, isFinal) => {
        if (isFinal) {
          interimText = '';
          socket.emit('transcript', { roomId, userId: socket.id, username, text, timestamp: Date.now() });
        } else {
          interimText = text;
        }
      },
      onError: (e) => console.warn('Speech error', e)
    });

    onDestroy(() => {
      recognizer?.stop?.();
      localStream?.getTracks().forEach((t) => t.stop());
      socket.disconnect();
    });
  });
</script>

<div class="container">
  <header>
    <a href="/">←</a>
    <h1>Room: {roomId}</h1>
    <span class="spacer" />
    <strong>{username}</strong>
  </header>

  <section class="grid">
    <div class="videos">
      <div class="video-tile">
        <video bind:this={myVideoEl} autoplay playsinline muted></video>
        <span class="label">You: {username}</span>
      </div>
      {#each remoteVideos as rv (rv.id)}
        <div class="video-tile">
          <div class="video-mount" this={rv.el}></div>
          <span class="label">{users.find(u => u.id === rv.id)?.username || rv.id}</span>
        </div>
      {/each}
    </div>

    <aside class="side">
      <div class="panel">
        <h3>Live Transcript</h3>
        {#if interimText}
          <div class="interim">{username}: {interimText} …</div>
        {/if}
        {#each transcripts as t (t.id)}
          <div class="line">
            <strong>{t.username}:</strong> {t.content}
            {#if t.createdAt}
              <span class="time">{new Date(t.createdAt).toLocaleTimeString()}</span>
            {/if}
          </div>
        {/each}
      </div>
      <div class="panel">
        <h3>Participants ({users.length})</h3>
        <ul>
          {#each users as u (u.id)}
            <li>{u.username}{u.id === undefined ? '' : ''}</li>
          {/each}
        </ul>
      </div>
    </aside>
  </section>
</div>

<style>
  .spacer { flex: 1; }
  header { display: flex; align-items: center; gap: .5rem; }
  .grid { display: grid; gap: 1rem; grid-template-columns: 1fr 320px; }
  .videos { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: .75rem; }
  .video-tile { position: relative; border: 1px solid #4443; border-radius: .5rem; overflow: hidden; }
  .video-tile video, .video-tile .video-mount video { width: 100%; height: auto; display: block; background: #000; }
  .video-mount { position: relative; }
  .label { position: absolute; bottom: .25rem; left: .25rem; background: #0009; color: #fff; padding: .15rem .35rem; border-radius: .25rem; font-size: .8rem; }
  .side { display: grid; gap: 1rem; align-content: start; }
  .panel { border: 1px solid #4443; border-radius: .5rem; padding: .5rem; display: grid; gap: .5rem; }
  .line { padding: .25rem .3rem; border-radius: .25rem; }
  .line:nth-child(odd) { background: #00000008; }
  .interim { font-style: italic; opacity: .8; }
  .time { margin-left: .35rem; opacity: .6; font-size: .75rem; }
  @media (max-width: 900px) {
    .grid { grid-template-columns: 1fr; }
  }
  ul { margin: 0; padding-left: 1rem; }
  li { margin: 0; }
  h3 { margin: .25rem 0; }
  h1 { font-size: 1rem; margin: 0; }
  a { text-decoration: none; }
  video { background: #000; }
  .container { padding-bottom: 2rem; }
  .video-mount:empty::before { content: 'Waiting for video…'; display: block; color: #999; padding: 2rem; text-align: center; }
  .video-mount:empty { background: #000; min-height: 160px; }
</style>
