part of 'nearby_bloc.dart';

sealed class NearbyState extends Equatable {
  const NearbyState();

  @override
  List<Object?> get props => [];
}

final class NearbyInitial extends NearbyState {
  const NearbyInitial();
}

final class NearbySearching extends NearbyState {
  const NearbySearching();
}

final class NearbyScanning extends NearbyState {
  const NearbyScanning(this.devices);

  final List<Service> devices;

  @override
  List<Object?> get props => [devices];
}

final class NearbyFailure extends NearbyState {
  const NearbyFailure(this.msg);

  final String msg;

  @override
  List<Object?> get props => [msg];
}
