import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/connected_device.dart';
import 'firebase_service.dart';
import 'pairing_service.dart';

/// Device Repository
/// Manages device registration and status tracking via Firestore
/// 
/// Devices are stored at /sessions/{sessionId}/devices for paired group tracking
class DeviceRepository {
  final FirebaseService _firebase;
  final PairingService _pairingService;
  
  DeviceRepository({
    FirebaseService? firebase,
    PairingService? pairingServiceParam,
  }) : _firebase = firebase ?? FirebaseService.instance,
       _pairingService = pairingServiceParam ?? pairingService;
  
  /// Get the devices collection reference for current session
  CollectionReference<Map<String, dynamic>>? get _devicesCollection {
    final sessionId = _pairingService.currentSessionId;
    if (sessionId == null) return null;
    
    return _firebase.firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('devices');
  }
  
  /// Check if we have an active session
  bool get hasActiveSession => _pairingService.currentSessionId != null;
  
  /// Watch all connected devices in real-time
  Stream<List<ConnectedDevice>> watchDevices() {
    final collection = _devicesCollection;
    if (collection == null) {
      return Stream.value([]);
    }
    
    return collection
        .orderBy('lastSeen', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ConnectedDevice.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }
  
  /// Get all devices (non-realtime)
  Future<List<ConnectedDevice>> getDevices() async {
    final collection = _devicesCollection;
    if (collection == null) return [];
    
    final snapshot = await collection
        .orderBy('lastSeen', descending: true)
        .get();
    
    return snapshot.docs.map((doc) {
      return ConnectedDevice.fromFirestore(doc.data(), doc.id);
    }).toList();
  }
  
  /// Register or update this device in the current session
  Future<void> registerDevice(ConnectedDevice device) async {
    final collection = _devicesCollection;
    if (collection == null) return;
    
    await collection.doc(device.id).set(
      device.toFirestore(),
      SetOptions(merge: true),
    );
  }
  
  /// Register this device with default info
  Future<void> registerCurrentDevice() async {
    final device = ConnectedDevice(
      id: _pairingService.deviceId,
      name: _pairingService.deviceName,
      type: _deviceTypeFromString(_pairingService.deviceType),
      status: DeviceStatus.active,
      lastSeen: DateTime.now(),
      isCurrentDevice: true,
      sessionId: _pairingService.currentSessionId,
    );
    await registerDevice(device);
  }
  
  DeviceType _deviceTypeFromString(String type) {
    switch (type) {
      case 'android': return DeviceType.android;
      case 'ios': return DeviceType.ios;
      case 'web': return DeviceType.web;
      default: return DeviceType.desktop;
    }
  }
  
  /// Update device online status
  Future<void> updateOnlineStatus(String deviceId, bool isOnline) async {
    final collection = _devicesCollection;
    if (collection == null) return;
    
    await collection.doc(deviceId).update({
      'status': isOnline ? 'active' : 'offline',
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
  
  /// Update device heartbeat (lastSeen timestamp)
  Future<void> updateHeartbeat(String deviceId) async {
    final collection = _devicesCollection;
    if (collection == null) return;
    
    await collection.doc(deviceId).update({
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
  
  /// Remove a device
  Future<void> removeDevice(String deviceId) async {
    final collection = _devicesCollection;
    if (collection == null) return;
    
    await collection.doc(deviceId).delete();
  }
  
  /// Get a specific device
  Future<ConnectedDevice?> getDevice(String deviceId) async {
    final collection = _devicesCollection;
    if (collection == null) return null;
    
    final doc = await collection.doc(deviceId).get();
    if (!doc.exists) return null;
    return ConnectedDevice.fromFirestore(doc.data()!, doc.id);
  }
}
