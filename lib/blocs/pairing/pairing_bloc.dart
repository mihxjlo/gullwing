import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/pairing_session.dart';
import '../../models/connected_device.dart';
import '../../services/pairing_service.dart';
import '../../services/device_repository.dart';
import '../../services/session_repository.dart';
import 'pairing_event.dart';
import 'pairing_state.dart';

/// Pairing BLoC
/// Manages pairing session state and device connections
class PairingBloc extends Bloc<PairingEvent, PairingState> {
  final PairingService _pairingService;
  final DeviceRepository _deviceRepository;
  final SessionRepository _sessionRepository;
  
  StreamSubscription<PairingSession?>? _sessionSubscription;
  StreamSubscription<List<ConnectedDevice>>? _devicesSubscription;
  Timer? _codeExpirationTimer;
  
  PairingBloc({
    PairingService? pairingServiceParam,
    DeviceRepository? deviceRepository,
    SessionRepository? sessionRepository,
  }) : _pairingService = pairingServiceParam ?? pairingService,
       _deviceRepository = deviceRepository ?? DeviceRepository(),
       _sessionRepository = sessionRepository ?? SessionRepository(),
       super(const PairingInitial()) {
    on<PairingSessionLoaded>(_onSessionLoaded);
    on<PairingSessionCreated>(_onSessionCreated);
    on<PairingSessionJoined>(_onSessionJoined);
    on<PairingSessionLeft>(_onSessionLeft);
    on<PairingCodeRefreshed>(_onCodeRefreshed);
    on<PairingSessionUpdated>(_onSessionUpdated);
    on<CurrentDeviceRegistered>(_onDeviceRegistered);
    on<PairingDevicesUpdated>(_onDevicesUpdated);
    on<PairingTimerTicked>(_onTimerTicked);
  }
  
  Future<void> _onSessionLoaded(
    PairingSessionLoaded event,
    Emitter<PairingState> emit,
  ) async {
    emit(const PairingLoading('Checking session...'));
    
    try {
      await _pairingService.init();
      
      final session = await _pairingService.getCurrentSession();
      
      if (session == null) {
        emit(const PairingDisconnected());
        return;
      }
      
      // Validate session is still active
      if (!session.isActive) {
        // Session is no longer active, clear local state
        await _pairingService.clearLocalSessionState();
        emit(const PairingDisconnected());
        return;
      }
      
      // Start watching the session
      _watchSession(session.id);
      
      // Determine if this device is the host (first device in list)
      final isHost = session.deviceIds.isNotEmpty && 
          session.deviceIds.first == _pairingService.deviceId;
      
      emit(PairingConnected(
        session: session,
        devices: [],
        isHost: isHost,
      ));
      
      // Register this device
      add(const CurrentDeviceRegistered());
    } catch (e) {
      // On error, clear local session state to prevent future issues
      await _pairingService.clearLocalSessionState();
      emit(const PairingDisconnected());
    }
  }
  
  Future<void> _onSessionCreated(
    PairingSessionCreated event,
    Emitter<PairingState> emit,
  ) async {
    emit(const PairingLoading('Creating session...'));
    
    try {
      await _pairingService.init();
      final session = await _pairingService.createSession();
      
      _startCodeExpirationTimer(session);
      
      emit(PairingCodeGenerated(
        session: session,
        timeRemaining: session.codeTimeRemaining,
      ));
      
      // Start watching the session for device joins
      _watchSession(session.id);
      
      // Register this device
      add(const CurrentDeviceRegistered());
    } catch (e) {
      emit(PairingError('Failed to create session: $e'));
    }
  }
  
  Future<void> _onSessionJoined(
    PairingSessionJoined event,
    Emitter<PairingState> emit,
  ) async {
    emit(const PairingLoading('Joining session...'));
    
    try {
      await _pairingService.init();
      final session = await _pairingService.joinSession(event.pairingCode);
      
      _watchSession(session.id);
      
      emit(PairingConnected(
        session: session,
        devices: [],
        isHost: false,
      ));
      
      // Register this device
      add(const CurrentDeviceRegistered());
    } on PairingException catch (e) {
      emit(PairingError(e.message));
    } catch (e) {
      emit(PairingError('Failed to join session: $e'));
    }
  }
  
