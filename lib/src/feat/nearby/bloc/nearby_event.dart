part of 'nearby_bloc.dart';

sealed class NearbyEvent extends Equatable {
  const NearbyEvent();

  @override
  List<Object?> get props => [];
}

final class StartScanning extends NearbyEvent {
  const StartScanning();
}

final class StopScanning extends NearbyEvent {
  const StopScanning();
}
