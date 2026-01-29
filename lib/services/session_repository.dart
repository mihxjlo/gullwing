import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pairing_session.dart';
import '../models/connected_device.dart';
import 'firebase_service.dart';

/// Session Repository
/// Manages pairing sessions in Firestore with real-time sync
class SessionRepository {
  final FirebaseService _firebase;
  
  SessionRepository({FirebaseService? firebase})
      : _firebase = firebase ?? FirebaseService.instance;
  
  /// Get the sessions collection reference
  CollectionReference<Map<String, dynamic>> get _sessionsCollection =>
      _firebase.firestore.collection('sessions');
  
  /// Get the pairing codes collection reference (for quick lookup)
  CollectionReference<Map<String, dynamic>> get _pairingCodesCollection =>
      _firebase.firestore.collection('pairing_codes');
  
  /// Create a new pairing session
  /// Returns the created session with ID and pairing code
  Future<PairingSession> createSession({
    required String hostDeviceId,
    Duration codeValidity = const Duration(minutes: 5),
  }) async {
    // Generate a unique pairing code
    final pairingCode = _generatePairingCode();
    
    // Create session document
    final docRef = _sessionsCollection.doc();
    final session = PairingSession.create(
      id: docRef.id,
      pairingCode: pairingCode,
      hostDeviceId: hostDeviceId,
      codeValidity: codeValidity,
    );
    
    // Write session and code lookup atomically
    final batch = _firebase.firestore.batch();
    batch.set(docRef, session.toFirestore());
    batch.set(_pairingCodesCollection.doc(pairingCode), {
      'sessionId': docRef.id,
      'expiresAt': Timestamp.fromDate(session.expiresAt),
    });
    await batch.commit();
    
    return session;
  }
  
  /// Join an existing session using a pairing code
  /// Returns the session if successful, throws if code is invalid/expired
  Future<PairingSession> joinSession({
    required String pairingCode,
    required String deviceId,
  }) async {
    // Look up the pairing code
    final codeDoc = await _pairingCodesCollection.doc(pairingCode.toUpperCase()).get();
    
    if (!codeDoc.exists) {
      throw PairingException('Invalid pairing code');
    }
    
    final codeEntry = PairingCodeEntry.fromFirestore(codeDoc.data()!, codeDoc.id);
    
    if (codeEntry.isExpired) {
      throw PairingException('Pairing code has expired');
    }
    
    // Get the session
    final sessionDoc = await _sessionsCollection.doc(codeEntry.sessionId).get();
    
    if (!sessionDoc.exists) {
      throw PairingException('Session not found');
    }
    
    final session = PairingSession.fromFirestore(sessionDoc.data()!, sessionDoc.id);
    
    if (!session.isActive) {
      throw PairingException('Session is no longer active');
    }
    
    // Add device to session if not already present
    if (!session.deviceIds.contains(deviceId)) {
      await _sessionsCollection.doc(session.id).update({
        'deviceIds': FieldValue.arrayUnion([deviceId]),
      });
      return session.addDevice(deviceId);
    }
    
    return session;
  }
  
  /// Get a session by ID
  Future<PairingSession?> getSession(String sessionId) async {
    final doc = await _sessionsCollection.doc(sessionId).get();
    if (!doc.exists) return null;
    return PairingSession.fromFirestore(doc.data()!, doc.id);
  }
  
  /// Watch a session for real-time updates
  Stream<PairingSession?> watchSession(String sessionId) {
    return _sessionsCollection.doc(sessionId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return PairingSession.fromFirestore(snapshot.data()!, snapshot.id);
    });
  }
  
  /// Get devices collection for a session
  CollectionReference<Map<String, dynamic>> getDevicesCollection(String sessionId) {
    return _sessionsCollection.doc(sessionId).collection('devices');
  }
  
  /// Get clipboard items collection for a session
  CollectionReference<Map<String, dynamic>> getClipboardCollection(String sessionId) {
    return _sessionsCollection.doc(sessionId).collection('clipboard_items');
  }
  
  /// Watch devices in a session
  Stream<List<ConnectedDevice>> watchSessionDevices(String sessionId) {
    return getDevicesCollection(sessionId)
        .orderBy('lastSeen', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ConnectedDevice.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }
  
  /// Leave a session (remove device from session)
  /// If the host leaves, the entire session is deactivated
  Future<void> leaveSession({
    required String sessionId,
    required String deviceId,
  }) async {
    // Get session to check if this device is the host
    final session = await getSession(sessionId);
    
    if (session != null && session.hostDeviceId == deviceId) {
      // Host is leaving - deactivate the entire session
      await deactivateSession(sessionId);
      
      // Remove device document
      await getDevicesCollection(sessionId).doc(deviceId).delete();
    } else {
      // Regular device leaving - just remove from session
      await _sessionsCollection.doc(sessionId).update({
        'deviceIds': FieldValue.arrayRemove([deviceId]),
      });
      
      // Remove device document
      await getDevicesCollection(sessionId).doc(deviceId).delete();
    }
  }
  
  /// Deactivate a session (host action)
  Future<void> deactivateSession(String sessionId) async {
    await _sessionsCollection.doc(sessionId).update({
      'isActive': false,
    });
  }
  
  /// Generate a 6-character alphanumeric pairing code
  String _generatePairingCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed ambiguous: 0, O, I, 1
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
  
  /// Refresh pairing code (host action)
  Future<PairingSession> refreshPairingCode({
    required String sessionId,
    Duration codeValidity = const Duration(minutes: 5),
  }) async {
    final newCode = _generatePairingCode();
    final expiresAt = DateTime.now().add(codeValidity);
    
    // Get current session to find old code
    final session = await getSession(sessionId);
    if (session == null) {
      throw PairingException('Session not found');
    }
    
    // Update session and code lookup atomically
    final batch = _firebase.firestore.batch();
    
    // Delete old code
    batch.delete(_pairingCodesCollection.doc(session.pairingCode));
    
    // Update session with new code
    batch.update(_sessionsCollection.doc(sessionId), {
      'pairingCode': newCode,
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    
    // Create new code lookup
    batch.set(_pairingCodesCollection.doc(newCode), {
      'sessionId': sessionId,
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    
    await batch.commit();
    
    return session.copyWith(
      pairingCode: newCode,
      expiresAt: expiresAt,
    );
  }
}

/// Exception thrown for pairing errors
class PairingException implements Exception {
  final String message;
  PairingException(this.message);
  
  @override
  String toString() => 'PairingException: $message';
}
