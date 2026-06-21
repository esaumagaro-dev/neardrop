import 'package:cryptography/cryptography.dart';
import '../../../core/network/transfer_channel.dart';
import '../../../core/network/smart_switch.dart';
import '../../../core/security/encryption_service.dart';
import '../../../core/security/pairing_service.dart';
import 'clipboard_sync_service.dart';
import 'notification_mirror_service.dart';

enum LinkStatus { disconnected, pairing, connected, error }

/// Orchestrates a full NearLink session: opens a channel via the
/// SmartSwitch, performs the X25519 handshake to derive a session key,
/// then starts clipboard sync and notification mirroring on top of the
/// same encrypted channel.
class NearLinkSession {
  final SmartSwitch smartSwitch = SmartSwitch();
  final EncryptionService encryption = EncryptionService();
  final PairingService pairing = PairingService();

  TransferChannel? _channel;
  ClipboardSyncService? _clipboardSync;
  NotificationMirrorService? _notificationMirror;
  SecretKey? _sessionKey;

  LinkStatus status = LinkStatus.disconnected;

  Future<void> connect({
    required String peerIp,
    required int peerPort,
    required SimpleKeyPair localKeyPair,
    required String remotePublicKeyBase64,
    required bool isDesktop,
  }) async {
    status = LinkStatus.pairing;

    _sessionKey = await pairing.deriveSessionKey(
      localKeyPair: localKeyPair,
      remotePublicKeyBase64: remotePublicKeyBase64,
    );

    _channel = await smartSwitch.openChannel(
      peerIp: peerIp,
      peerPort: peerPort,
      onModeSelected: (_) {},
    );

    _clipboardSync = ClipboardSyncService(
      channel: _channel!,
      encryption: encryption,
      sessionKey: _sessionKey!,
    )..start();

    _notificationMirror = NotificationMirrorService(transferChannel: _channel!);
    if (isDesktop) {
      _notificationMirror!.startDesktopListener();
    } else {
      await _notificationMirror!.requestAndroidPermission();
    }

    status = LinkStatus.connected;
  }

  Future<void> disconnect() async {
    _clipboardSync?.dispose();
    _notificationMirror?.dispose();
    await _channel?.close();
    status = LinkStatus.disconnected;
  }
}
