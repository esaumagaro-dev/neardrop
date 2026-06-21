/// Wire-level chunk header sent ahead of each encrypted file chunk so the
/// receiver knows how to reassemble the stream.
class FileChunkHeader {
  final String transferId;
  final String fileName;
  final int totalSizeBytes;
  final int chunkIndex;
  final int totalChunks;

  FileChunkHeader({
    required this.transferId,
    required this.fileName,
    required this.totalSizeBytes,
    required this.chunkIndex,
    required this.totalChunks,
  });

  Map<String, dynamic> toJson() => {
        'transferId': transferId,
        'fileName': fileName,
        'totalSizeBytes': totalSizeBytes,
        'chunkIndex': chunkIndex,
        'totalChunks': totalChunks,
      };

  factory FileChunkHeader.fromJson(Map<String, dynamic> json) =>
      FileChunkHeader(
        transferId: json['transferId'],
        fileName: json['fileName'],
        totalSizeBytes: json['totalSizeBytes'],
        chunkIndex: json['chunkIndex'],
        totalChunks: json['totalChunks'],
      );
}

class TransferProgress {
  final String transferId;
  final int bytesTransferred;
  final int totalBytes;

  TransferProgress({
    required this.transferId,
    required this.bytesTransferred,
    required this.totalBytes,
  });

  double get fraction => totalBytes == 0 ? 0 : bytesTransferred / totalBytes;
}
