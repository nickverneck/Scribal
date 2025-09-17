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
3. Generate/migrate DB once (optional): `npm run db:generate && npm run db:migrate`
4. Dev: `npm run dev` (server auto-waits for Postgres and runs migrations, server on `:5174`, web on `:5173`)

Notes
- Web Speech API is only available in supported browsers; a basic fallback logger is included.
- STUN server uses public Google STUN as default; replace with your own TURN for NAT traversal in production.

Docker (Postgres only)
- Start DB: `docker compose up -d db`
- Optional pgAdmin: `docker compose up -d pgadmin` then visit `http://localhost:5050` (admin@example.com / admin1234)
- Connection string (server `.env`): `DATABASE_URL=postgres://scribal:scribal@localhost:5432/scribal`
- Stop DB: `docker compose down`
- Wipe volumes: `docker compose down -v` (destructive)

Auto-migrations in dev
- `npm run dev` for the server will:
  - wait for Postgres (retry up to ~30s)
  - run migrations from `apps/server/drizzle/`
  - start Socket.IO + Express

Docker: full stack (dev)
- Build and run web + server + db: `docker compose up --build`
- Open: `http://localhost:5173` (frontend), backend at `http://localhost:5174`
- Live reload: source folders are mounted into containers; changes reflect automatically
- Stop: `docker compose down`

Notes
- Frontend dev server binds to `0.0.0.0` inside container and is published to host `:5173`.
- Backend dev server runs migrations at start and binds to `0.0.0.0` on `:5174`.
- Inside Docker network, the server reaches Postgres via `db:5432`; the browser reaches the server via `http://localhost:5174`.
