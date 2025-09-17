# Scribal

Zoom-like WebRTC conferencing with per-user speech-to-text transcription. Transcripts are broadcast in real-time and stored in Postgres via Drizzle for later retrieval.

Tech stack
- Frontend: SvelteKit (WebRTC, Web Speech API)
- Signaling: Socket.IO
- Backend: Node.js + Express + Socket.IO
- Database: Postgres
- ORM: Drizzle ORM

Architecture Flow
1. Users join via WebRTC peer connection (mesh).
2. Each client runs transcription on their own audio using Web Speech API.
3. Transcriptions are sent to the server with speaker identification.
4. Server stores and broadcasts transcriptions to all participants.
5. Real-time display of transcriptions with speaker labels in the UI.

Monorepo
- `apps/server`: Express + Socket.IO + Drizzle + Postgres
- `apps/web`: SvelteKit client app

Quick start
1. Create `.env` files as per `.env.example` in `apps/server` and `apps/web`.
2. Install deps: `npm install` (workspace root)
3. Generate/migrate DB: `npm run db:generate && npm run db:migrate`
4. Dev: `npm run dev` (runs server on `:5174` and web on `:5173` with proxy)

Notes
- Web Speech API is only available in supported browsers; a basic fallback logger is included.
- STUN server uses public Google STUN as default; replace with your own TURN for NAT traversal in production.

