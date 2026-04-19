class TransferData {
  const TransferData({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.storagePath,
    required this.fileName,
    required this.fileSize,
    required this.status,
    required this.progressBytes,
  });

  factory TransferData.fromJson(Map<String, dynamic> json) {
    return TransferData(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      recipientId: json['recipient_id'] as String,
      storagePath: json['storage_bucket_path'] as String,
      fileName: json['file_name'] as String,
      fileSize: (json['file_size'] as num).toInt(),
      status: json['status'] as String,
      progressBytes: (json['progress_bytes'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String senderId;
  final String recipientId;
  final String storagePath;
  final String fileName;
  final int fileSize;
  final String status;
  final int progressBytes;
}
