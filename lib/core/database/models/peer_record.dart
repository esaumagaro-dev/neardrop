import 'package:isar/isar.dart';

part 'peer_record.g.dart';

@collection
class PeerRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String peerId;

  late String name;
  late String platform;
  late String lastKnownIp;
  late DateTime lastConnected;
  bool trusted = false;
}
