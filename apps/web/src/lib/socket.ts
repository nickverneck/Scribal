import { io, Socket } from 'socket.io-client';

export function createSocket(serverUrl: string): Socket {
  return io(serverUrl, { transports: ['websocket'] });
}

