part of 'transfer_bloc.dart';

sealed class TransferEvent extends Equatable {
  const TransferEvent();

  @override
  List<Object> get props => [];
}

final class SendRequested extends TransferEvent {
  const SendRequested({required this.files, required this.rCode});

  final List<File> files;
  final String rCode;

  @override
  List<Object> get props => [rCode, ...files.map((file) => file.path)];
}

final class RecoveryRequested extends TransferEvent {
  const RecoveryRequested();
}

final class DownloadRequested extends TransferEvent {
  const DownloadRequested({required this.t});

  final TransferData t;

  @override
  List<Object> get props => [t.id];
}

final class TransferCancelled extends TransferEvent {
  const TransferCancelled();
}

final class TransferReset extends TransferEvent {
  const TransferReset();
}

final class ProgressUpdated extends TransferEvent {
  const ProgressUpdated(this.current, this.total);

  final int current;
  final int total;

  @override
  List<Object> get props => [current, total];
}
