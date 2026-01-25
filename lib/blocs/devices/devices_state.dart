import 'package:equatable/equatable.dart';
import '../../models/connected_device.dart';

/// Device States
abstract class DevicesState extends Equatable {
  const DevicesState();
  
  @override
  List<Object?> get props => [];
}

/// Initial state
class DevicesInitial extends DevicesState {}

/// Loading devices
class DevicesLoading extends DevicesState {}

/// Devices loaded
class DevicesLoaded extends DevicesState {
  final List<ConnectedDevice> devices;
  final String? currentDeviceId;
  
  const DevicesLoaded({
    required this.devices,
    this.currentDeviceId,
  });
  
  int get activeCount => devices.where(
    (d) => d.status == DeviceStatus.active
  ).length;
  
  @override
  List<Object?> get props => [devices, currentDeviceId];
  
  DevicesLoaded copyWith({
    List<ConnectedDevice>? devices,
    String? currentDeviceId,
  }) {
    return DevicesLoaded(
      devices: devices ?? this.devices,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
    );
  }
}

/// Error state
class DevicesError extends DevicesState {
  final String message;
  
  const DevicesError(this.message);
  
  @override
  List<Object?> get props => [message];
}
