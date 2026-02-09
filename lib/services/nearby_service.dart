import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/clipboard_item.dart';

/// Connection state for a nearby device
enum NearbyConnectionState {
  disconnected,
  connecting,
  connected,
}

/// Represents a discovered nearby device
class NearbyDevice {
  final String endpointId;
  final String deviceName;
  final String? deviceId;
  final String? authToken; // Authentication token for secure pairing
  NearbyConnectionState connectionState;

  NearbyDevice({
    required this.endpointId,
    required this.deviceName,
    this.deviceId,
    this.authToken,
    this.connectionState = NearbyConnectionState.disconnected,
  });

  /// Alias for deviceName for compatibility
  String get name => deviceName;
  
  /// Alias for connectionState for compatibility
  NearbyConnectionState get state => connectionState;
}

/// Callback types
typedef OnDeviceDiscovered = void Function(NearbyDevice device);
typedef OnDeviceLost = void Function(String endpointId);
typedef OnConnectionRequested = void Function(NearbyDevice device);
typedef OnConnectionResult = void Function(String endpointId, bool accepted);
typedef OnDisconnected = void Function(String endpointId);
typedef OnItemReceived = void Function(ClipboardItem item);
typedef OnTransferProgress = void Function(String endpointId, double progress);

/// Service for Android P2P sync via Nearby Connections
/// Uses WiFi Direct + Bluetooth for offline device-to-device communication
class NearbyService {
  static NearbyService? _instance;
  static NearbyService get instance => _instance ??= NearbyService._();
  
  NearbyService._();
  
  final Nearby _nearby = Nearby();
  
  /// Service ID for ClipSync discovery
  static const String _serviceId = 'com.clipsync.nearby';
  
  /// Strategy for connections (P2P_CLUSTER for multi-device)
  static const Strategy _strategy = Strategy.P2P_CLUSTER;
  
  /// Current device name for advertising
  String _deviceName = 'Android Device';
  String? _deviceId;
  String? _sessionId;
  
  /// Discovered devices
  final Map<String, NearbyDevice> _discoveredDevices = {};
  
  /// Connected devices
  final Map<String, NearbyDevice> _connectedDevices = {};
  
  /// Status flags
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  
  /// Callbacks
  OnDeviceDiscovered? onDeviceDiscovered;
  OnDeviceLost? onDeviceLost;
  OnConnectionRequested? onConnectionRequested;
  OnConnectionResult? onConnectionResult;
  OnDisconnected? onDisconnected;
  OnItemReceived? onItemReceived;
  OnTransferProgress? onTransferProgress;
  
  /// Stream controllers
  final _connectedDevicesController = StreamController<List<NearbyDevice>>.broadcast();
  Stream<List<NearbyDevice>> get connectedDevicesStream => _connectedDevicesController.stream;
  
  /// Getters
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  bool get hasConnections => _connectedDevices.isNotEmpty;
  List<NearbyDevice> get connectedDevices => _connectedDevices.values.toList();
  List<NearbyDevice> get discoveredDevices => _discoveredDevices.values.toList();
  
  /// Check if Nearby Connections is supported on this platform
  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  
  /// Get current device ID
  String? get deviceId => _deviceId;
  
  /// Get current session ID
  String? get sessionId => _sessionId;
  
  /// Initialize the service
  Future<void> init({
    required String deviceName,
    required String deviceId,
    String? sessionId,
  }) async {
    _deviceName = deviceName;
    _deviceId = deviceId;
    _sessionId = sessionId;
  }
  
  /// Update session ID (when joining/leaving sessions)
  void updateSession(String? sessionId) {
    _sessionId = sessionId;
  }
  
