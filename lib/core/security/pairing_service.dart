import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'encryption_service.dart';

/// Generates and parses the QR pairing payload exchanged when two devices
/// establish a NearLink connection. The payload carries enough info to
/// open a direct channel plus a bootstrap key used to encrypt the actual
/// per-session AES key handshake.
class PairingPayload {
  final String deviceId;
  final String deviceName;
  final String ip;
  final int port;
  final String publicKeyBase64;

  PairingPayload({
    required this.deviceId,
    required this.deviceName,
    required this.ip,
    required this.port,
    required this.publicKeyBase64,
  });

  String toQrData() => jsonEncode({
        'id': deviceId,
        'name': deviceName,
        'ip': ip,
        'port': port,
        'pk': publicKeyBase64,
      });

  factory PairingPayload.fromQrData(String data) {
    final map = jsonDecode(data) as Map<String, dynamic>;
    return PairingPayload(
      deviceId: map['id'],
      deviceName: map['name'],
      ip: map['ip'],
      port: map['port'],
      publicKeyBase64: map['pk'],
    );
  }
}

/// Uses X25519 ECDH to derive a shared secret from the QR-exchanged
/// public keys, then HKDF's that into the AES-256 session key used by
/// [EncryptionService]. This means the AES key itself is never sent over
/// the wire or embedded in the QR code.
class PairingService {
  final _keyExchangeAlgorithm = X25519();

  Future<SimpleKeyPair> generateKeyPair() =>
      _keyExchangeAlgorithm.newKeyPair();

  Future<String> publicKeyToBase64(SimpleKeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  Future<SecretKey> deriveSessionKey({
    required SimpleKeyPair localKeyPair,
    required String remotePublicKeyBase64,
  }) async {
    final remotePublicKey = SimplePublicKey(
      base64Decode(remotePublicKeyBase64),
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _keyExchangeAlgorithm.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: remotePublicKey,
    );

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: sharedSecret,
      info: utf8.encode('neardrop-session-key'),
    );
  }
}
