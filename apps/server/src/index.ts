import 'dotenv/config';
import express from 'express';
import http from 'http';
import cors from 'cors';
import { Server } from 'socket.io';
import { db } from './db/client.js';
import { transcripts } from './db/schema.js';
import { eq, desc } from 'drizzle-orm';
import type { JoinRoomPayload, SignalPayload, TranscriptPayload } from './types.js';

const app = express();
app.use(express.json());

const PORT = Number(process.env.PORT || 5174);
const CLIENT_ORIGIN = process.env.CLIENT_ORIGIN || 'http://localhost:5173';

app.use(cors({ origin: CLIENT_ORIGIN }));

// Basic health
app.get('/health', (_req, res) => res.json({ ok: true }));

// Fetch transcripts for a room
app.get('/api/rooms/:roomId/transcripts', async (req, res) => {
  const { roomId } = req.params;
  try {
    const rows = await db
      .select()
      .from(transcripts)
      .where(eq(transcripts.roomId, roomId))
      .orderBy(desc(transcripts.createdAt));
    res.json(rows);
  } catch (err) {
    console.error('Error fetching transcripts', err);
    res.status(500).json({ error: 'Failed to fetch transcripts' });
  }
});

const server = http.createServer(app);

const io = new Server(server, {
  cors: { origin: CLIENT_ORIGIN }
});

// Room state: roomId -> { socketId -> username }
const rooms = new Map<string, Map<string, string>>();

io.on('connection', (socket) => {
  let joinedRoom: string | null = null;
  let username: string | null = null;

  socket.on('join_room', (payload: JoinRoomPayload) => {
    joinedRoom = payload.roomId;
    username = payload.username;
    socket.join(payload.roomId);

    let room = rooms.get(payload.roomId);
    if (!room) {
      room = new Map();
      rooms.set(payload.roomId, room);
    }
    room.set(socket.id, payload.username);

    const users = Array.from(room.entries()).map(([id, name]) => ({ id, username: name }));
    io.to(payload.roomId).emit('room_users', users);
    socket.to(payload.roomId).emit('user_joined', { id: socket.id, username: payload.username });
  });

  socket.on('signal', (payload: SignalPayload) => {
    // Relay signaling data to the target peer
    io.to(payload.targetId).emit('signal', { sourceId: socket.id, data: payload.data });
  });

  socket.on('transcript', async (payload: TranscriptPayload) => {
    if (!payload?.roomId || !payload?.text || !payload?.username || !payload?.userId) return;
    try {
      await db.insert(transcripts).values({
        roomId: payload.roomId,
        userId: payload.userId,
        username: payload.username,
        content: payload.text,
      });
    } catch (err) {
      console.error('DB insert transcript error', err);
    }
    io.to(payload.roomId).emit('transcript', {
      id: Date.now(),
      roomId: payload.roomId,
      userId: payload.userId,
      username: payload.username,
      content: payload.text,
      createdAt: new Date().toISOString(),
    });
  });

  socket.on('disconnect', () => {
    if (joinedRoom) {
      const room = rooms.get(joinedRoom);
      if (room) {
        room.delete(socket.id);
        const users = Array.from(room.entries()).map(([id, name]) => ({ id, username: name }));
        io.to(joinedRoom).emit('room_users', users);
        socket.to(joinedRoom).emit('user_left', { id: socket.id, username });
        if (room.size === 0) rooms.delete(joinedRoom);
      }
    }
  });
});

server.listen(PORT, () => {
  console.log(`[server] listening on :${PORT}`);
});

