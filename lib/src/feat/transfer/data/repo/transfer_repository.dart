import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:relay_app/src/core/error/exception.dart';
import 'package:relay_app/src/feat/transfer/data/model/transfer_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class TransferRepository {
  TransferRepository({
    required SupabaseClient supabase,
    required Dio dio,
    required Uuid uuid,
  }) : _supabase = supabase,
       _dio = dio,
       _uuid = uuid;

  final SupabaseClient _supabase;
  final Dio _dio;
  final Uuid _uuid;
  final Set<String> _done = {};

  Future<void> send(
    File file,
    String recipientCode, {
    CancelToken? cancelToken,
  }) async {
    final fileSize = await file.length();

    if (fileSize > 52428800) {
      throw const UploadFailedException('File exceeds 50MB limit.');
    }

    final recipientUser = await _supabase
        .from('users')
        .select('id')
        .eq('short_code', recipientCode)
        .maybeSingle();

    if (recipientUser == null) {
      throw const UploadFailedException('Invalid recipient code.');
    }

    final recipientId = recipientUser['id'] as String;

    final senderId = _supabase.auth.currentUser!.id;
    if (recipientId == senderId) {
      throw const UploadFailedException('Cannot send files to your own code.');
    }

    final transferId = _uuid.v4();
    final fileName = file.path.split('/').last;
    final storagePath = '$senderId/$transferId/$fileName';
    final expiresAt = DateTime.now().toUtc().add(const Duration(days: 1));

    try {
      await _supabase.from('transfers').insert({
        'id': transferId,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'storage_bucket_path': storagePath,
        'file_name': fileName,
        'file_size': fileSize,
        'status': 'pending',
        'progress_bytes': 0,
        'expires_at': expiresAt.toIso8601String(),
      });

      await _supabase
          .from('transfers')
          .update({'status': 'transferring'})
          .eq('id', transferId);

      final uploadUrl = await _supabase.storage
          .from('media')
          .createSignedUploadUrl(storagePath);
      var lastProgressPercent = -1;

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
                .eq('id', transferId),
          );
        },
      );

      await _supabase
          .from('transfers')
          .update({'status': 'completed', 'progress_bytes': fileSize})
          .eq('id', transferId);
    } catch (error) {
      try {
        await _supabase
            .from('transfers')
            .update({'status': 'failed'})
            .eq('id', transferId);
      } catch (_) {}

      throw UploadFailedException(error.toString());
    }
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
              .where((transfer) => !_done.contains(transfer.id))
              .toList(),
        );
  }

  Future<void> download(
    TransferData transfer, {
    CancelToken? cancelToken,
    void Function(int, int)? onProgress,
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
        onReceiveProgress: onProgress,
      );

      _done.add(transfer.id);

      await _supabase
          .from('transfers')
          .update({'status': 'completed', 'progress_bytes': transfer.fileSize})
          .eq('id', transfer.id);
    } catch (error) {
      throw DownloadFailedException(error.toString());
    }
  }
}
