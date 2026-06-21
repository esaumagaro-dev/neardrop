import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Thin client over a WebSocket connection to the NearDrop signaling
/// server (see /signaling_server). Used only for the relay path — local
/// P2P transfers never touch this.
class SignalingClient {
  final String serverUrl; // e.g. wss://signal.neardrop.app
  final String roomId; // shared pairing code between the two peers
  WebSocketChannel? _channel;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  SignalingClient({required this.serverUrl, required this.roomId});

  Future<void> connect() async {
    _channel = WebSocketChannel.connect(Uri.parse('$serverUrl?room=$roomId'));
    _channel!.stream.listen((raw) {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      _messageController.add(data);
    });
  }

  void send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  void sendOffer(Map<String, dynamic> sdp) =>
      send({'type': 'offer', 'sdp': sdp});

  void sendAnswer(Map<String, dynamic> sdp) =>
      send({'type': 'answer', 'sdp': sdp});

  void sendIceCandidate(Map<String, dynamic> candidate) =>
      send({'type': 'ice-candidate', 'candidate': candidate});

  Future<void> close() async {
    await _channel?.sink.close();
    await _messageController.close();
  }
}
