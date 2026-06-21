import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../../core/network/transfer_channel.dart';
import '../../../core/security/encryption_service.dart';

/// Watches the local system clipboard and pushes changes to the paired
/// peer over an already-open NearLink [TransferChannel], encrypted with
/// the session's AES key. Also applies incoming clipboard updates from
/// the peer to the local clipboard.
///
/// Message framing on the wire (after decryption):
///   { "type": "clipboard", "text": "<content>" }
class ClipboardSyncService {
  final TransferChannel channel;
  final EncryptionService encryption;
  final SecretKey sessionKey;

  Timer? _pollTimer;
  String? _lastSeenText;
  StreamSubscription? _incomingSub;

  ClipboardSyncService({
    required this.channel,
    required this.encryption,
    required this.sessionKey,
  });

  void start({Duration pollInterval = const Duration(seconds: 1)}) {
    _pollTimer = Timer.periodic(pollInterval, (_) => _checkLocalClipboard());
    _incomingSub = channel.incomingChunks.listen(_handleIncoming);
  }

  Future<void> _checkLocalClipboard() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;

    final reader = await clipboard.read();
    if (!reader.canProvide(Formats.plainText)) return;

    final text = await reader.readValue(Formats.plainText);
    if (text == null || text == _lastSeenText) return;

    _lastSeenText = text;
    await _sendClipboardUpdate(text);
  }

  Future<void> _sendClipboardUpdate(String text) async {
    final payload = jsonEncode({'type': 'clipboard', 'text': text});
    final plaintext = Uint8List.fromList(utf8.encode(payload));
    final encrypted =
        await encryption.encryptChunk(plaintext: plaintext, key: sessionKey);
    await channel.sendChunk(encrypted);
  }

  Future<void> _handleIncoming(List<int> data) async {
    try {
      final decrypted = await encryption.decryptChunk(
        data: Uint8List.fromList(data),
        key: sessionKey,
      );
      final map = jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;
      if (map['type'] != 'clipboard') return;

      final text = map['text'] as String;
      _lastSeenText = text; // avoid echoing it straight back
      final item = DataWriterItem();
      item.add(Formats.plainText(text));
      await SystemClipboard.instance?.write([item]);
    } catch (_) {
      // Not a clipboard message (could be a file chunk) — ignore here;
      // the transfer engine handles those frames separately.
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _incomingSub?.cancel();
  }
}
