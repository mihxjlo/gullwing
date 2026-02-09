import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Represents a trusted device that can auto-connect without user prompt
class TrustedDevice {
  final String deviceId;
  final String deviceName;
  final DateTime addedAt;
  final String? lastKnownIp;

  TrustedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.addedAt,
    this.lastKnownIp,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'addedAt': addedAt.toIso8601String(),
    'lastKnownIp': lastKnownIp,
  };

  factory TrustedDevice.fromJson(Map<String, dynamic> json) => TrustedDevice(
    deviceId: json['deviceId'] ?? '',
    deviceName: json['deviceName'] ?? 'Unknown',
    addedAt: DateTime.tryParse(json['addedAt'] ?? '') ?? DateTime.now(),
    lastKnownIp: json['lastKnownIp'],
  );
}

/// Service for managing trusted devices
/// Trusted devices can reconnect via LAN without prompting user
class TrustedDevicesService {
  static const String _storageKey = 'trusted_devices';
  
  SharedPreferences? _prefs;
  final Map<String, TrustedDevice> _trustedDevices = {};
  
  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadTrustedDevices();
  }
  
  /// Load trusted devices from storage
  Future<void> _loadTrustedDevices() async {
    final json = _prefs?.getString(_storageKey);
    if (json != null) {
      try {
        final List<dynamic> list = jsonDecode(json);
        _trustedDevices.clear();
        for (final item in list) {
          final device = TrustedDevice.fromJson(item);
          _trustedDevices[device.deviceId] = device;
        }
      } catch (e) {
        // Ignore parse errors, start fresh
      }
    }
  }
  
  /// Save trusted devices to storage
  Future<void> _saveTrustedDevices() async {
    final list = _trustedDevices.values.map((d) => d.toJson()).toList();
    await _prefs?.setString(_storageKey, jsonEncode(list));
  }
  
  /// Add a device to trusted list
  Future<void> addTrustedDevice({
    required String deviceId,
    required String deviceName,
    String? lastKnownIp,
  }) async {
    _trustedDevices[deviceId] = TrustedDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      addedAt: DateTime.now(),
      lastKnownIp: lastKnownIp,
    );
    await _saveTrustedDevices();
  }
  
  /// Remove a device from trusted list
  Future<void> removeTrustedDevice(String deviceId) async {
    _trustedDevices.remove(deviceId);
    await _saveTrustedDevices();
  }
  
  /// Check if a device is trusted
  bool isTrusted(String deviceId) {
    return _trustedDevices.containsKey(deviceId);
  }
  
  /// Get a trusted device by ID
  TrustedDevice? getTrustedDevice(String deviceId) {
    return _trustedDevices[deviceId];
  }
  
  /// Get all trusted devices
  List<TrustedDevice> getAllTrustedDevices() {
    return _trustedDevices.values.toList();
  }
  
  /// Get trusted device IDs as a Set
  Set<String> get trustedDeviceIds => _trustedDevices.keys.toSet();
  
  /// Update last known IP for a device
  Future<void> updateLastKnownIp(String deviceId, String ip) async {
    final device = _trustedDevices[deviceId];
    if (device != null) {
      _trustedDevices[deviceId] = TrustedDevice(
        deviceId: device.deviceId,
        deviceName: device.deviceName,
        addedAt: device.addedAt,
        lastKnownIp: ip,
      );
      await _saveTrustedDevices();
    }
  }
  
  /// Clear all trusted devices
  Future<void> clearAllTrustedDevices() async {
    _trustedDevices.clear();
    await _saveTrustedDevices();
  }
}

/// Global instance
final trustedDevicesService = TrustedDevicesService();
