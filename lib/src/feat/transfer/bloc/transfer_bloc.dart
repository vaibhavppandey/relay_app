import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:relay_app/src/feat/transfer/data/repo/transfer_repository.dart';

abstract class TransferEvent extends Equatable {
  const TransferEvent();

  @override
  List<Object?> get props => [];
}

abstract class TransferState extends Equatable {
  const TransferState();

  @override
  List<Object?> get props => [];
}

final class TransferInitial extends TransferState {
  const TransferInitial();
}

class TransferBloc extends Bloc<TransferEvent, TransferState> {
  TransferBloc({required TransferRepository repository})
    : _repository = repository,
      super(const TransferInitial());

  final TransferRepository _repository;

  String get repositoryName => _repository.runtimeType.toString();
}
