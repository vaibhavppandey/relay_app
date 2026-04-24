import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:nsd/nsd.dart';
import 'package:relay_app/src/core/util/user_friendly_error.dart';
import 'package:relay_app/src/core/util/recovery_queue.dart';
import 'package:relay_app/src/feat/nearby/data/repo/nearby_repository.dart';
import 'package:relay_app/src/feat/transfer/data/model/transfer_model.dart';
import 'package:relay_app/src/feat/transfer/data/repo/transfer_repository.dart';

part 'transfer_event.dart';
part 'transfer_state.dart';

class TransferBloc extends Bloc<TransferEvent, TransferState> {
  final TransferRepository _transferRepository;
  final NearbyRepository _nearbyRepository;
  CancelToken? _cancelToken;
  String? _activeDownloadId;

  TransferBloc({
    required TransferRepository repository,
    required NearbyRepository nearbyRepository,
  }) : _transferRepository = repository,
       _nearbyRepository = nearbyRepository,
       super(TransferInitial()) {
    on<SendRequested>(_onSendRequested);
    on<SendNearbyRequested>(_onSendNearbyRequested);
    on<RecoveryRequested>(_onRecoveryRequested);
    on<DownloadRequested>(_onDownloadRequested);
    on<TransferCancelled>(_onTransferCancelled);
    on<TransferReset>(_onTransferReset);
  }

  Future<void> _onSendNearbyRequested(
    SendNearbyRequested event,
    Emitter<TransferState> emit,
  ) async {
    var hasError = false;
    for (final file in event.files) {
      emit(TransferLoading(isDownload: false, activeId: file.path));

      try {
        final ok = await _nearbyRepository.sendFile(
          file,
          event.target,
          onProgress: (val) => emit(
            TransferInProgress(
              pct: val,
              isDownload: false,
              activeId: file.path,
            ),
          ),
        );
        if (!ok) {
          emit(
            const TransferFailure(
              'Nearby TCP transfer failed. Make sure both devices are on the same network.',
            ),
          );
          hasError = true;
          continue;
        }
      } catch (err) {
        emit(TransferFailure(userFriendlyErrorMessage(err)));
        hasError = true;
        continue;
      }
    }

    if (!hasError) {
      emit(TransferSuccess());
    }
  }

  Future<void> _onRecoveryRequested(
    RecoveryRequested event,
    Emitter<TransferState> emit,
  ) async {
    await _transferRepository.cleanupStaleTransfers();
    final list = await RecoveryQueue.getPendingTransfers();
    if (list.isEmpty) {
      final pendingDownloads = await RecoveryQueue.getPendingDownloads();
      for (final id in pendingDownloads) {
        final t = await _transferRepository.getTransferById(id);
        if (t == null || t.status == 'downloaded') {
          await RecoveryQueue.removeDownload(id);
          continue;
        }
        if (t.status == 'completed') {
          add(DownloadRequested(t: t));
        }
      }
      return;
    }

    for (final item in list) {
      final path = item['path'];
      final code = item['code'];
      if (path == null || code == null) {
        continue;
      }

      final file = File(path);
      if (file.existsSync()) {
        add(SendRequested(files: [file], rCode: code));
      } else {
        await RecoveryQueue.removeTransfer(path);
      }
    }

    final pendingDownloads = await RecoveryQueue.getPendingDownloads();
    for (final id in pendingDownloads) {
      final t = await _transferRepository.getTransferById(id);
      if (t == null || t.status == 'downloaded') {
        await RecoveryQueue.removeDownload(id);
        continue;
      }
      if (t.status == 'completed') {
        add(DownloadRequested(t: t));
      }
    }
  }

  Future<void> _onSendRequested(
    SendRequested event,
    Emitter<TransferState> emit,
  ) async {
    var hasError = false;
    for (final file in event.files) {
      emit(TransferLoading(isDownload: false, activeId: file.path));
      final cancelToken = CancelToken();
      _cancelToken = cancelToken;

      try {
        await _transferRepository.send(
          file,
          event.rCode,
          cancelToken: cancelToken,
          onProgress: (val) => emit(
            TransferInProgress(
              pct: val,
              isDownload: false,
              activeId: file.path,
            ),
          ),
        );
      } catch (err) {
        if (err is DioException &&
            (err.type == DioExceptionType.cancel ||
                CancelToken.isCancel(err))) {
          return;
        }
        emit(TransferFailure(userFriendlyErrorMessage(err)));
        hasError = true;
        continue;
      } finally {
        if (identical(_cancelToken, cancelToken)) {
          _cancelToken = null;
        }
      }
    }

    if (!hasError) {
      emit(TransferSuccess());
    }
  }

  Future<void> _onDownloadRequested(
    DownloadRequested event,
    Emitter<TransferState> emit,
  ) async {
    _activeDownloadId = event.t.id;
    await RecoveryQueue.addDownload(event.t.id);
    emit(TransferLoading(isDownload: true, activeId: event.t.id));
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    try {
      await _transferRepository.download(
        event.t,
        cancelToken: cancelToken,
        onProgress: (val) => emit(
          TransferInProgress(pct: val, isDownload: true, activeId: event.t.id),
        ),
      );
      await RecoveryQueue.removeDownload(event.t.id);
      _activeDownloadId = null;
      emit(TransferSuccess());
    } catch (err) {
      if (err is DioException &&
          (err.type == DioExceptionType.cancel || CancelToken.isCancel(err))) {
        return;
      }
      _activeDownloadId = null;
      emit(TransferFailure(userFriendlyErrorMessage(err)));
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
    }
  }

  void _onTransferCancelled(
    TransferCancelled event,
    Emitter<TransferState> emit,
  ) {
    _cancelToken?.cancel('Cancelled by user');
    _cancelToken = null;
    final id = _activeDownloadId;
    if (id != null) {
      unawaited(RecoveryQueue.removeDownload(id));
      _activeDownloadId = null;
    }
    emit(TransferFailure('Transfer cancelled.'));
  }

  void _onTransferReset(TransferReset event, Emitter<TransferState> emit) {
    _cancelToken?.cancel();
    _cancelToken = null;
    _activeDownloadId = null;
    emit(TransferInitial());
  }
}
