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

  function mountVideo(node: HTMLDivElement, video?: HTMLVideoElement) {
    if (!video) return;

    const place = (el: HTMLVideoElement) => {
      node.replaceChildren(el);
    };

    place(video);

    return {
      update(newVideo?: HTMLVideoElement) {
        if (newVideo && newVideo !== video) {
          video = newVideo;
          place(newVideo);
        }
      },
      destroy() {
        if (video && video.parentElement === node) {
          node.removeChild(video);
        }
      }
    };
  }

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

<div class="call-page">
  <div class="call-backdrop"></div>
  <div class="call-blob call-blob--left"></div>
  <div class="call-blob call-blob--right"></div>

  <div class="call-shell">
    <header class="call-header">
      <a class="call-back" href="/">
        <span aria-hidden="true">←</span>
        <span>Home</span>
      </a>

      <div class="call-room">
        <span class="call-room__label">Current room</span>
        <h1 class="call-room__title">{roomId}</h1>
      </div>

      <div class="call-user">
        <span class="call-user__label">Signed in as</span>
        <span class="call-user__name">{username}</span>
      </div>
    </header>

    <section class="call-content">
      <div class="call-videos">
        <div class="video-card video-card--local">
          <div class="video-frame">
            <video bind:this={myVideoEl} autoplay playsinline muted></video>
          </div>
          <span class="video-label">You • {username}</span>
        </div>

        {#each remoteVideos as rv (rv.id)}
          <div class="video-card">
            <div class="video-frame" use:mountVideo={rv.el}></div>
            <span class="video-label">{users.find((u) => u.id === rv.id)?.username || 'Guest'}</span>
          </div>
        {/each}
      </div>

      <aside class="call-sidebar">
        <div class="glass-panel transcript-panel">
          <h3>Live Transcript</h3>
          {#if interimText}
            <div class="transcript-interim">{username}: {interimText} …</div>
          {/if}
          <div class="transcript-feed">
            {#each transcripts as t (t.id)}
              <div class="transcript-line">
                <span class="speaker">{t.username}</span>
                <span class="text">{t.content}</span>
                {#if t.createdAt}
                  <span class="timestamp">{new Date(t.createdAt).toLocaleTimeString()}</span>
                {/if}
              </div>
            {/each}
          </div>
        </div>

        <div class="glass-panel participants-panel">
          <h3>Participants ({users.length})</h3>
          <ul class="participants-list">
            {#each users as u (u.id)}
              <li class:is-self={u.id === socket.id}>{u.username}</li>
            {/each}
          </ul>
        </div>
      </aside>
    </section>
  </div>
</div>

<style>
  .call-page {
    position: relative;
    min-height: 100svh;
    padding: clamp(2.5rem, 6vw, 4rem) clamp(1.5rem, 5vw, 3rem);
    display: flex;
    justify-content: center;
    background: #020617;
    color: #f8fafc;
    overflow: hidden;
  }

  .call-backdrop {
    position: absolute;
    inset: 0;
    background: radial-gradient(circle at top, rgba(76, 29, 149, 0.18), transparent 55%),
      radial-gradient(circle at bottom right, rgba(56, 189, 248, 0.18), transparent 60%),
      linear-gradient(135deg, #020617 0%, #0f172a 40%, #020617 100%);
    z-index: 0;
  }

  .call-blob {
    position: absolute;
    border-radius: 999px;
    filter: blur(90px);
    opacity: 0.8;
    pointer-events: none;
    z-index: 0;
  }

  .call-blob--left {
    width: 24rem;
    height: 24rem;
    top: -7rem;
    left: -9rem;
    background: rgba(168, 85, 247, 0.45);
  }

  .call-blob--right {
    width: 30rem;
    height: 30rem;
    right: -12rem;
    top: 55%;
    transform: translateY(-50%);
    background: rgba(56, 189, 248, 0.35);
  }

  .call-shell {
    position: relative;
    z-index: 1;
    width: min(100%, 1180px);
    display: flex;
    flex-direction: column;
    gap: clamp(1.25rem, 3vw, 1.85rem);
  }

  .call-header {
    display: flex;
    align-items: center;
    gap: clamp(1rem, 3vw, 1.75rem);
    padding: clamp(1.1rem, 3vw, 1.6rem) clamp(1.25rem, 3vw, 2rem);
    border-radius: 26px;
    background: linear-gradient(135deg, rgba(255, 255, 255, 0.14), rgba(255, 255, 255, 0.05));
    border: 1px solid rgba(255, 255, 255, 0.16);
    backdrop-filter: blur(28px);
    box-shadow: 0 28px 60px -30px rgba(59, 130, 246, 0.55);
  }

  .call-back {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.5rem 0.9rem;
    border-radius: 14px;
    border: 1px solid rgba(255, 255, 255, 0.22);
    background: rgba(15, 23, 42, 0.35);
    color: rgba(226, 232, 240, 0.92);
    font-size: 0.9rem;
    font-weight: 500;
    text-decoration: none;
    transition: background 0.2s ease, transform 0.2s ease, border-color 0.2s ease;
  }

  .call-back:hover {
    background: rgba(59, 130, 246, 0.2);
    border-color: rgba(148, 163, 184, 0.5);
    transform: translateY(-1px);
  }

  .call-room {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  .call-room__label {
    font-size: 0.72rem;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: rgba(148, 163, 184, 0.72);
  }

  .call-room__title {
    margin: 0;
    font-size: clamp(1.4rem, 4vw, 1.8rem);
    font-weight: 700;
    color: #f1f5f9;
  }

  .call-user {
    margin-left: auto;
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    padding: 0.6rem 0.95rem;
    border-radius: 18px;
    background: rgba(15, 23, 42, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.16);
    text-align: right;
  }

  .call-user__label {
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: rgba(148, 163, 184, 0.72);
  }

  .call-user__name {
    font-size: 1rem;
    font-weight: 600;
    color: #e0f2fe;
  }

  .call-content {
    display: grid;
    gap: clamp(1.1rem, 3vw, 1.8rem);
    grid-template-columns: minmax(0, 2fr) minmax(0, 1fr);
    align-items: start;
  }

  .call-videos {
    display: grid;
    gap: 1rem;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  }

  .video-card {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    padding: 1rem;
    border-radius: 22px;
    background: linear-gradient(135deg, rgba(255, 255, 255, 0.18), rgba(255, 255, 255, 0.08));
    border: 1px solid rgba(255, 255, 255, 0.16);
    box-shadow: 0 22px 45px -28px rgba(59, 130, 246, 0.55);
    backdrop-filter: blur(24px);
  }

  .video-card--local {
    box-shadow: 0 24px 55px -24px rgba(129, 140, 248, 0.6);
  }

  .video-frame {
    position: relative;
    width: 100%;
    aspect-ratio: 16 / 9;
    border-radius: 18px;
    overflow: hidden;
    border: 1px solid rgba(255, 255, 255, 0.16);
    background: rgba(2, 6, 23, 0.85);
    display: flex;
    align-items: center;
    justify-content: center;
    color: rgba(226, 232, 240, 0.75);
    font-size: 0.9rem;
  }

  .video-frame video {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
    background: #000;
  }

  .video-frame:empty::before {
    content: 'Waiting for video…';
  }

  .video-label {
    font-size: 0.9rem;
    color: rgba(226, 232, 240, 0.88);
  }

  .video-card--local .video-label {
    color: rgba(248, 250, 252, 0.95);
    font-weight: 600;
  }

  .call-sidebar {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .glass-panel {
    border-radius: 24px;
    padding: 1.25rem;
    background: linear-gradient(135deg, rgba(15, 23, 42, 0.72), rgba(30, 41, 59, 0.6));
    border: 1px solid rgba(255, 255, 255, 0.12);
    backdrop-filter: blur(26px);
    box-shadow: 0 22px 45px -30px rgba(30, 64, 175, 0.45);
  }

  .glass-panel h3 {
    margin: 0 0 0.9rem;
    font-size: 1.05rem;
    font-weight: 600;
    color: #e2e8f0;
  }

  .transcript-panel {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .transcript-interim {
    font-style: italic;
    color: rgba(196, 181, 253, 0.9);
    background: rgba(76, 29, 149, 0.25);
    border: 1px dashed rgba(129, 140, 248, 0.55);
    padding: 0.65rem 0.8rem;
    border-radius: 14px;
  }

  .transcript-feed {
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
    max-height: 22rem;
    overflow-y: auto;
    padding-right: 0.2rem;
  }

  .transcript-line {
    display: grid;
    gap: 0.4rem;
    grid-template-columns: auto 1fr auto;
    align-items: baseline;
    background: rgba(15, 23, 42, 0.45);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 14px;
    padding: 0.55rem 0.75rem;
    color: #e2e8f0;
  }

  .transcript-line .speaker {
    font-weight: 600;
    color: #c4b5fd;
  }

  .transcript-line .text {
    font-size: 0.92rem;
    padding-right: 0.4rem;
  }

  .transcript-line .timestamp {
    font-size: 0.75rem;
    color: rgba(148, 163, 184, 0.75);
    white-space: nowrap;
  }

  .participants-panel {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .participants-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .participants-list li {
    padding: 0.55rem 0.8rem;
    border-radius: 14px;
    background: rgba(15, 23, 42, 0.45);
    border: 1px solid rgba(255, 255, 255, 0.12);
    color: rgba(226, 232, 240, 0.88);
    font-size: 0.92rem;
  }

  .participants-list li.is-self {
    background: rgba(129, 140, 248, 0.35);
    border-color: rgba(129, 140, 248, 0.55);
    color: #f8fafc;
    font-weight: 600;
  }

  .transcript-feed::-webkit-scrollbar,
  .participants-list::-webkit-scrollbar {
    width: 6px;
  }

  .transcript-feed::-webkit-scrollbar-thumb,
  .participants-list::-webkit-scrollbar-thumb {
    background: rgba(148, 163, 184, 0.4);
    border-radius: 999px;
  }

  @media (max-width: 1100px) {
    .call-content {
      grid-template-columns: minmax(0, 1fr);
    }
  }

  @media (max-width: 640px) {
    .call-header {
      flex-direction: column;
      align-items: stretch;
      text-align: center;
    }

    .call-user {
      margin-left: 0;
      text-align: center;
    }

    .call-back {
      align-self: flex-start;
    }
  }

  @media (max-width: 520px) {
    .call-page {
      padding: 2rem 1.25rem 2.5rem;
    }

    .call-videos {
      grid-template-columns: 1fr;
    }
  }
</style>
