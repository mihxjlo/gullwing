import 'package:equatable/equatable.dart';
import '../../models/connected_device.dart';

/// Device Events
abstract class DevicesEvent extends Equatable {
  const DevicesEvent();
  
  @override
  List<Object?> get props => [];
}

/// Start loading devices
class DevicesLoadStarted extends DevicesEvent {}

/// Devices updated from Firestore
class DevicesUpdated extends DevicesEvent {
  final List<ConnectedDevice> devices;
  
  const DevicesUpdated(this.devices);
  
  @override
  List<Object?> get props => [devices];
}

/// Register current device
class DeviceRegistered extends DevicesEvent {
  final ConnectedDevice device;
  
  const DeviceRegistered(this.device);
  
  @override
  List<Object?> get props => [device];
}

/// Update device status
class DeviceStatusUpdated extends DevicesEvent {
  final String deviceId;
  final bool isOnline;
  
  const DeviceStatusUpdated({
    required this.deviceId,
    required this.isOnline,
  });
  
  @override
  List<Object?> get props => [deviceId, isOnline];
}
