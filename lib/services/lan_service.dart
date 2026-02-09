import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/clipboard_item.dart';

/// Connection state for LAN devices
enum LanConnectionState {
  disconnected,
  connecting,
  connected,
}

/// Represents a device on the local network
class LanDevice {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  final int port;
  LanConnectionState connectionState;

  LanDevice({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.port,
    this.connectionState = LanConnectionState.disconnected,
  });
  
  String get wsUrl => 'ws://$ipAddress:$port';
  
  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'ipAddress': ipAddress,
    'port': port,
  };
  
  factory LanDevice.fromJson(Map<String, dynamic> json) => LanDevice(
    deviceId: json['deviceId'] ?? '',
    deviceName: json['deviceName'] ?? 'Unknown',
    ipAddress: json['ipAddress'] ?? '',
    port: json['port'] ?? 8765,
  );
}

/// Callback types
typedef OnLanItemReceived = void Function(ClipboardItem item, String fromDeviceId);
typedef OnLanConnectionRequest = void Function(LanDevice device);
typedef OnLanConnected = void Function(LanDevice device);
typedef OnLanDisconnected = void Function(String deviceId);

/// Service for LAN sync via WebSocket
/// Android hosts server, Web connects as client
/// Uses Firebase to share IP addresses
class LanService {
  static LanService? _instance;
  static LanService get instance => _instance ??= LanService._();
  
  LanService._();
  
  /// Default port for WebSocket server
  static const int defaultPort = 8765;
  
  /// Device info
  String _deviceId = '';
  String _deviceName = '';
  String? _sessionId;
  
  /// WebSocket server (Android only)
  HttpServer? _server;
  bool _isServerRunning = false;
  
  /// Connected WebSocket channels (as server)
  final Map<String, WebSocketChannel> _serverConnections = {};
  
  /// WebSocket client connection (Web to Android)
  WebSocketChannel? _clientConnection;
  String? _connectedToDeviceId;
  
  /// Pending connection requests
  final Map<String, LanDevice> _pendingRequests = {};
  
  /// Trusted devices that can auto-connect
  final Set<String> _trustedDeviceIds = {};
  
  /// Callbacks
  OnLanItemReceived? onItemReceived;
  OnLanConnectionRequest? onConnectionRequest;
  OnLanConnected? onConnected;
  OnLanDisconnected? onDisconnected;
  
  /// Connected devices stream
  final _connectedDevicesController = StreamController<List<LanDevice>>.broadcast();
  Stream<List<LanDevice>> get connectedDevicesStream => _connectedDevicesController.stream;
  
  /// Connected devices list
  final List<LanDevice> _connectedDevices = [];
  List<LanDevice> get connectedDevices => List.unmodifiable(_connectedDevices);
  
  /// Getters
  bool get isServerRunning => _isServerRunning;
  bool get hasConnections => _serverConnections.isNotEmpty || _clientConnection != null;
  bool get isWeb => kIsWeb;
  bool get canHostServer => !kIsWeb;
  
  /// Initialize the service
  Future<void> init({
    required String deviceId,
    required String deviceName,
    String? sessionId,
    Set<String>? trustedDeviceIds,
  }) async {
    _deviceId = deviceId;
    _deviceName = deviceName;
    _sessionId = sessionId;
    if (trustedDeviceIds != null) {
      _trustedDeviceIds.addAll(trustedDeviceIds);
    }
  }
  
  /// Update session ID
  void updateSession(String? sessionId) {
    _sessionId = sessionId;
  }
  
  /// Add a trusted device (can auto-connect without prompt)
  void addTrustedDevice(String deviceId) {
    _trustedDeviceIds.add(deviceId);
  }
  
  /// Remove a trusted device
  void removeTrustedDevice(String deviceId) {
    _trustedDeviceIds.remove(deviceId);
  }
  
  /// Check if device is trusted
  bool isTrusted(String deviceId) {
    return _trustedDeviceIds.contains(deviceId);
  }
  