  Future<void> _onSessionLeft(
    PairingSessionLeft event,
    Emitter<PairingState> emit,
  ) async {
    emit(const PairingLoading('Leaving session...'));
    
    try {
      await _pairingService.leaveSession();
      _cancelSubscriptions();
      emit(const PairingDisconnected());
    } catch (e) {
      emit(PairingError('Failed to leave session: $e'));
    }
  }
  
  Future<void> _onCodeRefreshed(
    PairingCodeRefreshed event,
    Emitter<PairingState> emit,
  ) async {
    final currentState = state;
    if (currentState is! PairingCodeGenerated) return;
    
    emit(const PairingLoading('Refreshing code...'));
    
    try {
      final session = await _pairingService.refreshPairingCode();
      if (session == null) {
        emit(const PairingError('Failed to refresh code'));
        return;
      }
      
      _startCodeExpirationTimer(session);
      
      emit(PairingCodeGenerated(
        session: session,
        timeRemaining: session.codeTimeRemaining,
      ));
    } catch (e) {
      emit(PairingError('Failed to refresh code: $e'));
    }
  }
  
  void _onSessionUpdated(
    PairingSessionUpdated event,
    Emitter<PairingState> emit,
  ) {
    final session = event.session;
    if (session == null) {
      emit(const PairingDisconnected());
      return;
    }
    
    final currentState = state;
    
    // If we were showing code and now have other devices, transition to connected
    if (currentState is PairingCodeGenerated && session.deviceIds.length > 1) {
      final isHost = session.deviceIds.first == _pairingService.deviceId;
      emit(PairingConnected(
        session: session,
        devices: currentState is PairingConnected 
            ? (currentState as PairingConnected).devices 
            : [],
        isHost: isHost,
      ));
    } else if (currentState is PairingConnected) {
      emit(currentState.copyWith(session: session));
    }
  }
  
  Future<void> _onDeviceRegistered(
    CurrentDeviceRegistered event,
    Emitter<PairingState> emit,
  ) async {
    try {
      await _deviceRepository.registerCurrentDevice();
    } catch (e) {
      // Non-fatal, just log
    }
  }
  
  void _onDevicesUpdated(
    PairingDevicesUpdated event,
    Emitter<PairingState> emit,
  ) {
    final devices = event.devices.cast<ConnectedDevice>();
    final currentState = state;
    
    if (currentState is PairingConnected) {
      emit(currentState.copyWith(devices: devices));
    } else if (currentState is PairingCodeGenerated) {
      // Transition to connected when devices join
      if (devices.length > 1) {
        final isHost = currentState.session.deviceIds.first == 
            _pairingService.deviceId;
        emit(PairingConnected(
          session: currentState.session,
          devices: devices,
          isHost: isHost,
        ));
      }
    }
  }
  
  void _onTimerTicked(
    PairingTimerTicked event,
    Emitter<PairingState> emit,
  ) {
    final currentState = state;
    if (currentState is PairingCodeGenerated) {
      final remaining = currentState.session.codeTimeRemaining;
      if (remaining <= Duration.zero) {
        _codeExpirationTimer?.cancel();
      }
      emit(PairingCodeGenerated(
        session: currentState.session,
        timeRemaining: remaining,
      ));
    }
  }
  
  void _watchSession(String sessionId) {
    _sessionSubscription?.cancel();
    _sessionSubscription = _sessionRepository.watchSession(sessionId).listen(
      (session) => add(PairingSessionUpdated(session)),
    );
    
    _devicesSubscription?.cancel();
    _devicesSubscription = _sessionRepository.watchSessionDevices(sessionId).listen(
      (devices) => add(PairingDevicesUpdated(devices)),
    );
  }
  
  void _startCodeExpirationTimer(PairingSession session) {
    _codeExpirationTimer?.cancel();
    _codeExpirationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const PairingTimerTicked()),
    );
  }
  
  void _cancelSubscriptions() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _devicesSubscription?.cancel();
    _devicesSubscription = null;
    _codeExpirationTimer?.cancel();
    _codeExpirationTimer = null;
  }
  
  @override
  Future<void> close() {
    _cancelSubscriptions();
    return super.close();
  }
}

extension _PairingConnectedCopyWith on PairingConnected {
  PairingConnected copyWith({
    PairingSession? session,
    List<ConnectedDevice>? devices,
    bool? isHost,
  }) {
    return PairingConnected(
      session: session ?? this.session,
      devices: devices ?? this.devices,
      isHost: isHost ?? this.isHost,
    );
  }
}
