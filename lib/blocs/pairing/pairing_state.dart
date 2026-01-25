import 'package:equatable/equatable.dart';
import '../../models/pairing_session.dart';
import '../../models/connected_device.dart';

/// Base class for all pairing states
abstract class PairingState extends Equatable {
  const PairingState();
  
  @override
  List<Object?> get props => [];
}

/// Initial state before loading
class PairingInitial extends PairingState {
  const PairingInitial();
}

/// Loading state during operations
class PairingLoading extends PairingState {
  final String message;
  
  const PairingLoading([this.message = 'Loading...']);
  
  @override
  List<Object?> get props => [message];
}

/// Not in any session
class PairingDisconnected extends PairingState {
  const PairingDisconnected();
}

/// Session created, showing pairing code for others to join
class PairingCodeGenerated extends PairingState {
  final PairingSession session;
  final Duration timeRemaining;
  
  const PairingCodeGenerated({
    required this.session,
    required this.timeRemaining,
  });
  
  String get pairingCode => session.pairingCode;
  bool get isCodeExpired => timeRemaining <= Duration.zero;
  
  @override
  List<Object?> get props => [session, timeRemaining];
}

/// Successfully connected to a session
class PairingConnected extends PairingState {
  final PairingSession session;
  final List<ConnectedDevice> devices;
  final bool isHost;
  
  const PairingConnected({
    required this.session,
    required this.devices,
    this.isHost = false,
  });
  
  int get deviceCount => devices.length;
  int get activeDeviceCount => 
      devices.where((d) => d.status == DeviceStatus.active).length;
  
  @override
  List<Object?> get props => [session, devices, isHost];
}

/// Error state
class PairingError extends PairingState {
  final String message;
  final PairingState? previousState;
  
  const PairingError(this.message, [this.previousState]);
  
  @override
  List<Object?> get props => [message, previousState];
}
