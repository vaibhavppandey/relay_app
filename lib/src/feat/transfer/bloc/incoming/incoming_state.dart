part of 'incoming_bloc.dart';

sealed class IncomingState extends Equatable {
  const IncomingState();

  @override
  List<Object> get props => [];
}

final class IncomingInitial extends IncomingState {}

final class IncomingLoading extends IncomingState {}

final class IncomingLoaded extends IncomingState {
  const IncomingLoaded(this.lst);

  final List<TransferData> lst;

  @override
  List<Object> get props => [lst];
}

final class IncomingFailure extends IncomingState {
  const IncomingFailure({required this.msg, required this.lst});

  final String msg;
  final List<TransferData> lst;

  @override
  List<Object> get props => [msg, lst];
}
