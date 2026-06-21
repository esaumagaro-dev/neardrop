import 'package:isar/isar.dart';

part 'transfer_record.g.dart';

enum TransferDirection { sent, received }

enum TransferStatus { pending, inProgress, completed, failed, cancelled }

@collection
class TransferRecord {
  Id id = Isar.autoIncrement;

  late String fileName;
  late int fileSizeBytes;
  late String peerName;
  late String peerId;

  @enumerated
  late TransferDirection direction;

  @enumerated
  late TransferStatus status;

  late DateTime startedAt;
  DateTime? completedAt;

  @Index()
  late String networkModeUsed; // "localP2P" or "relay"
}
