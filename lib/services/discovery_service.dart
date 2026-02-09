import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'lan_service.dart';

/// Represents a device discovered via UDP broadcast
class DiscoveredDevice {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  final int wsPort;
  final bool hasSession;
  final String? sessionId;
  final DateTime discoveredAt;

  DiscoveredDevice({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.wsPort,
    required this.hasSession,
    this.sessionId,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  bool get isExpired => DateTime.now().difference(discoveredAt).inSeconds > 15;

  Map<String, dynamic> toJson() => {
    'type': 'clipsync_announce',
    'deviceId': deviceId,
    'deviceName': deviceName,
    'ip': ipAddress,
    'wsPort': wsPort,
    'hasSession': hasSession,
    'sessionId': sessionId,
  };

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json, String sourceIp) {
    return DiscoveredDevice(
      deviceId: json['deviceId'] ?? '',
      deviceName: json['deviceName'] ?? 'Unknown Device',
      ipAddress: json['ip'] ?? sourceIp,
      wsPort: json['wsPort'] ?? LanService.defaultPort,
      hasSession: json['hasSession'] ?? false,
      sessionId: json['sessionId'],
    );
  }
}

/// Invitation message structure
class Invitation {
  final String hostDeviceId;
  final String hostName;
  final String hostIp;
  final String sessionId;
  final DateTime receivedAt;

  Invitation({
    required this.hostDeviceId,
    required this.hostName,
    required this.hostIp,
    required this.sessionId,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': 'clipsync_invite',
    'hostDeviceId': hostDeviceId,
    'hostName': hostName,
    'hostIp': hostIp,
    'sessionId': sessionId,
  };

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      hostDeviceId: json['hostDeviceId'] ?? '',
      hostName: json['hostName'] ?? 'Unknown Host',
      hostIp: json['hostIp'] ?? '',
      sessionId: json['sessionId'] ?? '',
    );
  }
}

/// Service for UDP-based device discovery and invitations
/// Android broadcasts presence, all platforms listen for invitations
class DiscoveryService {
  static DiscoveryService? _instance;
  static DiscoveryService get instance => _instance ??= DiscoveryService._();
  
  DiscoveryService._();

  /// UDP port for discovery broadcasts
  static const int discoveryPort = 8766;
  
  /// Broadcast interval
  static const Duration broadcastInterval = Duration(seconds: 3);
  
  /// Device info
  String _deviceId = '';
  String _deviceName = '';
  String? _sessionId;
  String? _localIp;
  
  /// UDP sockets
  RawDatagramSocket? _broadcastSocket;
  RawDatagramSocket? _listenerSocket;
  Timer? _broadcastTimer;
  
  /// Discovered devices cache (cleaned up periodically)
  final Map<String, DiscoveredDevice> _discoveredDevices = {};
  
  /// Streams
  final _discoveredDevicesController = StreamController<List<DiscoveredDevice>>.broadcast();
  final _invitationController = StreamController<Invitation>.broadcast();
  
  /// Public streams
  Stream<List<DiscoveredDevice>> get discoveredDevices => _discoveredDevicesController.stream;
  Stream<Invitation> get invitations => _invitationController.stream;
  
  /// Current discovered devices list
  List<DiscoveredDevice> get currentDiscoveredDevices {
    _cleanupExpiredDevices();
    return _discoveredDevices.values.toList();
  }
  
  /// Check if broadcasting is supported (Android + Desktop, not Web)
  bool get canBroadcast => !kIsWeb;
  
  /// Initialize with device info
  void initialize({
    required String deviceId,
    required String deviceName,
  }) {
    _deviceId = deviceId;
    _deviceName = deviceName;
    debugPrint('DiscoveryService: Initialized for "$deviceName" ($deviceId)');
  }
  
  /// Update session info
  void updateSession(String? sessionId) {
    _sessionId = sessionId;
    debugPrint('DiscoveryService: Session updated to $sessionId');
  }
  
  /// Set local IP (called from LanService)
  void setLocalIp(String? ip) {
    _localIp = ip;
    debugPrint('DiscoveryService: Local IP set to $ip');
  }
  
  // ============ Broadcasting (Android Only) ============
  
