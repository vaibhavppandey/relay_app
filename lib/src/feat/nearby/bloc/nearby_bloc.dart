import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:nsd/nsd.dart';
import 'package:relay_app/src/feat/nearby/data/repo/nearby_repository.dart';

part 'nearby_event.dart';
part 'nearby_state.dart';

class NearbyBloc extends Bloc<NearbyEvent, NearbyState> {
  NearbyBloc({required NearbyRepository repo})
    : _repo = repo,
      super(const NearbyInitial()) {
    on<StartScanning>(_onStartScanning);
    on<StopScanning>(_onStopScanning);
  }

  final NearbyRepository _repo;

  Future<void> _onStartScanning(
    StartScanning event,
    Emitter<NearbyState> emit,
  ) async {
    await emit.forEach<List<Service>>(
      _repo.discover(),
      onData: (list) => NearbyScanning(list),
      onError: (error, stackTrace) =>
          const NearbyFailure('Unable to scan nearby devices.'),
    );
  }

  Future<void> _onStopScanning(
    StopScanning event,
    Emitter<NearbyState> emit,
  ) async {
    await _repo.stopDiscoveryScan();
  }
}
