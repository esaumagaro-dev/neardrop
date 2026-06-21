import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'transfer_channel.dart';

/// Fallback path used when peers are on different networks. Uses a
/// WebRTC DataChannel; signaling (offer/answer/ICE exchange) goes through
/// the lightweight signaling server in /signaling_server — see
/// SignalingClient in lib/core/network/signaling_client.dart.
class WebRtcTransferChannel implements TransferChannel {
  final void Function(RTCSessionDescription) onLocalDescription;
  final void Function(RTCIceCandidate) onLocalIceCandidate;
  final bool isInitiator;

  RTCPeerConnection? _pc;
  RTCDataChannel? _dataChannel;
  final _incomingController = StreamController<List<int>>.broadcast();
  final _dataChannelReady = Completer<void>();

  WebRtcTransferChannel({
    required this.onLocalDescription,
    required this.onLocalIceCandidate,
    this.isInitiator = true,
  });

  @override
  Stream<List<int>> get incomingChunks => _incomingController.stream;

  @override
  Future<void> connect() async {
    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    _pc!.onIceCandidate = (candidate) => onLocalIceCandidate(candidate);

    if (isInitiator) {
      _dataChannel = await _pc!.createDataChannel(
        'neardrop-transfer',
        RTCDataChannelInit()
          ..ordered = true
          ..maxRetransmits = 30,
      );
      _bindDataChannel(_dataChannel!);

      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      onLocalDescription(offer);
    } else {
      _pc!.onDataChannel = (channel) {
        _dataChannel = channel;
        _bindDataChannel(channel);
      };
    }
  }

  void _bindDataChannel(RTCDataChannel channel) {
    channel.onMessage = (message) {
      if (message.isBinary) {
        _incomingController.add(message.binary);
      }
    };
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen &&
          !_dataChannelReady.isCompleted) {
        _dataChannelReady.complete();
      }
    };
  }

  /// Call once an offer is received (answerer side) or an answer is
  /// received (initiator side).
  Future<void> acceptRemoteDescription(RTCSessionDescription desc) async {
    await _pc?.setRemoteDescription(desc);
    if (!isInitiator && desc.type == 'offer') {
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      onLocalDescription(answer);
    }
  }

  Future<void> addRemoteIceCandidate(RTCIceCandidate candidate) async {
    await _pc?.addCandidate(candidate);
  }

  @override
  Future<void> sendChunk(List<int> bytes) async {
    if (!_dataChannelReady.isCompleted) await _dataChannelReady.future;
    await _dataChannel?.send(RTCDataChannelMessage.fromBinary(Uint8List.fromList(bytes)));
  }

  @override
  Future<void> close() async {
    await _dataChannel?.close();
    await _pc?.close();
    await _incomingController.close();
  }
}
