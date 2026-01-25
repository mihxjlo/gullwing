import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a connected device in the sync network
class ConnectedDevice {
  final String id;
  final String name;
  final DeviceType type;
  final DeviceStatus status;
  final DateTime lastSeen;
  final bool isCurrentDevice;
  final String? sessionId;

  const ConnectedDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.lastSeen,
    this.isCurrentDevice = false,
    this.sessionId,
  });

  IconData get icon {
    switch (type) {
      case DeviceType.android:
        return Icons.phone_android_outlined;
      case DeviceType.ios:
        return Icons.phone_iphone_outlined;
      case DeviceType.web:
        return Icons.language_outlined;
      case DeviceType.desktop:
        return Icons.computer_outlined;
      case DeviceType.unknown:
        return Icons.devices_outlined;
    }
  }

  String get statusText {
    switch (status) {
      case DeviceStatus.active:
        return 'Active now';
      case DeviceStatus.idle:
        return 'Idle';
      case DeviceStatus.offline:
        return 'Offline';
    }
  }

  /// Check if device is online (seen within last 30 seconds)
  bool get isOnline {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    return diff.inSeconds < 30;
  }

  /// Get relative time since last seen
  String get lastSeenText {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    
    if (diff.inSeconds < 30) return 'Online';
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.name,
      'status': status.name,
      'lastSeen': FieldValue.serverTimestamp(),
      'isCurrentDevice': isCurrentDevice,
      'sessionId': sessionId,
    };
  }

  /// Create from Firestore document
  factory ConnectedDevice.fromFirestore(Map<String, dynamic> data, String docId) {
    return ConnectedDevice(
      id: docId,
      name: data['name'] as String? ?? 'Unknown Device',
      type: DeviceType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => DeviceType.unknown,
      ),
      status: DeviceStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => DeviceStatus.offline,
      ),
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : DateTime.now(),
      isCurrentDevice: data['isCurrentDevice'] as bool? ?? false,
      sessionId: data['sessionId'] as String?,
    );
  }

  /// Copy with modifications
  ConnectedDevice copyWith({
    String? id,
    String? name,
    DeviceType? type,
    DeviceStatus? status,
    DateTime? lastSeen,
    bool? isCurrentDevice,
    String? sessionId,
  }) {
    return ConnectedDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

enum DeviceType {
  android,
  ios,
  web,
  desktop,
  unknown,
}

enum DeviceStatus {
  active,
  idle,
  offline,
}

