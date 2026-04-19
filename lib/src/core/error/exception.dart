class ShortCodeCollisionException implements Exception {
  final String message;
  ShortCodeCollisionException(this.message);
}

class NetworkOfflineException implements Exception {
  final String message;
  NetworkOfflineException([this.message = 'No internet connection.']);
}

class StorageQuotaExceededException implements Exception {
  final String message;
  StorageQuotaExceededException([
    this.message = 'Relay server is currently at capacity.',
  ]);
}

class UploadFailedException implements Exception {
  const UploadFailedException(this.msg);
  final String msg;

  @override
  String toString() => msg;
}

class TransferNotCompletedException implements Exception {
  const TransferNotCompletedException(this.msg);
  final String msg;

  @override
  String toString() => msg;
}

class DownloadFailedException implements Exception {
  const DownloadFailedException(this.msg);
  final String msg;

  @override
  String toString() => msg;
}
