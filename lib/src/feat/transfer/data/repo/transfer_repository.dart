import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:relay_app/pigeons/generated/media_saver.g.dart';
import 'package:relay_app/src/core/error/exception.dart';
import 'package:relay_app/src/core/native/bg_service.dart';
import 'package:relay_app/src/core/util/mime_type.dart';
import 'package:relay_app/src/core/util/recovery_queue.dart';
import 'package:relay_app/src/feat/transfer/data/model/transfer_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class TransferRepository {
  TransferRepository({
    required SupabaseClient supabase,
    required Dio dio,
    required Uuid uuid,
    BgServiceManager? bg,
    Future<void> Function()? onDeferredSyncRequested,
  }) : _supabase = supabase,
       _dio = dio,
       _uuid = uuid,
       _bg = bg,
       _onDeferredSyncRequested = onDeferredSyncRequested;

  final SupabaseClient _supabase;
  final Dio _dio;
  final Uuid _uuid;
  final BgServiceManager? _bg;
  final Future<void> Function()? _onDeferredSyncRequested;
  final MediaSaverApi _native = MediaSaverApi();
  final Set<String> _done = {};
  static const Duration _retryPollInterval = Duration(seconds: 2);
  static const Duration _internetCheckTimeout = Duration(seconds: 2);

  Future<void> send(
    File file,
    String recipientCode, {
    CancelToken? cancelToken,
    void Function(double)? onProgress,
    bool waitForNetwork = true,
  }) async {
    final fileSize = await file.length();
    final fileName = file.path.split('/').last;
    String? transferId;

    try {
      if (fileSize > 52428800) {
        throw const UploadFailedException('File exceeds 50MB limit.');
      }

      await _bg?.startTransfer(fileName);
      await RecoveryQueue.addTransfer(file.path, recipientCode);
      unawaited(_onDeferredSyncRequested?.call());

      final recipientUser = await _withNetworkRetry(
        () => _supabase
            .from('users')
            .select('id')
            .eq('short_code', recipientCode)
            .maybeSingle(),
        cancelToken: cancelToken,
        waitForNetwork: waitForNetwork,
      );

      if (recipientUser == null) {
        throw const UploadFailedException('Invalid recipient code.');
      }

      final recipientId = recipientUser['id'] as String;
      final senderId = _supabase.auth.currentUser!.id;
      if (recipientId == senderId) {
        throw const UploadFailedException(
          'Cannot send files to your own code.',
        );
      }

      transferId = _uuid.v4();
      final storagePath = '$senderId/$transferId/$fileName';
      final expiresAt = DateTime.now().toUtc().add(const Duration(days: 1));

      await _withNetworkRetry(
        () => _supabase.from('transfers').insert({
          'id': transferId,
          'sender_id': senderId,
          'recipient_id': recipientId,
          'storage_bucket_path': storagePath,
          'file_name': fileName,
          'file_size': fileSize,
          'status': 'pending',
          'progress_bytes': 0,
          'expires_at': expiresAt.toIso8601String(),
        }),
        cancelToken: cancelToken,
        waitForNetwork: waitForNetwork,
      );

      await _withNetworkRetry(
        () => _supabase
            .from('transfers')
            .update({'status': 'transferring'})
            .eq('id', transferId!),
        cancelToken: cancelToken,
        waitForNetwork: waitForNetwork,
      );

      var lastProgressPercent = -1;

      await _withNetworkRetry(
        () async {
          final uploadUrl = await _supabase.storage
              .from('media')
              .createSignedUploadUrl(storagePath);
          await _dio.put(
            uploadUrl.signedUrl,
            data: file.openRead(),
            cancelToken: cancelToken,
            options: Options(
              headers: {
                'content-type': 'application/octet-stream',
                'content-length': fileSize.toString(),
              },
              responseType: ResponseType.plain,
            ),
            onSendProgress: (sentBytes, totalBytes) {
              if (totalBytes > 0 && onProgress != null) {
                onProgress(sentBytes / totalBytes);
              }
              if (totalBytes <= 0) return;

              final progressPercent = ((sentBytes / totalBytes) * 100).floor();
              if (progressPercent == lastProgressPercent ||
                  (progressPercent - lastProgressPercent) < 5 &&
                      sentBytes != totalBytes) {
                return;
              }

              lastProgressPercent = progressPercent;
              unawaited(
                _supabase
                    .from('transfers')
                    .update({'progress_bytes': sentBytes})
                    .eq('id', transferId!)
                    .catchError((_) {}),
              );
            },
          );
        },
        cancelToken: cancelToken,
        waitForNetwork: waitForNetwork,
      );

      await _withNetworkRetry(
        () => _supabase
            .from('transfers')
            .update({'status': 'completed', 'progress_bytes': fileSize})
            .eq('id', transferId!),
        cancelToken: cancelToken,
        waitForNetwork: waitForNetwork,
      );

      await RecoveryQueue.removeTransfer(file.path);
      await _bg?.stopTransfer();
    } catch (error) {
      await _bg?.stopTransfer();
      if (_isCancelledError(error)) {
        rethrow;
      }

      final retryable = _isRetryableNetworkError(error);

      if (transferId != null && !retryable) {
        try {
          await _supabase
              .from('transfers')
              .update({'status': 'failed'})
              .eq('id', transferId);
        } catch (_) {}
      }

      if (retryable) {
        unawaited(_onDeferredSyncRequested?.call());
      } else {
        await RecoveryQueue.removeTransfer(file.path);
      }

      throw UploadFailedException(error.toString());
    }
  }

  Future<T> _withNetworkRetry<T>(
    Future<T> Function() action, {
    CancelToken? cancelToken,
    bool waitForNetwork = true,
  }) async {
    while (true) {
      _throwIfCancelled(cancelToken);
      try {
        return await action();
      } catch (error) {
        if (_isCancelledError(error)) {
          rethrow;
        }
        if (!_isRetryableNetworkError(error)) {
          rethrow;
        }

        if (!waitForNetwork) {
          rethrow;
        }

        await _waitForInternet(cancelToken: cancelToken);
      }
    }
  }

  Future<void> _waitForInternet({CancelToken? cancelToken}) async {
    while (true) {
      _throwIfCancelled(cancelToken);
      final isOnline = await _hasInternet();
      if (isOnline) {
        return;
      }
      await Future<void>.delayed(_retryPollInterval);
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'one.one.one.one',
      ).timeout(_internetCheckTimeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _throwIfCancelled(CancelToken? cancelToken) {
    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: RequestOptions(path: '/transfers/upload'),
        type: DioExceptionType.cancel,
        error: 'Cancelled by user',
      );
    }
  }

  bool _isCancelledError(Object error) {
    return error is DioException &&
        (error.type == DioExceptionType.cancel || CancelToken.isCancel(error));
  }

  bool _isRetryableNetworkError(Object error) {
    if (error is SocketException) {
      return true;
    }

    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.unknown;
    }

    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network') ||
        text.contains('connection reset') ||
        text.contains('connection refused') ||
        text.contains('timed out') ||
        text.contains('timeout');
  }

  Future<void> cleanupStaleTransfers() async {
    final sId = _supabase.auth.currentUser!.id;
    await _supabase.from('transfers').delete().eq('sender_id', sId).inFilter(
      'status',
      ['pending', 'transferring'],
    );
  }

  Future<TransferData?> getTransferById(String id) async {
    final rec = await _supabase
        .from('transfers')
        .select('*')
        .eq('id', id)
        .maybeSingle();

    if (rec == null) {
      return null;
    }

    return TransferData.fromJson(Map<String, dynamic>.from(rec as Map));
  }

  Stream<List<TransferData>> listenIncoming(String recipientCode) async* {
    final recipientUser = await _supabase
        .from('users')
        .select('id')
        .eq('short_code', recipientCode)
        .maybeSingle();

    if (recipientUser == null) {
      yield const [];
      return;
    }

    final recipientId = recipientUser['id'] as String;

    yield* _supabase
        .from('transfers')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', recipientId)
        .map(
          (records) => records
              .map(
                (record) => TransferData.fromJson(
                  Map<String, dynamic>.from(record as Map),
                ),
              )
              .where(
                (t) =>
                    t.status == 'pending' ||
                    t.status == 'transferring' ||
                    t.status == 'completed' ||
                    t.status == 'downloaded',
              )
              .toList(),
        );
  }

  Future<void> download(
    TransferData transfer, {
    CancelToken? cancelToken,
    void Function(double)? onProgress,
  }) async {
    if (_done.contains(transfer.id)) {
      return;
    }

    if (transfer.status != 'completed') {
      throw const TransferNotCompletedException('Transfer is not ready yet.');
    }

    try {
      final signedUrl = await _supabase.storage
          .from('media')
          .createSignedUrl(transfer.storagePath, 3600);
      final documentsDir = await getApplicationDocumentsDirectory();
      final savePath = '${documentsDir.path}/${transfer.fileName}';

      await _dio.download(
        signedUrl,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (count, total) {
          if (total > 0 && onProgress != null) {
            onProgress(count / total);
          }
        },
      );

      final mimeType = inferMimeType(transfer.fileName);
      final saved = await _native.saveFile(
        savePath,
        transfer.fileName,
        mimeType,
      );
      if (!saved) {
        throw const DownloadFailedException(
          'Could not save file on this device.',
        );
      }

      _done.add(transfer.id);

      await _supabase.storage.from('media').remove([transfer.storagePath]);

      await _supabase
          .from('transfers')
          .update({'status': 'downloaded', 'progress_bytes': transfer.fileSize})
          .eq('id', transfer.id);
    } catch (error) {
      throw DownloadFailedException(error.toString());
    }
  }
}
