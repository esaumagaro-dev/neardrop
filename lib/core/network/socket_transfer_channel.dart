import 'dart:async';
import 'dart:io';
import 'transfer_channel.dart';

/// Direct LAN transfer over a raw TCP socket (used when peers are on the
/// same Wi-Fi / Wi-Fi Direct group — the fast path).
class SocketTransferChannel implements TransferChannel {
  final String host;
  final int port;
  Socket? _socket;
  final _incomingController = StreamController<List<int>>.broadcast();

  SocketTransferChannel({required this.host, required this.port});

  @override
  Stream<List<int>> get incomingChunks => _incomingController.stream;

  @override
  Future<void> connect() async {
    _socket = await Socket.connect(host, port,
        timeout: const Duration(seconds: 5));
    _socket!.listen(
      (data) => _incomingController.add(data),
      onError: (e) => _incomingController.addError(e),
      onDone: () => _incomingController.close(),
    );
  }

  @override
  Future<void> sendChunk(List<int> bytes) async {
    _socket?.add(bytes);
    await _socket?.flush();
  }

  @override
  Future<void> close() async {
    await _socket?.close();
    await _incomingController.close();
  }
}

/// Server-side counterpart: listens for incoming P2P connections on the
/// NearDrop transfer port and hands each connection off as a channel.
class SocketTransferServer {
  ServerSocket? _server;
  final void Function(SocketTransferChannelInbound channel) onConnection;

  SocketTransferServer({required this.onConnection});

  Future<void> start({int port = 7531}) async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _server!.listen((socket) {
      onConnection(SocketTransferChannelInbound(socket));
    });
  }

  Future<void> stop() async {
    await _server?.close();
  }
}

/// Wraps an already-accepted [Socket] (server side) as a [TransferChannel].
class SocketTransferChannelInbound implements TransferChannel {
  final Socket _socket;
  final _incomingController = StreamController<List<int>>.broadcast();

  SocketTransferChannelInbound(this._socket) {
    _socket.listen(
      (data) => _incomingController.add(data),
      onError: (e) => _incomingController.addError(e),
      onDone: () => _incomingController.close(),
    );
  }

  @override
  Stream<List<int>> get incomingChunks => _incomingController.stream;

  @override
  Future<void> connect() async {} // already connected

  @override
  Future<void> sendChunk(List<int> bytes) async {
    _socket.add(bytes);
    await _socket.flush();
  }

  @override
  Future<void> close() async {
    await _socket.close();
    await _incomingController.close();
  }
}