  /// Get local IP address (for Firebase sharing)
  /// Uses multiple methods with fallback for reliability
  Future<String?> getLocalIpAddress() async {
    if (kIsWeb) {
      debugPrint('LanService: getLocalIpAddress - Web platform, returning null');
      return null;
    }
    
    debugPrint('LanService: getLocalIpAddress - Starting IP detection...');
    
    // Detect if we're on desktop (Windows/macOS/Linux)
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    
    // Method 1: Try NetworkInfo plugin (only on mobile - fails on desktop)
    if (!isDesktop) {
      try {
        final info = NetworkInfo();
        final wifiIP = await info.getWifiIP();
        debugPrint('LanService: NetworkInfo.getWifiIP() returned: $wifiIP');
        
        if (wifiIP != null && wifiIP.isNotEmpty && wifiIP != '0.0.0.0') {
          debugPrint('LanService: ✓ Using WiFi IP: $wifiIP');
          return wifiIP;
        }
      } catch (e) {
        debugPrint('LanService: NetworkInfo failed: $e');
      }
    } else {
      debugPrint('LanService: Skipping NetworkInfo plugin on desktop (known to fail)');
    }
    
    // Method 2: NetworkInterface scan (primary method for desktop)
    debugPrint('LanService: Scanning NetworkInterface.list()...');
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      
      debugPrint('LanService: Found ${interfaces.length} network interfaces');
      
      // Helper to check if interface is virtual (Windows)
      bool isVirtualInterface(String name) {
        final lowerName = name.toLowerCase();
        return lowerName.contains('hyper-v') ||
               lowerName.contains('vmware') ||
               lowerName.contains('virtualbox') ||
               lowerName.contains('vethernet') ||
               lowerName.contains('docker') ||
               lowerName.contains('wsl') ||
               lowerName.contains('loopback');
      }
      
      // First pass: prefer physical interfaces (Wi-Fi, Ethernet) with 192.168.x.x
      for (var interface in interfaces) {
        final ifName = interface.name;
        debugPrint('LanService: Interface "$ifName": ${interface.addresses.map((a) => a.address).join(", ")}');
        
        // Skip virtual interfaces on Windows
        if (Platform.isWindows && isVirtualInterface(ifName)) {
          debugPrint('LanService: Skipping virtual interface: $ifName');
          continue;
        }
        
        for (var addr in interface.addresses) {
          final ip = addr.address;
          
          // Skip loopback and link-local
          if (addr.isLoopback) continue;
          if (ip.startsWith('127.')) continue;
          if (ip.startsWith('169.254.')) continue; // Link-local
          
          // Strongly prefer 192.168.x.x (real home/office WiFi)
          if (ip.startsWith('192.168.')) {
            debugPrint('LanService: ✓ Using WiFi IP (192.168.x.x): $ip from interface "$ifName"');
            return ip;
          }
        }
      }
      
      // Second pass: accept other private ranges (10.x.x.x, 172.x.x.x)
      // Note: 10.0.2.x is Android emulator, acceptable for testing
      for (var interface in interfaces) {
        if (Platform.isWindows && isVirtualInterface(interface.name)) continue;
        
        for (var addr in interface.addresses) {
          final ip = addr.address;
          
          if (addr.isLoopback) continue;
          if (ip.startsWith('127.')) continue;
          if (ip.startsWith('169.254.')) continue;
          
          if (ip.startsWith('10.') || ip.startsWith('172.')) {
            debugPrint('LanService: ✓ Using private range IP: $ip from interface "${interface.name}"');
            return ip;
          }
        }
      }
      
      // Last resort: use any non-loopback IPv4 (even from virtual interfaces)
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            debugPrint('LanService: ✓ Using fallback IP: ${addr.address} from interface "${interface.name}"');
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('LanService: NetworkInterface scan failed: $e');
    }
    
