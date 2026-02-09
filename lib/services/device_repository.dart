import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
    
    final currentDeviceId = _pairingService.deviceId;
    
    return collection
        .orderBy('lastSeen', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final device = ConnectedDevice.fromFirestore(doc.data(), doc.id);
            // Override isCurrentDevice based on local comparison
            return device.copyWith(isCurrentDevice: doc.id == currentDeviceId);
          }).toList();
        });
  }
  
  /// Get all devices (non-realtime snapshot)
  /// Note: Cache is kept fresh by the real-time watchDevices() listener
  Future<List<ConnectedDevice>> getDevices() async {
    final collection = _devicesCollection;
    if (collection == null) {
      debugPrint('DeviceRepository.getDevices: No session, returning empty');
      return [];
    }
    
    final currentDeviceId = _pairingService.deviceId;
    
    // Use default behavior - Firestore cache is kept fresh by real-time listeners
    final snapshot = await collection
        .orderBy('lastSeen', descending: true)
        .get();
    
    debugPrint('DeviceRepository.getDevices: Found ${snapshot.docs.length} devices');
    
    return snapshot.docs.map((doc) {
      final device = ConnectedDevice.fromFirestore(doc.data(), doc.id);
      return device.copyWith(isCurrentDevice: doc.id == currentDeviceId);
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
  Future<void> registerCurrentDevice({
    String? localIp,
    int? lanPort,
  }) async {
    final device = ConnectedDevice(
      id: _pairingService.deviceId,
      name: _pairingService.deviceName,
      type: _deviceTypeFromString(_pairingService.deviceType),
      status: DeviceStatus.active,
      lastSeen: DateTime.now(),
      isCurrentDevice: true,
      sessionId: _pairingService.currentSessionId,
      localIp: localIp,
      lanPort: lanPort,
    );
    await registerDevice(device);
  }
  
  /// Update device's local IP address (for LAN discovery)
  Future<void> updateLocalIp(String deviceId, String? ip, int? port) async {
    debugPrint('DeviceRepository.updateLocalIp called: deviceId=$deviceId, ip=$ip, port=$port');
    debugPrint('DeviceRepository.updateLocalIp: sessionId=${_pairingService.currentSessionId}');
    
    final collection = _devicesCollection;
    if (collection == null) {
      debugPrint('DeviceRepository.updateLocalIp: ✗ Collection is null (no session), cannot update');
      return;
    }
    
    try {
      // Use set with merge so it works even if document doesn't exist yet
      await collection.doc(deviceId).set({
        'localIp': ip,
        'lanPort': port,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('DeviceRepository.updateLocalIp: ✓ Successfully updated IP in Firebase');
    } catch (e) {
      debugPrint('DeviceRepository.updateLocalIp: ✗ Failed to update: $e');
    }
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
