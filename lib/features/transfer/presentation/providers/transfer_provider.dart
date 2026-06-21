import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/database/models/transfer_record.dart';
import '../../../../core/network/smart_switch.dart';
import '../../../../core/security/encryption_service.dart';
import '../../data/transfer_engine.dart';
import '../../../discovery/domain/peer.dart';

final smartSwitchProvider = Provider((ref) => SmartSwitch());
final encryptionServiceProvider = Provider((ref) => EncryptionService());

/// Starts a send: opens a channel to [peer] via the Smart Switch, derives
/// a fresh session key, builds a TransferEngine, sends the file, and logs
/// the result to Isar transfer history.
class TransferRepository {
  final Ref ref;
  TransferRepository(this.ref);

  Future<void> sendFileToPeer({
    required Peer peer,
    required File file,
  }) async {
    final smartSwitch = ref.read(smartSwitchProvider);
    final encryption = ref.read(encryptionServiceProvider);
    NetworkMode? modeUsed;

    final channel = await smartSwitch.openChannel(
      peerIp: peer.ip,
      peerPort: peer.port,
      onModeSelected: (mode) => modeUsed = mode,
    );

    // In production the session key comes from the NearLink/X25519
    // handshake; for a one-off file send without an active NearLink
    // session, a fresh random key is generated and exchanged over the
    // same (already-authenticated) channel as the first frame.
    final sessionKey = await encryption.generateSessionKey();

    final engine = TransferEngine(
      channel: channel,
      encryption: encryption,
      sessionKey: sessionKey,
    );

    final isar = await ref.read(isarProvider.future);
    final record = TransferRecord()
      ..fileName = file.uri.pathSegments.last
      ..fileSizeBytes = await file.length()
      ..peerName = peer.name
      ..peerId = peer.id
      ..direction = TransferDirection.sent
      ..status = TransferStatus.inProgress
      ..startedAt = DateTime.now()
      ..networkModeUsed = (modeUsed ?? NetworkMode.localP2P).name;

    await isar.writeTxn(() => isar.transferRecords.put(record));

    try {
      await engine.sendFile(file);
      record
        ..status = TransferStatus.completed
        ..completedAt = DateTime.now();
    } catch (_) {
      record.status = TransferStatus.failed;
    } finally {
      await isar.writeTxn(() => isar.transferRecords.put(record));
      await engine.dispose();
      await channel.close();
    }
  }
}

final transferRepositoryProvider = Provider((ref) => TransferRepository(ref));

final transferHistoryProvider = FutureProvider<List<TransferRecord>>((ref) async {
  final isar = await ref.watch(isarProvider.future);
  return isar.transferRecords.where().sortByStartedAtDesc().findAll();
});
