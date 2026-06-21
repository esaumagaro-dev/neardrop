import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Handles per-session AES-256-GCM encryption for the transfer stream.
/// A fresh symmetric key is generated per transfer session and exchanged
/// via the secure channel established during QR pairing / handshake.
class EncryptionService {
  final _algorithm = AesGcm.with256bits();

  Future<SecretKey> generateSessionKey() => _algorithm.newSecretKey();

  Future<String> exportKey(SecretKey key) async {
    final bytes = await key.extractBytes();
    return base64Encode(bytes);
  }

  SecretKey importKey(String encoded) {
    final bytes = base64Decode(encoded);
    return SecretKey(bytes);
  }

  /// Encrypts a chunk. Returns nonce + ciphertext + MAC concatenated,
  /// ready to send over the wire.
  Future<Uint8List> encryptChunk({
    required Uint8List plaintext,
    required SecretKey key,
  }) async {
    final box = await _algorithm.encrypt(plaintext, secretKey: key);
    return Uint8List.fromList([
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  /// Decrypts a chunk produced by [encryptChunk]. Nonce is 12 bytes,
  /// MAC (Poly1305 tag) is 16 bytes; everything in between is ciphertext.
  Future<Uint8List> decryptChunk({
    required Uint8List data,
    required SecretKey key,
  }) async {
    final nonce = data.sublist(0, 12);
    final mac = data.sublist(data.length - 16);
    final cipherText = data.sublist(12, data.length - 16);

    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
    final clear = await _algorithm.decrypt(box, secretKey: key);
    return Uint8List.fromList(clear);
  }
}
