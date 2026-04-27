import 'dart:async';

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
    on<_DiscoverySnapshotChanged>(_onDiscoverySnapshotChanged);
    on<_DiscoveryGraceElapsed>(_onDiscoveryGraceElapsed);
    on<_DiscoveryFailed>(_onDiscoveryFailed);
  }

  static const Duration _emptySearchGrace = Duration(seconds: 3);

  final NearbyRepository _repo;
  StreamSubscription<List<Service>>? _discoverySub;
  Timer? _emptySearchTimer;
  int _activeScanId = 0;
  bool _isSettled = false;
  List<Service> _lastEmittedDevices = const [];

  Future<void> _onStartScanning(
    StartScanning event,
    Emitter<NearbyState> emit,
  ) async {
    await _stopScanInternal();

    final scanId = ++_activeScanId;
    _isSettled = false;
    _lastEmittedDevices = const [];
    emit(const NearbySearching());

    _emptySearchTimer = Timer(_emptySearchGrace, () {
      if (!isClosed) {
        add(_DiscoveryGraceElapsed(scanId));
      }
    });

    try {
      _discoverySub = _repo.discover().listen(
        (services) {
          if (!isClosed) {
            add(_DiscoverySnapshotChanged(scanId, services));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!isClosed) {
            add(_DiscoveryFailed(scanId, error));
          }
        },
      );
    } catch (error) {
      if (!isClosed) {
        add(_DiscoveryFailed(scanId, error));
      }
    }
  }

  Future<void> _onStopScanning(
    StopScanning event,
    Emitter<NearbyState> emit,
  ) async {
    _activeScanId++;
    await _stopScanInternal();
    _isSettled = false;
    _lastEmittedDevices = const [];
    emit(const NearbyInitial());
  }

  void _onDiscoverySnapshotChanged(
    _DiscoverySnapshotChanged event,
    Emitter<NearbyState> emit,
  ) {
    if (event.scanId != _activeScanId) {
      return;
    }

    final devices = _normalizeServices(event.devices);
    if (devices.isNotEmpty) {
      _settleScan();
      _emitIfChanged(devices, emit);
      return;
    }

    if (!_isSettled) {
      return;
    }

    _emitIfChanged(devices, emit);
  }

  void _onDiscoveryGraceElapsed(
    _DiscoveryGraceElapsed event,
    Emitter<NearbyState> emit,
  ) {
    if (event.scanId != _activeScanId || _isSettled) {
      return;
    }

    _settleScan();
    _emitIfChanged(const [], emit);
  }

  void _onDiscoveryFailed(_DiscoveryFailed event, Emitter<NearbyState> emit) {
    if (event.scanId != _activeScanId) {
      return;
    }

    _settleScan();
    emit(const NearbyFailure('Unable to scan nearby devices.'));
  }

  void _emitIfChanged(List<Service> devices, Emitter<NearbyState> emit) {
    if (_isSameServiceList(_lastEmittedDevices, devices) &&
        state is NearbyScanning) {
      return;
    }

    _lastEmittedDevices = devices;
    emit(NearbyScanning(devices));
  }

  void _settleScan() {
    _isSettled = true;
    _cancelEmptySearchTimer();
  }

  Future<void> _stopScanInternal() async {
    _cancelEmptySearchTimer();

    final sub = _discoverySub;
    _discoverySub = null;
    await sub?.cancel();

    await _repo.stopDiscoveryScan();
  }

  void _cancelEmptySearchTimer() {
    final timer = _emptySearchTimer;
    _emptySearchTimer = null;
    timer?.cancel();
  }

  List<Service> _normalizeServices(List<Service> services) {
    final seen = <String>{};
    final normalized = <Service>[];

    for (final service in services) {
      final sig = _serviceSignature(service);
      if (seen.add(sig)) {
        normalized.add(service);
      }
    }

    normalized.sort(
      (a, b) =>
          (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()),
    );

    return List<Service>.unmodifiable(normalized);
  }

  bool _isSameServiceList(List<Service> a, List<Service> b) {
    if (identical(a, b)) {
      return true;
    }

    if (a.length != b.length) {
      return false;
    }

    for (var i = 0; i < a.length; i++) {
      if (_serviceSignature(a[i]) != _serviceSignature(b[i])) {
        return false;
      }
    }

    return true;
  }

  String _serviceSignature(Service service) {
    return '${service.name ?? ''}|${service.type}|${service.host ?? ''}|${service.port ?? 0}';
  }

  @override
  Future<void> close() async {
    _activeScanId++;
    await _stopScanInternal();
    return super.close();
  }
}