  /// Request required permissions for Nearby Connections
  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    
    // Request all required permissions
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ];
    
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    // Check if all critical permissions are granted
    bool locationGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;
    bool bluetoothGranted = (statuses[Permission.bluetoothScan]?.isGranted ?? false) ||
                            (statuses[Permission.bluetooth]?.isGranted ?? false);
    
    return locationGranted && bluetoothGranted;
  }
  
  /// Check if location services are enabled (required for Nearby)
  Future<bool> checkLocationEnabled() async {
    return await Permission.locationWhenInUse.serviceStatus.isEnabled;
  }
  
  /// Start advertising this device for discovery
  Future<bool> startAdvertising() async {
    if (!isSupported || _isAdvertising) return false;
    
    try {
      await _nearby.startAdvertising(
        _deviceName,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
      
      _isAdvertising = true;
      return true;
    } catch (e) {
      debugPrint('NearbyService: Failed to start advertising: $e');
      return false;
    }
  }
  
  /// Stop advertising
  Future<void> stopAdvertising() async {
    if (!isSupported || !_isAdvertising) return;
    
    try {
      await _nearby.stopAdvertising();
      _isAdvertising = false;
    } catch (e) {
      debugPrint('NearbyService: Failed to stop advertising: $e');
    }
  }
  
  /// Start discovering nearby devices
  Future<bool> startDiscovery() async {
    if (!isSupported || _isDiscovering) return false;
    
    try {
      await _nearby.startDiscovery(
        _deviceName,
        _strategy,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: _serviceId,
      );
      
      _isDiscovering = true;
      return true;
    } catch (e) {
      debugPrint('NearbyService: Failed to start discovery: $e');
      return false;
    }
  }
  
  /// Stop discovery
  Future<void> stopDiscovery() async {
    if (!isSupported || !_isDiscovering) return;
    
    try {
      await _nearby.stopDiscovery();
      _isDiscovering = false;
      _discoveredDevices.clear();
    } catch (e) {
      debugPrint('NearbyService: Failed to stop discovery: $e');
    }
  }
  
  /// Request connection to a discovered device
  Future<bool> requestConnection(String endpointId) async {
    if (!isSupported) return false;
    
    try {
      await _nearby.requestConnection(
        _deviceName,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      
      // Update device state
      if (_discoveredDevices.containsKey(endpointId)) {
        _discoveredDevices[endpointId]!.connectionState = NearbyConnectionState.connecting;
      }
      
      return true;
    } catch (e) {
      debugPrint('NearbyService: Failed to request connection: $e');
      return false;
    }
  }
  
  /// Accept an incoming connection
  Future<bool> acceptConnection(String endpointId) async {
    if (!isSupported) return false;
    
    try {
      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: _onPayloadReceived,
        onPayloadTransferUpdate: _onPayloadTransferUpdate,
      );
      return true;
    } catch (e) {
      debugPrint('NearbyService: Failed to accept connection: $e');
      return false;
    }
  }
  
  /// Reject an incoming connection
  Future<bool> rejectConnection(String endpointId) async {
    if (!isSupported) return false;
    
    try {
      await _nearby.rejectConnection(endpointId);
      return true;
    } catch (e) {
      debugPrint('NearbyService: Failed to reject connection: $e');
      return false;
    }
  }
  
  /// Disconnect from a specific device
  Future<void> disconnectFromDevice(String endpointId) async {
    if (!isSupported) return;
    
    try {
      await _nearby.disconnectFromEndpoint(endpointId);
      _connectedDevices.remove(endpointId);
      _notifyConnectedDevicesChange();
    } catch (e) {
      debugPrint('NearbyService: Failed to disconnect: $e');
    }
  }
  
  /// Disconnect from all devices and stop services
  Future<void> disconnectAll() async {
    if (!isSupported) return;
    
    try {
      await _nearby.stopAllEndpoints();
      _connectedDevices.clear();
      _notifyConnectedDevicesChange();
    } catch (e) {
      debugPrint('NearbyService: Failed to disconnect all: $e');
    }
  }
  
  /// Send a clipboard item to all connected devices
  Future<void> broadcastClipboardItem(ClipboardItem item) async {
    for (final device in _connectedDevices.values) {
      await sendClipboardItem(item, device.endpointId);
    }
  }
  
  /// Send a clipboard item to a specific device
  Future<bool> sendClipboardItem(ClipboardItem item, String endpointId) async {
    if (!isSupported) return false;
    
    try {
      // Serialize item to JSON
      final json = jsonEncode({
        'type': 'clipboard_item',
        'data': item.toFirestore(),
      });
      
      final bytes = Uint8List.fromList(utf8.encode(json));
      
      await _nearby.sendBytesPayload(endpointId, bytes);
      return true;
    } catch (e) {
      debugPrint('NearbyService: Failed to send clipboard item: $e');
      return false;
    }
  }
  
  /// Send file bytes to a device (for large files)
  Future<bool> sendFileBytes(
    String endpointId,
    Uint8List bytes,
    String fileName,
    String itemId,
  ) async {
    if (!isSupported) return false;
    
    try {
      // Send metadata first
      final metadata = jsonEncode({
        'type': 'file_metadata',
        'itemId': itemId,
        'fileName': fileName,
        'size': bytes.length,
      });
      
      await _nearby.sendBytesPayload(
        endpointId,
        Uint8List.fromList(utf8.encode(metadata)),
      );
      
      // Then send the file bytes
      await _nearby.sendBytesPayload(endpointId, bytes);
      
      return true;
    } catch (e) {
      debugPrint('NearbyService: Failed to send file: $e');
      return false;
    }
  }
  
  // ============ Private Callbacks ============
  
  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    final device = NearbyDevice(
      endpointId: endpointId,
      deviceName: endpointName,
    );
    
    _discoveredDevices[endpointId] = device;
    onDeviceDiscovered?.call(device);
  }
  
  void _onEndpointLost(String? endpointId) {
    if (endpointId != null) {
      _discoveredDevices.remove(endpointId);
      onDeviceLost?.call(endpointId);
    }
  }
  
  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    final device = NearbyDevice(
      endpointId: endpointId,
      deviceName: info.endpointName,
      authToken: info.authenticationToken, // 4-digit code for verification
      connectionState: NearbyConnectionState.connecting,
    );
    
    // If we initiated, auto-accept; otherwise prompt user
    if (info.isIncomingConnection) {
      onConnectionRequested?.call(device);
    } else {
      // We initiated, auto-accept
      acceptConnection(endpointId);
    }
  }
  
  void _onConnectionResult(String endpointId, Status status) {
    final accepted = status == Status.CONNECTED;
    
    if (accepted) {
      // Move from discovered to connected
      final device = _discoveredDevices[endpointId] ?? NearbyDevice(
        endpointId: endpointId,
        deviceName: 'Unknown Device',
      );
      device.connectionState = NearbyConnectionState.connected;
      
      _connectedDevices[endpointId] = device;
      _discoveredDevices.remove(endpointId);
      _notifyConnectedDevicesChange();
    }
    
    onConnectionResult?.call(endpointId, accepted);
  }
  
  void _onDisconnected(String endpointId) {
    _connectedDevices.remove(endpointId);
    _notifyConnectedDevicesChange();
    onDisconnected?.call(endpointId);
  }
  
  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      try {
        final json = utf8.decode(payload.bytes!);
        final data = jsonDecode(json) as Map<String, dynamic>;
        
        final type = data['type'] as String?;
        
        if (type == 'clipboard_item') {
          final itemData = data['data'] as Map<String, dynamic>;
          final item = ClipboardItem.fromFirestore(itemData, itemData['id'] ?? '');
          onItemReceived?.call(item);
        }
        // Handle other message types as needed
      } catch (e) {
        debugPrint('NearbyService: Failed to parse payload: $e');
      }
    }
  }
  
  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    if (update.totalBytes > 0) {
      final progress = update.bytesTransferred / update.totalBytes;
      onTransferProgress?.call(endpointId, progress);
    }
  }
  
  void _notifyConnectedDevicesChange() {
    _connectedDevicesController.add(_connectedDevices.values.toList());
  }
  
  /// Dispose resources
  void dispose() {
    stopAdvertising();
    stopDiscovery();
    disconnectAll();
    _connectedDevicesController.close();
  }
}

/// Singleton instance
final nearbyService = NearbyService.instance;
