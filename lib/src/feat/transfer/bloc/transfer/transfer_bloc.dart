import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:relay_app/src/core/util/user_friendly_error.dart';
import 'package:relay_app/src/core/util/recovery_queue.dart';
import 'package:relay_app/src/feat/transfer/data/model/transfer_model.dart';
import 'package:relay_app/src/feat/transfer/data/repo/transfer_repository.dart';

part 'transfer_event.dart';
part 'transfer_state.dart';

class TransferBloc extends Bloc<TransferEvent, TransferState> {
  final TransferRepository _transferRepository;
  CancelToken? _cancelToken;
  var _isDownloadTransfer = false;

  TransferBloc({required TransferRepository repository})
    : _transferRepository = repository,
      super(TransferInitial()) {
    on<SendRequested>(_onSendRequested);
    on<RecoveryRequested>(_onRecoveryRequested);
    on<DownloadRequested>(_onDownloadRequested);
    on<ProgressUpdated>(_onProgressUpdated);
    on<TransferCancelled>(_onTransferCancelled);
    on<TransferReset>(_onTransferReset);
  }

  Future<void> _onRecoveryRequested(
    RecoveryRequested event,
    Emitter<TransferState> emit,
  ) async {
    await _transferRepository.cleanupStaleTransfers();
    final list = await RecoveryQueue.getPendingTransfers();
    if (list.isEmpty) {
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
  }

  Future<void> _onSendRequested(
    SendRequested event,
    Emitter<TransferState> emit,
  ) async {
    emit(TransferLoading());
    _isDownloadTransfer = false;
    var hasError = false;
    for (final file in event.files) {
      final cancelToken = CancelToken();
      _cancelToken = cancelToken;

      try {
        await _transferRepository.send(
          file,
          event.rCode,
          cancelToken: cancelToken,
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
    emit(TransferLoading());
    _isDownloadTransfer = true;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    try {
      await _transferRepository.download(
        event.t,
        cancelToken: cancelToken,
        onProgress: (receivedBytes, totalBytes) =>
            add(ProgressUpdated(receivedBytes, totalBytes)),
      );
      emit(TransferSuccess());
    } catch (err) {
      if (err is DioException &&
          (err.type == DioExceptionType.cancel || CancelToken.isCancel(err))) {
        return;
      }
      emit(TransferFailure(userFriendlyErrorMessage(err)));
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
    }
  }

  void _onProgressUpdated(ProgressUpdated event, Emitter<TransferState> emit) {
    if (event.total <= 0) {
      return;
    }
    final pct = (event.current / event.total).clamp(0.0, 1.0).toDouble();
    emit(TransferInProgress(pct: pct, isDownload: _isDownloadTransfer));
  }

  void _onTransferCancelled(
    TransferCancelled event,
    Emitter<TransferState> emit,
  ) {
    _cancelToken?.cancel('Cancelled by user');
    _cancelToken = null;
    emit(TransferFailure('Transfer cancelled.'));
  }

  void _onTransferReset(TransferReset event, Emitter<TransferState> emit) {
    _cancelToken?.cancel();
    _cancelToken = null;
    emit(TransferInitial());
  }
}
