import 'package:relay_app/src/feat/transfer/bloc/incoming/incoming_bloc.dart';
import 'package:relay_app/src/feat/transfer/data/model/transfer_model.dart';

extension IncomingStateView on IncomingState {
  bool get isLoading => this is IncomingInitial || this is IncomingLoading;

  List<TransferData>? get transfersOrNull {
    if (this is IncomingLoaded) {
      return (this as IncomingLoaded).lst;
    }
    if (this is IncomingFailure) {
      return (this as IncomingFailure).lst;
    }
    return null;
  }
}
