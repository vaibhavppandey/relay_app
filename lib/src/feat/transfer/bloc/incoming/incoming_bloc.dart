import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
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
  int _errorStreak = 0;

  Future<void> _onStartListening(
    StartListening event,
    Emitter<IncomingState> emit,
  ) async {
    final code = event.myCode.trim();
    if (code.isEmpty) {
      _lastKnown = const [];
      _errorStreak = 0;
      emit(const IncomingLoaded([]));
      return;
    }

    _errorStreak = 0;
    await _sub?.cancel();
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

  String _mapError(Object err) {
    final msg = err.toString();
    final lower = msg.toLowerCase();
    if (lower.contains('realtimesubscribeexception') ||
        lower.contains('timedout') ||
        lower.contains('time out')) {
      return 'Live sync is slow right now. Please check your connection.';
    }

    return 'Unable to sync transfers right now. Please try again.';
  }

  void _onIncomingChanged(_IncomingChanged event, Emitter<IncomingState> emit) {
    _errorStreak = 0;
    _lastKnown = event.lst;
    emit(IncomingLoaded(event.lst));
  }

  void _onIncomingErrored(_IncomingErrored event, Emitter<IncomingState> emit) {
    _errorStreak += 1;
    if (_errorStreak == 3) {
      emit(IncomingFailure(msg: _mapError(event.err), lst: _lastKnown));
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
