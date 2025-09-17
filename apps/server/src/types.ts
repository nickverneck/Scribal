export type JoinRoomPayload = {
  roomId: string;
  username: string;
};

export type SignalPayload = {
  targetId: string;
  data: any; // SDP or ICE
};

export type TranscriptPayload = {
  roomId: string;
  userId: string;
  username: string;
  text: string;
  timestamp?: number;
};

