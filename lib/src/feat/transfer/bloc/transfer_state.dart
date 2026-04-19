part of 'transfer_bloc.dart';

sealed class TransferState extends Equatable {
  const TransferState();

  @override
  List<Object> get props => [];
}

final class TransferInitial extends TransferState {}

final class TransferLoading extends TransferState {}

final class TransferInProgress extends TransferState {
  const TransferInProgress({required this.pct, required this.isDownload});

  final double pct;
  final bool isDownload;

  @override
  List<Object> get props => [pct, isDownload];
}

final class TransferIncoming extends TransferState {
  const TransferIncoming(this.list);

  final List<TransferData> list;

  @override
  List<Object> get props => [list];
}

final class TransferSuccess extends TransferState {}

final class TransferFailure extends TransferState {
  const TransferFailure(this.msg);

  final String msg;

  @override
  List<Object> get props => [msg];
}
