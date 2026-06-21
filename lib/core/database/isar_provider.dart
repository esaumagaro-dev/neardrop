import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'models/peer_record.dart';
import 'models/transfer_record.dart';

final isarProvider = FutureProvider<Isar>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return Isar.open(
    [PeerRecordSchema, TransferRecordSchema],
    directory: dir.path,
    name: 'neardrop_db',
  );
});
