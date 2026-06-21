import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/models/transfer_record.dart';
import '../providers/transfer_provider.dart';

class TransferHistoryScreen extends ConsumerWidget {
  const TransferHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(transferHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer History')),
      body: historyAsync.when(
        data: (records) => records.isEmpty
            ? const Center(child: Text('No transfers yet'))
            : ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, i) {
                  final r = records[i];
                  return ListTile(
                    leading: Icon(
                      r.direction == TransferDirection.sent
                          ? Icons.upload_rounded
                          : Icons.download_rounded,
                    ),
                    title: Text(r.fileName),
                    subtitle: Text(
                      '${r.peerName} • ${_formatBytes(r.fileSizeBytes)} • ${r.networkModeUsed}',
                    ),
                    trailing: _statusIcon(r.status),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading history: $e')),
      ),
    );
  }

  Widget _statusIcon(TransferStatus status) {
    switch (status) {
      case TransferStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case TransferStatus.failed:
        return const Icon(Icons.error, color: Colors.red);
      case TransferStatus.inProgress:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      default:
        return const Icon(Icons.schedule, color: Colors.grey);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