    debugPrint('LanService: ✗ No valid IP found');
    return null;
  }

  
  // ============ Server Methods (Android) ============
  
  /// Start WebSocket server (Android only)
  Future<bool> startServer({int port = defaultPort}) async {
    if (kIsWeb || _isServerRunning) return false;
    
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isServerRunning = true;
      
      debugPrint('LanService: Server started on port $port');
      
      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleNewConnection(socket);
        }
      });
      
      return true;
    } catch (e) {
      debugPrint('LanService: Failed to start server: $e');
      return false;
    }
  }
  
  /// Stop WebSocket server
  Future<void> stopServer() async {
    if (!_isServerRunning) return;
    
    // Close all connections
    for (final channel in _serverConnections.values) {
      await channel.sink.close();
    }
    _serverConnections.clear();
    
    await _server?.close();
    _server = null;
    _isServerRunning = false;
    
    _connectedDevices.clear();
    _notifyConnectedDevicesChange();
    
    debugPrint('LanService: Server stopped');
  }
  
  /// Handle new incoming WebSocket connection
  void _handleNewConnection(WebSocket socket) {
    final channel = IOWebSocketChannel(socket);
    String? remoteDeviceId;
    
    channel.stream.listen(
      (message) {
        final data = _parseMessage(message);
        if (data == null) return;
        
        final type = data['type'] as String?;
        
        switch (type) {
          case 'handshake':
            remoteDeviceId = data['deviceId'] as String?;
            final remoteName = data['deviceName'] as String? ?? 'Unknown';
            final remoteSession = data['sessionId'] as String?;
            // Note: Getting remote IP is not directly available from WebSocket
            // Use a placeholder or rely on handshake data
            const remoteIp = 'unknown';
            
            // Validate session
            if (remoteSession != _sessionId) {
              _sendMessage(channel, {
                'type': 'handshake_reject',
                'reason': 'Session mismatch',
              });
              channel.sink.close();
              return;
            }
            
            final device = LanDevice(
              deviceId: remoteDeviceId!,
              deviceName: remoteName,
              ipAddress: remoteIp,
              port: defaultPort,
              connectionState: LanConnectionState.connecting,
            );
            
            // Check if trusted or prompt user
            if (isTrusted(remoteDeviceId!)) {
              _acceptServerConnection(channel, device);
            } else {
              _pendingRequests[remoteDeviceId!] = device;
              _serverConnections[remoteDeviceId!] = channel;
              onConnectionRequest?.call(device);
            }
            break;
            
          case 'clipboard_item':
            if (remoteDeviceId != null) {
              final itemData = data['data'] as Map<String, dynamic>;
              final item = ClipboardItem.fromFirestore(itemData, itemData['id'] ?? '');
              onItemReceived?.call(item, remoteDeviceId!);
            }
            break;
        }
      },
      onDone: () {
        if (remoteDeviceId != null) {
          _serverConnections.remove(remoteDeviceId);
          _connectedDevices.removeWhere((d) => d.deviceId == remoteDeviceId);
          _notifyConnectedDevicesChange();
          onDisconnected?.call(remoteDeviceId!);
        }
      },
      onError: (error) {
        debugPrint('LanService: Connection error: $error');
      },
    );
  }
  
  /// Accept a pending connection request
  void acceptConnectionRequest(String deviceId) {
    final device = _pendingRequests.remove(deviceId);
    final channel = _serverConnections[deviceId];
    
    if (device != null && channel != null) {
      _acceptServerConnection(channel, device);
    }
  }
  
  /// Reject a pending connection request
  void rejectConnectionRequest(String deviceId) {
    final channel = _serverConnections.remove(deviceId);
    _pendingRequests.remove(deviceId);
    
    if (channel != null) {
      _sendMessage(channel, {
        'type': 'handshake_reject',
        'reason': 'User rejected',
      });
      channel.sink.close();
    }
  }
  
  void _acceptServerConnection(WebSocketChannel channel, LanDevice device) {
    device.connectionState = LanConnectionState.connected;
    _connectedDevices.add(device);
    _serverConnections[device.deviceId] = channel;
    
    // Send acceptance
    _sendMessage(channel, {
      'type': 'handshake_accept',
      'deviceId': _deviceId,
      'deviceName': _deviceName,
    });
    
    _notifyConnectedDevicesChange();
    onConnected?.call(device);
  }
  
  // ============ Client Methods (Web) ============
  
  /// Connect to a LAN device (usually Android hosting server)
  Future<bool> connectToDevice(LanDevice device) async {
    try {
      final channel = WebSocketChannel.connect(Uri.parse(device.wsUrl));
      _clientConnection = channel;
      _connectedToDeviceId = device.deviceId;
      
      // Send handshake
      _sendMessage(channel, {
        'type': 'handshake',
        'deviceId': _deviceId,
        'deviceName': _deviceName,
        'sessionId': _sessionId,
      });
      
      // Listen for messages
      channel.stream.listen(
        (message) {
          final data = _parseMessage(message);
          if (data == null) return;
          
          final type = data['type'] as String?;
          
          switch (type) {
            case 'handshake_accept':
              device.connectionState = LanConnectionState.connected;
              _connectedDevices.add(device);
              _notifyConnectedDevicesChange();
              onConnected?.call(device);
              break;
              
            case 'handshake_reject':
              _clientConnection = null;
              _connectedToDeviceId = null;
              debugPrint('LanService: Connection rejected: ${data['reason']}');
              break;
              
            case 'clipboard_item':
              final itemData = data['data'] as Map<String, dynamic>;
              final item = ClipboardItem.fromFirestore(itemData, itemData['id'] ?? '');
              onItemReceived?.call(item, device.deviceId);
              break;
          }
        },
        onDone: () {
          _clientConnection = null;
          _connectedDevices.removeWhere((d) => d.deviceId == device.deviceId);
          _notifyConnectedDevicesChange();
          onDisconnected?.call(device.deviceId);
        },
        onError: (error) {
          debugPrint('LanService: Client connection error: $error');
        },
      );
      
      return true;
    } catch (e) {
      debugPrint('LanService: Failed to connect to device: $e');
      return false;
    }
  }
  
  /// Disconnect from current server
  Future<void> disconnectFromServer() async {
    if (_clientConnection != null) {
      await _clientConnection!.sink.close();
      _clientConnection = null;
      
      if (_connectedToDeviceId != null) {
        _connectedDevices.removeWhere((d) => d.deviceId == _connectedToDeviceId);
        onDisconnected?.call(_connectedToDeviceId!);
        _connectedToDeviceId = null;
      }
      
      _notifyConnectedDevicesChange();
    }
  }
  
  // ============ Data Transfer ============
  
  /// Broadcast clipboard item to all connected devices
  Future<void> broadcastClipboardItem(ClipboardItem item) async {
    final message = {
      'type': 'clipboard_item',
      'data': item.toFirestore(),
    };
    
    // Send to all server connections
    for (final channel in _serverConnections.values) {
      _sendMessage(channel, message);
    }
    
    // Send to client connection
    if (_clientConnection != null) {
      _sendMessage(_clientConnection!, message);
    }
  }
  
  /// Send item to specific device
  Future<bool> sendClipboardItem(ClipboardItem item, String deviceId) async {
    final channel = _serverConnections[deviceId];
    if (channel != null) {
      _sendMessage(channel, {
        'type': 'clipboard_item',
        'data': item.toFirestore(),
      });
      return true;
    }
    
    if (_connectedToDeviceId == deviceId && _clientConnection != null) {
      _sendMessage(_clientConnection!, {
        'type': 'clipboard_item',
        'data': item.toFirestore(),
      });
      return true;
    }
    
    return false;
  }
  
  // ============ Helpers ============
  
  void _sendMessage(WebSocketChannel channel, Map<String, dynamic> data) {
    channel.sink.add(jsonEncode(data));
  }
  
  Map<String, dynamic>? _parseMessage(dynamic message) {
    try {
      if (message is String) {
        return jsonDecode(message) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('LanService: Failed to parse message: $e');
      return null;
    }
  }
  
  void _notifyConnectedDevicesChange() {
    _connectedDevicesController.add(List.unmodifiable(_connectedDevices));
  }
  
  /// Disconnect all and cleanup
  Future<void> dispose() async {
    await stopServer();
    await disconnectFromServer();
    await _connectedDevicesController.close();
  }
}

/// Singleton instance
final lanService = LanService.instance;
