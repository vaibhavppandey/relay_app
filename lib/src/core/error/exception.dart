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
