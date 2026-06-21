import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/transfer_channel.dart';
import '../../../core/security/encryption_service.dart';
import '../domain/file_chunk.dart';

const int kChunkSizeBytes = 256 * 1024; // 256 KB per chunk

/// Frame types multiplexed over the same encrypted channel:
///  - "header": JSON FileChunkHeader, sent once before each file's bytes
///  - raw encrypted bytes immediately after a header belong to that chunk
///
/// In production each frame would be length-prefixed; this version relies
/// on the channel preserving message boundaries (true for both the
/// SocketTransferChannel using one socket per chunk-burst and the WebRTC
/// DataChannel, which is message-oriented).
class TransferEngine {
  final TransferChannel channel;
  final EncryptionService encryption;
  final SecretKey sessionKey;

  final _progressController = StreamController<TransferProgress>.broadcast();
  Stream<TransferProgress> get progressStream => _progressController.stream;

  final _completedController = StreamController<String>.broadcast();
  Stream<String> get fileReceivedStream => _completedController.stream;

  StreamSubscription? _incomingSub;
  FileChunkHeader? _pendingHeader;
  IOSink? _receiveSink;
  File? _receiveFile;
  int _receivedBytes = 0;

  TransferEngine({
    required this.channel,
    required this.encryption,
    required this.sessionKey,
  }) {
    _incomingSub = channel.incomingChunks.listen(_handleIncoming);
  }

  /// Sends [file] to the connected peer, chunked and AES-256-GCM encrypted.
  Future<void> sendFile(File file) async {
    final transferId = const Uuid().v4();
    final fileName = file.uri.pathSegments.last;
    final totalSize = await file.length();
    final totalChunks = (totalSize / kChunkSizeBytes).ceil();

    final randomAccess = await file.open();
    try {
      for (var i = 0; i < totalChunks; i++) {
        final bytes = await randomAccess.read(kChunkSizeBytes);

        final header = FileChunkHeader(
          transferId: transferId,
          fileName: fileName,
          totalSizeBytes: totalSize,
          chunkIndex: i,
          totalChunks: totalChunks,
        );

        // Header frame (plaintext JSON is fine here; the body is what's
        // sensitive and that's always encrypted).
        await channel.sendChunk(
          utf8.encode(jsonEncode({'frame': 'header', ...header.toJson()})),
        );

        final encrypted = await encryption.encryptChunk(
          plaintext: Uint8List.fromList(bytes),
          key: sessionKey,
        );
        await channel.sendChunk(encrypted);

        _progressController.add(TransferProgress(
          transferId: transferId,
          bytesTransferred: (i + 1) * kChunkSizeBytes,
          totalBytes: totalSize,
        ));
      }
    } finally {
      await randomAccess.close();
    }
  }

  Future<void> _handleIncoming(List<int> data) async {
    // Try to interpret as a header frame first.
    if (_pendingHeader == null) {
      try {
        final asString = utf8.decode(data);
        final map = jsonDecode(asString) as Map<String, dynamic>;
        if (map['frame'] == 'header') {
          _pendingHeader = FileChunkHeader.fromJson(map);
          if (_pendingHeader!.chunkIndex == 0) {
            final dir = Directory.systemTemp;
            _receiveFile = File('${dir.path}/${_pendingHeader!.fileName}');
            _receiveSink = _receiveFile!.openWrite();
            _receivedBytes = 0;
          }
          return;
        }
      } catch (_) {
        // Not JSON / not a header — fall through and treat as chunk body.
      }
    }

    if (_pendingHeader == null) return; // out-of-order/garbage frame

    final decrypted = await encryption.decryptChunk(
      data: Uint8List.fromList(data),
      key: sessionKey,
    );
    _receiveSink?.add(decrypted);
    _receivedBytes += decrypted.length;

    _progressController.add(TransferProgress(
      transferId: _pendingHeader!.transferId,
      bytesTransferred: _receivedBytes,
      totalBytes: _pendingHeader!.totalSizeBytes,
    ));

    final isLastChunk =
        _pendingHeader!.chunkIndex == _pendingHeader!.totalChunks - 1;
    if (isLastChunk) {
      await _receiveSink?.flush();
      await _receiveSink?.close();
      _completedController.add(_receiveFile!.path);
      _pendingHeader = null;
      _receiveSink = null;
      _receiveFile = null;
    }
  }

  Future<void> dispose() async {
    await _incomingSub?.cancel();
    await _progressController.close();
    await _completedController.close();
  }
}
