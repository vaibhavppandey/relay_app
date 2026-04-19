part of 'incoming_bloc.dart';

sealed class IncomingEvent extends Equatable {
  const IncomingEvent();

  @override
  List<Object> get props => [];
}

final class StartListening extends IncomingEvent {
  const StartListening({required this.myCode});

  final String myCode;

  @override
  List<Object> get props => [myCode];
}

final class _IncomingChanged extends IncomingEvent {
  const _IncomingChanged(this.lst);

  final List<TransferData> lst;

  @override
  List<Object> get props => [lst];
}

final class _IncomingErrored extends IncomingEvent {
  const _IncomingErrored(this.err);

  final Object err;

  @override
  List<Object> get props => [err];
}
