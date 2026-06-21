import 'dart:io';
import 'transfer_channel.dart';
import 'socket_transfer_channel.dart';
import 'webrtc_transfer_channel.dart';

enum NetworkMode { localP2P, relay }

/// Decides, per-transfer, whether to use the fast local socket path or
/// fall back to the WebRTC relay — this is the "Smart Switch" from the
/// blueprint.
class SmartSwitch {
  /// Returns true if [peerIp] looks reachable on the local subnet.
  Future<bool> _isOnLocalNetwork(String peerIp, int peerPort) async {
    try {
      final socket = await Socket.connect(
        peerIp,
        peerPort,
        timeout: const Duration(milliseconds: 800),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<TransferChannel> openChannel({
    required String peerIp,
    required int peerPort,
    required void Function(NetworkMode mode) onModeSelected,
    void Function(dynamic localDescription)? onWebRtcOffer,
    void Function(dynamic localCandidate)? onWebRtcCandidate,
  }) async {
    final local = await _isOnLocalNetwork(peerIp, peerPort);

    if (local) {
      onModeSelected(NetworkMode.localP2P);
      final channel = SocketTransferChannel(host: peerIp, port: peerPort);
      await channel.connect();
      return channel;
    } else {
      onModeSelected(NetworkMode.relay);
      final channel = WebRtcTransferChannel(
        onLocalDescription: (desc) => onWebRtcOffer?.call(desc),
        onLocalIceCandidate: (cand) => onWebRtcCandidate?.call(cand),
      );
      await channel.connect();
      return channel;
    }
  }
}
