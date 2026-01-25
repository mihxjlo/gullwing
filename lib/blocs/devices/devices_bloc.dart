import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/connected_device.dart';
import '../../services/device_repository.dart';
import 'devices_event.dart';
import 'devices_state.dart';

/// Devices BLoC
/// Manages connected devices list and status
class DevicesBloc extends Bloc<DevicesEvent, DevicesState> {
  final DeviceRepository _repository;
  StreamSubscription<List<ConnectedDevice>>? _devicesSubscription;
  Timer? _heartbeatTimer;
  String? _currentDeviceId;
  
  DevicesBloc({
    DeviceRepository? repository,
  }) : _repository = repository ?? DeviceRepository(),
       super(DevicesInitial()) {
    on<DevicesLoadStarted>(_onLoadStarted);
    on<DevicesUpdated>(_onUpdated);
    on<DeviceRegistered>(_onRegistered);
    on<DeviceStatusUpdated>(_onStatusUpdated);
  }
  
  Future<void> _onLoadStarted(
    DevicesLoadStarted event,
    Emitter<DevicesState> emit,
  ) async {
    emit(DevicesLoading());
    
    try {
      // Subscribe to real-time device updates
      _devicesSubscription?.cancel();
      _devicesSubscription = _repository.watchDevices().listen(
        (devices) => add(DevicesUpdated(devices)),
        onError: (error) => emit(DevicesError(error.toString())),
      );
    } catch (e) {
      emit(DevicesError(e.toString()));
    }
  }
  
  void _onUpdated(
    DevicesUpdated event,
    Emitter<DevicesState> emit,
  ) {
    emit(DevicesLoaded(
      devices: event.devices,
      currentDeviceId: _currentDeviceId,
    ));
  }
  
  Future<void> _onRegistered(
    DeviceRegistered event,
    Emitter<DevicesState> emit,
  ) async {
    try {
      await _repository.registerDevice(event.device);
      _currentDeviceId = event.device.id;
      
      // Start heartbeat timer
      _startHeartbeat();
      
      final currentState = state;
      if (currentState is DevicesLoaded) {
        emit(currentState.copyWith(currentDeviceId: event.device.id));
      }
    } catch (e) {
      emit(DevicesError('Failed to register device: $e'));
    }
  }
  
  Future<void> _onStatusUpdated(
    DeviceStatusUpdated event,
    Emitter<DevicesState> emit,
  ) async {
    try {
      await _repository.updateOnlineStatus(event.deviceId, event.isOnline);
    } catch (e) {
      // Handle silently
    }
  }
  
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_currentDeviceId != null) {
          _repository.updateHeartbeat(_currentDeviceId!);
        }
      },
    );
  }
  
  @override
  Future<void> close() {
    _devicesSubscription?.cancel();
    _heartbeatTimer?.cancel();
    
    // Mark device as offline when closing
    if (_currentDeviceId != null) {
      _repository.updateOnlineStatus(_currentDeviceId!, false);
    }
    
    return super.close();
  }
}
