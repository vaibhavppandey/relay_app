part of 'transfer_bloc.dart';

sealed class TransferState extends Equatable {
  const TransferState();

  @override
  List<Object?> get props => [];
}

final class TransferInitial extends TransferState {}

final class TransferLoading extends TransferState {
  const TransferLoading({required this.isDownload, this.activeId});

  final bool isDownload;
  final String? activeId;

  @override
  List<Object?> get props => [isDownload, activeId];
}

final class TransferInProgress extends TransferState {
  const TransferInProgress({
    required this.pct,
    required this.isDownload,
    this.activeId,
  });

  final double pct;
  final bool isDownload;
  final String? activeId;

  @override
  List<Object?> get props => [pct, isDownload, activeId];
}

final class TransferSuccess extends TransferState {}

final class TransferFailure extends TransferState {
  const TransferFailure(this.msg);

  final String msg;

  @override
  List<Object?> get props => [msg];
}
