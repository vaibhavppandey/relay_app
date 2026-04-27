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

final class _DiscoverySnapshotChanged extends NearbyEvent {
  const _DiscoverySnapshotChanged(this.scanId, this.devices);

  final int scanId;
  final List<Service> devices;

  @override
  List<Object?> get props => [scanId, devices];
}

final class _DiscoveryGraceElapsed extends NearbyEvent {
  const _DiscoveryGraceElapsed(this.scanId);

  final int scanId;

  @override
  List<Object?> get props => [scanId];
}

final class _DiscoveryFailed extends NearbyEvent {
  const _DiscoveryFailed(this.scanId, this.error);

  final int scanId;
  final Object error;

  @override
  List<Object?> get props => [scanId, error];
}
