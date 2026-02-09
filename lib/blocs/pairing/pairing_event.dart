import 'package:equatable/equatable.dart';
import '../../models/pairing_session.dart';

/// Base class for all pairing events
abstract class PairingEvent extends Equatable {
  const PairingEvent();
  
  @override
  List<Object?> get props => [];
}

/// Load current session from local storage
class PairingSessionLoaded extends PairingEvent {
  const PairingSessionLoaded();
}

/// Create a new session (this device becomes host)
class PairingSessionCreated extends PairingEvent {
  const PairingSessionCreated();
}

/// Join an existing session using a pairing code
class PairingSessionJoined extends PairingEvent {
  final String pairingCode;
  
  const PairingSessionJoined(this.pairingCode);
  
  @override
  List<Object?> get props => [pairingCode];
}

/// Join an existing session directly by session ID (from LAN invitation)
class PairingSessionJoinedById extends PairingEvent {
  final String sessionId;
  
  const PairingSessionJoinedById(this.sessionId);
  
  @override
  List<Object?> get props => [sessionId];
}

/// Leave the current session
class PairingSessionLeft extends PairingEvent {
  const PairingSessionLeft();
}

/// Refresh the pairing code (host only)
class PairingCodeRefreshed extends PairingEvent {
  const PairingCodeRefreshed();
}

/// Session was updated (from stream)
class PairingSessionUpdated extends PairingEvent {
  final PairingSession? session;
  
  const PairingSessionUpdated(this.session);
  
  @override
  List<Object?> get props => [session];
}

/// Register this device in the session
class CurrentDeviceRegistered extends PairingEvent {
  const CurrentDeviceRegistered();
}

/// Devices list was updated from stream
class PairingDevicesUpdated extends PairingEvent {
  final List<dynamic> devices;
  
  const PairingDevicesUpdated(this.devices);
  
  @override
  List<Object?> get props => [devices];
}

/// Timer tick for code expiration countdown
class PairingTimerTicked extends PairingEvent {
  const PairingTimerTicked();
}
