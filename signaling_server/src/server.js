import { WebSocketServer } from 'ws';
import { createServer } from 'http';

const PORT = process.env.PORT || 8080;

// room id -> Set of sockets (NearDrop pairs exactly 2 peers per room,
// identified by the pairing code shared via QR code).
const rooms = new Map();

const httpServer = createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', rooms: rooms.size }));
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ server: httpServer });

wss.on('connection', (socket, req) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const roomId = url.searchParams.get('room');

  if (!roomId) {
    socket.close(4000, 'Missing room id');
    return;
  }

  if (!rooms.has(roomId)) {
    rooms.set(roomId, new Set());
  }
  const room = rooms.get(roomId);

  if (room.size >= 2) {
    socket.close(4001, 'Room full');
    return;
  }

  room.add(socket);
  console.log(`[signaling] peer joined room=${roomId} size=${room.size}`);

  socket.on('message', (raw) => {
    // Relay verbatim to the other peer in the room (offer / answer /
    // ice-candidate messages). The server never inspects or stores SDP
    // content beyond forwarding it.
    for (const peer of room) {
      if (peer !== socket && peer.readyState === peer.OPEN) {
        peer.send(raw.toString());
      }
    }
  });

  socket.on('close', () => {
    room.delete(socket);
    console.log(`[signaling] peer left room=${roomId} size=${room.size}`);
    if (room.size === 0) {
      rooms.delete(roomId);
    }
  });

  socket.on('error', (err) => {
    console.error(`[signaling] socket error in room=${roomId}:`, err.message);
  });
});

httpServer.listen(PORT, () => {
  console.log(`NearDrop signaling server listening on :${PORT}`);
});
