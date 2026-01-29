import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a pairing session that connects multiple devices
/// 
/// Sessions are created by one device (host) and joined by others using
/// a short-lived pairing code. Once paired, devices share clipboard data
/// within the session.
class PairingSession {
  final String id;
  final String pairingCode;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> deviceIds;
  final bool isActive;
  final String hostDeviceId; // Session admin - if this device leaves, session closes

  const PairingSession({
    required this.id,
    required this.pairingCode,
    required this.createdAt,
    required this.expiresAt,
    required this.deviceIds,
    this.isActive = true,
    required this.hostDeviceId,
  });

  /// Check if the pairing code is still valid
  bool get isCodeValid => DateTime.now().isBefore(expiresAt) && isActive;

  /// Check if session has multiple devices paired
  bool get hasPairedDevices => deviceIds.length > 1;

  /// Get remaining time for pairing code
  Duration get codeTimeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'pairingCode': pairingCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'deviceIds': deviceIds,
      'isActive': isActive,
      'hostDeviceId': hostDeviceId,
    };
  }

  /// Create from Firestore document
  factory PairingSession.fromFirestore(Map<String, dynamic> data, String docId) {
    return PairingSession(
      id: docId,
      pairingCode: data['pairingCode'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : DateTime.now(),
      deviceIds: (data['deviceIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      isActive: data['isActive'] as bool? ?? true,
      hostDeviceId: data['hostDeviceId'] as String? ?? '',
    );
  }

  /// Create a new session with a fresh pairing code
  factory PairingSession.create({
    required String id,
    required String pairingCode,
    required String hostDeviceId,
    Duration codeValidity = const Duration(minutes: 5),
  }) {
    final now = DateTime.now();
    return PairingSession(
      id: id,
      pairingCode: pairingCode,
      createdAt: now,
      expiresAt: now.add(codeValidity),
      deviceIds: [hostDeviceId],
      isActive: true,
      hostDeviceId: hostDeviceId,
    );
  }

  /// Copy with modifications
  PairingSession copyWith({
    String? id,
    String? pairingCode,
    DateTime? createdAt,
    DateTime? expiresAt,
    List<String>? deviceIds,
    bool? isActive,
    String? hostDeviceId,
  }) {
    return PairingSession(
      id: id ?? this.id,
      pairingCode: pairingCode ?? this.pairingCode,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      deviceIds: deviceIds ?? this.deviceIds,
      isActive: isActive ?? this.isActive,
      hostDeviceId: hostDeviceId ?? this.hostDeviceId,
    );
  }

  /// Add a device to the session
  PairingSession addDevice(String deviceId) {
    if (deviceIds.contains(deviceId)) return this;
    return copyWith(deviceIds: [...deviceIds, deviceId]);
  }

  /// Remove a device from the session
  PairingSession removeDevice(String deviceId) {
    return copyWith(
      deviceIds: deviceIds.where((id) => id != deviceId).toList(),
    );
  }
}

/// Represents a pairing code lookup entry for quick validation
/// Stored at /pairing_codes/{code} for O(1) code lookup
class PairingCodeEntry {
  final String code;
  final String sessionId;
  final DateTime expiresAt;

  const PairingCodeEntry({
    required this.code,
    required this.sessionId,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toFirestore() {
    return {
      'sessionId': sessionId,
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  factory PairingCodeEntry.fromFirestore(Map<String, dynamic> data, String code) {
    return PairingCodeEntry(
      code: code,
      sessionId: data['sessionId'] as String? ?? '',
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
