export type Peer = {
  id: string;
  pc: RTCPeerConnection;
};

export function createPeerConnection(iceServers?: RTCIceServer[]) {
  const config: RTCConfiguration = {
    iceServers: iceServers ?? [{ urls: ['stun:stun.l.google.com:19302'] }]
  };
  return new RTCPeerConnection(config);
}

