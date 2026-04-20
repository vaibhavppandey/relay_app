import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:relay_app/src/core/util/user_friendly_error.dart';
import 'package:relay_app/src/feat/transfer/data/model/transfer_model.dart';
import 'package:relay_app/src/feat/transfer/data/repo/transfer_repository.dart';

part 'incoming_event.dart';
part 'incoming_state.dart';

class IncomingBloc extends Bloc<IncomingEvent, IncomingState> {
  IncomingBloc({required TransferRepository repo})
    : _repo = repo,
      super(IncomingInitial()) {
    on<StartListening>(_onStartListening);
    on<_IncomingChanged>(_onIncomingChanged);
    on<_IncomingErrored>(_onIncomingErrored);
  }

  final TransferRepository _repo;
  StreamSubscription<List<TransferData>>? _sub;
  List<TransferData> _lastKnown = const [];

  Future<void> _onStartListening(
    StartListening event,
    Emitter<IncomingState> emit,
  ) async {
    final code = event.myCode.trim();
    if (code.isEmpty) {
      _lastKnown = const [];
      emit(const IncomingLoaded([]));
      return;
    }

    await _sub?.cancel();
    emit(IncomingLoading());
    _sub = _repo
        .listenIncoming(code)
        .listen(
          (lst) {
            if (!isClosed) {
              add(_IncomingChanged(lst));
            }
          },
          onError: (err) {
            if (!isClosed) {
              add(_IncomingErrored(err));
            }
          },
        );
  }

  void _onIncomingChanged(_IncomingChanged event, Emitter<IncomingState> emit) {
    _lastKnown = event.lst;
    emit(IncomingLoaded(event.lst));
  }

  void _onIncomingErrored(_IncomingErrored event, Emitter<IncomingState> emit) {
    emit(
      IncomingFailure(
        msg: userFriendlyErrorMessage(
          event.err,
          fallback:
              'Live sync is slow right now. Please check your connection.',
        ),
        lst: _lastKnown,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