  /// Start UDP broadcast (Android announces presence)
  Future<bool> startBroadcast() async {
    if (!canBroadcast) {
      debugPrint('DiscoveryService: Cannot broadcast on this platform');
      return false;
    }
    
    if (_broadcastSocket != null) {
      debugPrint('DiscoveryService: Broadcast already running');
      return true;
    }
    
    try {
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // Let OS pick port for sending
      );
      _broadcastSocket!.broadcastEnabled = true;
      
      debugPrint('DiscoveryService: Broadcast socket bound');
      
      // Start periodic broadcast
      _broadcastTimer = Timer.periodic(broadcastInterval, (_) => _sendBroadcast());
      _sendBroadcast(); // Send immediately
      
      debugPrint('DiscoveryService: Broadcasting started');
      return true;
    } catch (e) {
      debugPrint('DiscoveryService: Failed to start broadcast: $e');
      return false;
    }
  }
  
  /// Stop broadcasting
  void stopBroadcast() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
    debugPrint('DiscoveryService: Broadcast stopped');
  }
  
  /// Send a single broadcast packet
  void _sendBroadcast() {
    if (_broadcastSocket == null || _localIp == null) return;
    
    final packet = DiscoveredDevice(
      deviceId: _deviceId,
      deviceName: _deviceName,
      ipAddress: _localIp!,
      wsPort: LanService.defaultPort,
      hasSession: _sessionId != null,
      sessionId: _sessionId,
    ).toJson();
    
    final data = utf8.encode(jsonEncode(packet));
    
    try {
      // Broadcast to subnet
      _broadcastSocket!.send(
        data,
        InternetAddress('255.255.255.255'),
        discoveryPort,
      );
      // Reduce log spam - only log occasionally
    } catch (e) {
      debugPrint('DiscoveryService: Broadcast send failed: $e');
    }
  }
  
  // ============ Listening ============
  
  /// Start listening for broadcasts and invitations
  Future<bool> startListening() async {
    if (kIsWeb) {
      debugPrint('DiscoveryService: Web cannot listen for UDP, skipping');
      return false;
    }
    
    if (_listenerSocket != null) {
      debugPrint('DiscoveryService: Already listening');
      return true;
    }
    
    try {
      // Note: reusePort is not supported on Android, only use reuseAddress
      _listenerSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        // reusePort: true, // NOT SUPPORTED ON ANDROID - causes crash
      );
      
      debugPrint('DiscoveryService: Listening on port $discoveryPort');
      
      _listenerSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _listenerSocket!.receive();
          if (datagram != null) {
            _handleIncomingPacket(datagram);
          }
        }
      });
      
      // Cleanup expired devices periodically
      Timer.periodic(const Duration(seconds: 5), (_) {
        _cleanupExpiredDevices();
      });
      
      return true;
    } catch (e) {
      debugPrint('DiscoveryService: Failed to start listening: $e');
      return false;
    }
  }
  
  /// Stop listening
  void stopListening() {
    _listenerSocket?.close();
    _listenerSocket = null;
    _discoveredDevices.clear();
    debugPrint('DiscoveryService: Stopped listening');
  }
  
  /// Handle incoming UDP packet
  void _handleIncomingPacket(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      final json = jsonDecode(message) as Map<String, dynamic>;
      final type = json['type'] as String?;
      
      final sourceIp = datagram.address.address;
      
      // Only log non-announce packets to reduce spam
      if (type != 'clipsync_announce') {
        debugPrint('DiscoveryService: Received $type from $sourceIp');
      }
      
      switch (type) {
        case 'clipsync_announce':
          _handleAnnounce(json, sourceIp);
          break;
        case 'clipsync_invite':
          _handleInvite(json);
          break;
        default:
          debugPrint('DiscoveryService: Unknown packet type: $type');
      }
    } catch (e) {
      debugPrint('DiscoveryService: Failed to parse packet: $e');
    }
  }
  
  /// Handle announce broadcast
  void _handleAnnounce(Map<String, dynamic> json, String sourceIp) {
    final device = DiscoveredDevice.fromJson(json, sourceIp);
    
    // Ignore our own broadcasts (check both deviceId AND IP)
    if (device.deviceId == _deviceId) return;
    if (_localIp != null && sourceIp == _localIp) return;
    
    // Update or add device
    final isNew = !_discoveredDevices.containsKey(device.deviceId);
    _discoveredDevices[device.deviceId] = device;
    
    // Only log when a NEW device is discovered
    if (isNew) {
      debugPrint('DiscoveryService: Discovered "${device.deviceName}" at ${device.ipAddress}');
    }
    _notifyDiscoveredDevicesChange();
  }
  
  /// Handle invitation
  void _handleInvite(Map<String, dynamic> json) {
    final invitation = Invitation.fromJson(json);
    
    debugPrint('DiscoveryService: Received invitation from "${invitation.hostName}"');
    _invitationController.add(invitation);
  }
  
  // ============ Sending Invitations ============
  
  /// Send an invitation to a specific device
  Future<bool> sendInvitation({
    required String targetIp,
    required String sessionId,
  }) async {
    if (_localIp == null) {
      debugPrint('DiscoveryService: Cannot send invitation without local IP');
      return false;
    }
    
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      
      final invitation = Invitation(
        hostDeviceId: _deviceId,
        hostName: _deviceName,
        hostIp: _localIp!,
        sessionId: sessionId,
      ).toJson();
      
      final data = utf8.encode(jsonEncode(invitation));
      
      socket.send(data, InternetAddress(targetIp), discoveryPort);
      
      debugPrint('DiscoveryService: Sent invitation to $targetIp');
      
      socket.close();
      return true;
    } catch (e) {
      debugPrint('DiscoveryService: Failed to send invitation: $e');
      return false;
    }
  }
  
  // ============ Helpers ============
  
  void _cleanupExpiredDevices() {
    final expired = _discoveredDevices.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();
    
    for (final id in expired) {
      _discoveredDevices.remove(id);
    }
    
    if (expired.isNotEmpty) {
      debugPrint('DiscoveryService: Cleaned up ${expired.length} expired devices');
      _notifyDiscoveredDevicesChange();
    }
  }
  
  void _notifyDiscoveredDevicesChange() {
    _discoveredDevicesController.add(currentDiscoveredDevices);
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    stopBroadcast();
    stopListening();
    await _discoveredDevicesController.close();
    await _invitationController.close();
  }
}

/// Global instance
final discoveryService = DiscoveryService.instance;
