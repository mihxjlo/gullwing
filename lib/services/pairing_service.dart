import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/pairing_session.dart';
import 'session_repository.dart';

/// Pairing Service
/// Manages device identity and current session state with local persistence
/// 
/// This service is designed to be extensible for future discovery methods:
/// - LAN/local network discovery
/// - Bluetooth-based pairing
/// - QR code scanning
class PairingService {
  static const String _deviceIdKey = 'device_id';
  static const String _deviceNameKey = 'device_name';
  static const String _sessionIdKey = 'current_session_id';
  
  final SessionRepository _sessionRepository;
  SharedPreferences? _prefs;
  
  PairingService({SessionRepository? sessionRepository})
      : _sessionRepository = sessionRepository ?? SessionRepository();
  
  /// Initialize the pairing service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Get or create a unique device identifier
  String get deviceId {
    var id = _prefs?.getString(_deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      _prefs?.setString(_deviceIdKey, id);
    }
    return id;
  }
  
  /// Get the device name (defaults to platform name)
  String get deviceName {
    return _prefs?.getString(_deviceNameKey) ?? _defaultDeviceName;
  }
  
  /// Set custom device name
  Future<void> setDeviceName(String name) async {
    await _prefs?.setString(_deviceNameKey, name);
  }
  
  /// Get default device name based on platform
  String get _defaultDeviceName {
    if (kIsWeb) return 'Web Browser';
    if (Platform.isAndroid) return 'Android Phone';
    if (Platform.isIOS) return 'iPhone';
    if (Platform.isMacOS) return 'Mac';
    if (Platform.isWindows) return 'Windows PC';
    if (Platform.isLinux) return 'Linux PC';
    return 'Unknown Device';
  }
  
  /// Get the device type based on platform
  String get deviceType {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'desktop';
  }
  
  /// Get current session ID (null if not in a session)
  String? get currentSessionId {
    return _prefs?.getString(_sessionIdKey);
  }
  
  /// Check if device is currently in a session
  bool get isInSession => currentSessionId != null;
  
  /// Store the current session ID
  Future<void> _setCurrentSession(String? sessionId) async {
    if (sessionId == null) {
      await _prefs?.remove(_sessionIdKey);
    } else {
      await _prefs?.setString(_sessionIdKey, sessionId);
    }
  }
  
  /// Create a new pairing session (this device becomes host)
  Future<PairingSession> createSession() async {
    final session = await _sessionRepository.createSession(
      hostDeviceId: deviceId,
    );
    await _setCurrentSession(session.id);
    return session;
  }
  
  /// Join an existing session using a pairing code
  Future<PairingSession> joinSession(String pairingCode) async {
    final session = await _sessionRepository.joinSession(
      pairingCode: pairingCode.toUpperCase().trim(),
      deviceId: deviceId,
    );
    await _setCurrentSession(session.id);
    return session;
  }
  
  /// Leave the current session
  Future<void> leaveSession() async {
    final sessionId = currentSessionId;
    
    // Clear local state first (so even if backend fails, we're disconnected locally)
    await _setCurrentSession(null);
    
    if (sessionId == null) return;
    
    try {
      await _sessionRepository.leaveSession(
        sessionId: sessionId,
        deviceId: deviceId,
      );
    } catch (e) {
      // Backend call failed but local state is already cleared
      // This is acceptable - device is disconnected locally
    }
  }
  
  /// Get the current session details
  Future<PairingSession?> getCurrentSession() async {
    final sessionId = currentSessionId;
    if (sessionId == null) return null;
    return _sessionRepository.getSession(sessionId);
  }
  
  /// Watch the current session for changes
  Stream<PairingSession?> watchCurrentSession() {
    final sessionId = currentSessionId;
    if (sessionId == null) {
      return Stream.value(null);
    }
    return _sessionRepository.watchSession(sessionId);
  }
  
  /// Refresh the pairing code for current session
  Future<PairingSession?> refreshPairingCode() async {
    final sessionId = currentSessionId;
    if (sessionId == null) return null;
    return _sessionRepository.refreshPairingCode(sessionId: sessionId);
  }
  
  /// Clear local session state without calling the backend
  /// Used when session is detected as invalid
  Future<void> clearLocalSessionState() async {
    await _prefs?.remove(_sessionIdKey);
  }
  
  /// Clear all pairing data (for testing or reset)
  Future<void> clearPairingData() async {
    await _prefs?.remove(_sessionIdKey);
    await _prefs?.remove(_deviceIdKey);
    await _prefs?.remove(_deviceNameKey);
  }
}

/// Global pairing service instance
final pairingService = PairingService();
