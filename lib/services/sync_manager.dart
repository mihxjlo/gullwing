import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/clipboard_item.dart';
import '../models/connected_device.dart';
import 'nearby_service.dart';
import 'lan_service.dart';
import 'clipboard_repository.dart';
import 'offline_queue_service.dart';
import 'device_repository.dart';
import 'trusted_devices_service.dart';
import 'pairing_service.dart';
import 'discovery_service.dart';

/// Available sync routes in priority order
enum SyncRoute {
  nearby,   // Android ↔ Android (offline, fastest)
  lan,      // Web ↔ Android (same network)
  firebase, // Cloud fallback
  offline,  // No route available, queued locally
}

/// Sync result for tracking
class SyncResult {
  final bool success;
  final SyncRoute route;
  final String? errorMessage;
  
  SyncResult({
    required this.success,
    required this.route,
    this.errorMessage,
  });
}

/// Sync Manager - Central routing logic for clipboard sync
/// Automatically detects and selects the best available route
class SyncManager {
  static SyncManager? _instance;
  static SyncManager get instance => _instance ??= SyncManager._();
  
  SyncManager._();
  
  /// Services
  final NearbyService _nearbyService = nearbyService;
  final LanService _lanService = lanService;
  final OfflineQueueService _offlineQueue = offlineQueueService;
  final DiscoveryService _discoveryService = discoveryService;
  ClipboardRepository? _clipboardRepository;
  
  /// Connectivity
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _hasInternet = false;
  
  /// Current route
  SyncRoute _currentRoute = SyncRoute.offline;
  
  /// Stream controller for route changes
  final _routeController = StreamController<SyncRoute>.broadcast();
  Stream<SyncRoute> get routeChanges => _routeController.stream;
  
  /// Stream controller for received items
  final _receivedItemsController = StreamController<ClipboardItem>.broadcast();
  Stream<ClipboardItem> get receivedItems => _receivedItemsController.stream;
  
  /// Queue flush in progress
  bool _isFlushingQueue = false;
  
  /// Current device's LAN info (cached locally for immediate access)
  String? _currentDeviceLocalIp;
  int? _currentDeviceLanPort;
  
  /// Getters
  SyncRoute get currentRoute => _currentRoute;
  bool get hasRoute => _currentRoute != SyncRoute.offline;
  bool get isNearbyAvailable => _nearbyService.hasConnections;
  bool get isLanAvailable => _lanService.hasConnections;
  bool get isFirebaseAvailable => _hasInternet && (_clipboardRepository?.hasActiveSession ?? false);
  String? get currentDeviceLocalIp => _currentDeviceLocalIp;
  
  /// Initialize the sync manager
  Future<void> init({
    required String deviceId,
    required String deviceName,
    String? sessionId,
  }) async {
    // Initialize services
    await _offlineQueue.init();
    
    _nearbyService.init(
      deviceId: deviceId,
      deviceName: deviceName,
      sessionId: sessionId,
    );
    
    await _lanService.init(
      deviceId: deviceId,
      deviceName: deviceName,
      sessionId: sessionId,
    );
    
    // Initialize discovery service
    _discoveryService.initialize(
      deviceId: deviceId,
      deviceName: deviceName,
    );
    
    // Create clipboard repository
    _clipboardRepository = ClipboardRepository();
    
    // Setup connectivity monitoring
    _setupConnectivityMonitoring();
    
    // Setup item received callbacks
    _setupReceivedItemCallbacks();
    
    // Initial route detection
    await _detectRoute();
    
    // Start LAN server and UDP discovery immediately (session-less discovery)
    await _startLanServerForDiscovery();
    
    // Try to flush any queued items
    _tryFlushQueue();
  }
  
  /// Update session (when joining/leaving)
  Future<void> updateSession(String? sessionId) async {
    _nearbyService.updateSession(sessionId);
    _lanService.updateSession(sessionId);
    _discoveryService.updateSession(sessionId);
    
    if (sessionId != null) {
      // Session started - auto-start LAN server on Android
      await _autoStartLanServer();
    } else {
      // Session ended - stop LAN server
      await _lanService.stopServer();
    }
    
    _detectRoute();
  }
  
  /// Start LAN server and UDP discovery for session-less device discovery
  /// This allows devices to find each other before joining a session via code
  Future<void> _startLanServerForDiscovery() async {
    debugPrint('SyncManager: _startLanServerForDiscovery called (session-less mode)');
    
    if (!_lanService.canHostServer) {
      debugPrint('SyncManager: Cannot host server (Web platform), will only listen');
    } else {
      // Start WebSocket server to accept incoming connections
      debugPrint('SyncManager: Starting WebSocket server for discovery...');
      final started = await _lanService.startServer();
      debugPrint('SyncManager: Discovery server started=$started');
    }
    
    // Get local IP for UDP broadcasts
    final localIp = await _lanService.getLocalIpAddress();
    debugPrint('SyncManager: Discovery IP=$localIp');
    
    if (localIp != null) {
      // Cache locally
      _currentDeviceLocalIp = localIp;
      _currentDeviceLanPort = LanService.defaultPort;
      
      // Share IP with discovery service for UDP broadcasts
      _discoveryService.setLocalIp(localIp);
      
      // Start UDP broadcast for discovery (works on Android + Desktop)
      if (_discoveryService.canBroadcast) {
        await _discoveryService.startBroadcast();
        debugPrint('SyncManager: ✓ Started UDP discovery broadcast (session-less)');
      }
    } else {
      debugPrint('SyncManager: ✗ No local IP, UDP broadcast disabled');
    }
    
    // Always start listening for UDP discovery packets
    await _discoveryService.startListening();
    debugPrint('SyncManager: ✓ Started UDP discovery listening');
  }
  
  /// Auto-start LAN server on Android and publish IP to Firebase
  Future<void> _autoStartLanServer() async {
    debugPrint('SyncManager: _autoStartLanServer called');
    debugPrint('SyncManager: canHostServer=${_lanService.canHostServer}');
    
    if (!_lanService.canHostServer) {
      debugPrint('SyncManager: Cannot host server (Web platform), skipping');
      return;
    }
    
    // Start WebSocket server
    debugPrint('SyncManager: Starting WebSocket server...');
    final started = await _lanService.startServer();
    debugPrint('SyncManager: Server started=$started');
    
    if (!started) {
      debugPrint('SyncManager: Failed to start server, aborting IP publish');
      return;
    }
    
    // Get local IP and publish to Firebase
    debugPrint('SyncManager: Getting local IP address...');
    final localIp = await _lanService.getLocalIpAddress();
    debugPrint('SyncManager: Got localIp=$localIp');
    
    if (localIp != null) {
      debugPrint('SyncManager: Publishing IP to Firebase...');
      debugPrint('SyncManager: deviceId=${pairingService.deviceId}');
      debugPrint('SyncManager: sessionId=${pairingService.currentSessionId}');
      
      // Share IP with discovery service for UDP broadcasts
      _discoveryService.setLocalIp(localIp);
      
      // Cache locally for immediate access
      _currentDeviceLocalIp = localIp;
      _currentDeviceLanPort = LanService.defaultPort;
      
      // Register device first (ensures document exists), then update IP
      final deviceRepo = DeviceRepository();
      
      // Retry up to 3 times with delay (session might not be ready yet)
      for (int attempt = 1; attempt <= 3; attempt++) {
        debugPrint('SyncManager: Attempt $attempt to publish IP to Firebase...');
        
        if (pairingService.currentSessionId == null) {
          debugPrint('SyncManager: Session not ready yet, waiting 500ms...');
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        
        try {
          // First ensure device is registered
          await deviceRepo.registerCurrentDevice(
            localIp: localIp,
            lanPort: LanService.defaultPort,
          );
          debugPrint('SyncManager: ✓ Published LAN IP $localIp:${LanService.defaultPort} to Firebase');
          break;
        } catch (e) {
          debugPrint('SyncManager: ✗ Failed to publish IP (attempt $attempt): $e');
          if (attempt < 3) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
      
      // Start UDP broadcast for discovery
      if (_discoveryService.canBroadcast) {
        await _discoveryService.startBroadcast();
        debugPrint('SyncManager: ✓ Started UDP discovery broadcast');
      }
    } else {
      debugPrint('SyncManager: ✗ localIp is null, cannot publish to Firebase');
    }
    
    // Always start listening for discovery (even on Web)
    await _discoveryService.startListening();
  }
  
  /// Setup connectivity monitoring
  void _setupConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      _hasInternet = result == ConnectivityResult.wifi || 
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet;
      _detectRoute();
      
      // Try to flush queue when connection changes
      if (hasRoute) {
        _tryFlushQueue();
      }
    });
    
    // Initial check
    _connectivity.checkConnectivity().then((result) {
      _hasInternet = result == ConnectivityResult.wifi || 
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet;
    });
  }
  
  /// Setup callbacks for received items from local routes
  void _setupReceivedItemCallbacks() {
    // Nearby items
    _nearbyService.onItemReceived = (item) {
      _offlineQueue.markProcessed(item); // Prevent echo
      _receivedItemsController.add(item);
    };
    
    // LAN items
    _lanService.onItemReceived = (item, fromDeviceId) {
      _offlineQueue.markProcessed(item); // Prevent echo
      _receivedItemsController.add(item);
    };
  }
  
  /// Detect the best available route (priority order)
  Future<void> _detectRoute() async {
    final previousRoute = _currentRoute;
    
    // Priority 1: Nearby Connections (Android ↔ Android)
    if (_nearbyService.hasConnections) {
      _currentRoute = SyncRoute.nearby;
    }
    // Priority 2: LAN (same network)
    else if (_lanService.hasConnections) {
      _currentRoute = SyncRoute.lan;
    }
    // Priority 3: Firebase (online)
    else if (_hasInternet && (_clipboardRepository?.hasActiveSession ?? false)) {
      _currentRoute = SyncRoute.firebase;
    }
    // No route available
    else {
      _currentRoute = SyncRoute.offline;
    }
    
    if (_currentRoute != previousRoute) {
      debugPrint('SyncManager: Route changed from $previousRoute to $_currentRoute');
      _routeController.add(_currentRoute);
    }
  }
  
  /// Sync a clipboard item through the best available route
  Future<SyncResult> syncItem(ClipboardItem item) async {
    // Check for duplicates
    if (_offlineQueue.wasProcessed(item)) {
      return SyncResult(
        success: true,
        route: _currentRoute,
        errorMessage: 'Already processed',
      );
    }
    
    // Update route detection
    await _detectRoute();
    
    try {
      switch (_currentRoute) {
        case SyncRoute.nearby:
          await _nearbyService.broadcastClipboardItem(item);
          // Also sync to Firebase for persistence
          if (_hasInternet) {
            await _clipboardRepository?.addClipboardItem(item);
          }
          _offlineQueue.markProcessed(item);
          return SyncResult(success: true, route: SyncRoute.nearby);
          
        case SyncRoute.lan:
          await _lanService.broadcastClipboardItem(item);
          // Also sync to Firebase for persistence
          if (_hasInternet) {
            await _clipboardRepository?.addClipboardItem(item);
          }
          _offlineQueue.markProcessed(item);
          return SyncResult(success: true, route: SyncRoute.lan);
          
        case SyncRoute.firebase:
          await _clipboardRepository?.addClipboardItem(item);
          _offlineQueue.markProcessed(item);
          return SyncResult(success: true, route: SyncRoute.firebase);
          
        case SyncRoute.offline:
          await _offlineQueue.enqueue(item);
          return SyncResult(success: false, route: SyncRoute.offline);
      }
    } catch (e) {
      debugPrint('SyncManager: Sync failed: $e');
      // Queue for later
      await _offlineQueue.enqueue(item);
      return SyncResult(
        success: false,
        route: _currentRoute,
        errorMessage: e.toString(),
      );
    }
  }
  
  /// Broadcast an item to all local connections (for multi-device)
  Future<void> broadcastToLocalDevices(ClipboardItem item) async {
    if (_nearbyService.hasConnections) {
      await _nearbyService.broadcastClipboardItem(item);
    }
    if (_lanService.hasConnections) {
      await _lanService.broadcastClipboardItem(item);
    }
  }
  
  /// Flush queued items when route becomes available
  Future<void> _tryFlushQueue() async {
    if (_isFlushingQueue || !hasRoute || _offlineQueue.isEmpty) return;
    
    _isFlushingQueue = true;
    
    try {
      while (!_offlineQueue.isEmpty && hasRoute) {
        final queuedItem = await _offlineQueue.dequeue();
        if (queuedItem == null) break;
        
        final result = await syncItem(queuedItem.item);
        
        if (!result.success) {
          // Re-queue with retry count
          await _offlineQueue.requeue(queuedItem);
          break; // Stop if we can't sync
        }
      }
    } finally {
      _isFlushingQueue = false;
    }
  }
  
  /// Force flush queue (manual trigger)
  Future<void> flushQueue() async {
    await _tryFlushQueue();
  }
  
  /// Get human-readable route name for UI
  String get currentRouteName {
    switch (_currentRoute) {
      case SyncRoute.nearby:
        return 'Nearby';
      case SyncRoute.lan:
        return 'Local Network';
      case SyncRoute.firebase:
        return 'Cloud';
      case SyncRoute.offline:
        return 'Offline';
    }
  }
  
  /// Start Nearby Connections (Android only)
  Future<bool> startNearby() async {
    if (!NearbyService.isSupported) return false;
    
    final hasPermissions = await _nearbyService.requestPermissions();
    if (!hasPermissions) return false;
    
    final advertising = await _nearbyService.startAdvertising();
    final discovery = await _nearbyService.startDiscovery();
    
    return advertising || discovery;
  }
  
  /// Stop Nearby Connections
  Future<void> stopNearby() async {
    await _nearbyService.stopAdvertising();
    await _nearbyService.stopDiscovery();
    await _nearbyService.disconnectAll();
    _detectRoute();
  }
  
  /// Start LAN server (Android only)
  Future<bool> startLanServer() async {
    if (!_lanService.canHostServer) return false;
    return await _lanService.startServer();
  }
  
  /// Stop LAN server
  Future<void> stopLanServer() async {
    await _lanService.stopServer();
    _detectRoute();
  }
  
  /// Connect to LAN device (Web)
  Future<bool> connectToLanDevice(LanDevice device) async {
    final success = await _lanService.connectToDevice(device);
    if (success) {
      _detectRoute();
    }
    return success;
  }
  
  /// Probe a LAN device to check availability (smart promotion)
  Future<bool> probeLanDevice(ConnectedDevice device) async {
    if (device.localIp == null || device.lanPort == null) return false;
    
    final lanDevice = LanDevice(
      deviceId: device.id,
      deviceName: device.name,
      ipAddress: device.localIp!,
      port: device.lanPort!,
    );
    
    // Check if already trusted (sync method, no await needed)
    final isTrusted = trustedDevicesService.isTrusted(device.id);
    
    // Attempt connection (trusted devices auto-accept on server side)
    final success = await _lanService.connectToDevice(lanDevice);
    
    if (success && !isTrusted) {
      // Mark as trusted for future auto-connect
      await trustedDevicesService.addTrustedDevice(
        deviceId: device.id,
        deviceName: device.name,
        lastKnownIp: device.localIp,
      );
      debugPrint('SyncManager: Promoted ${device.name} to LAN and added to trusted');
    }
    
    if (success) {
      _detectRoute();
    }
    
    return success;
  }
  
  /// Probe all session devices for LAN availability
  /// Now uses "Blind Broadcast" - discovers devices via UDP first,
  /// then falls back to Firebase repository for session devices.
  Future<void> probeAllDevicesForLan() async {
    debugPrint('SyncManager: probeAllDevicesForLan called (Blind Broadcast mode)');
    
    // ========================================
    // Step 1: Probe UDP-discovered devices (works without session!)
    // ========================================
    final udpDevices = _discoveryService.currentDiscoveredDevices;
    debugPrint('SyncManager: Found ${udpDevices.length} devices via UDP broadcast');
    
    for (final device in udpDevices) {
      debugPrint('SyncManager: UDP Device "${device.deviceName}" at ${device.ipAddress}:${device.wsPort}');
      
      // Convert DiscoveredDevice to ConnectedDevice for probing
      final connectedDevice = ConnectedDevice(
        id: device.deviceId,
        name: device.deviceName,
        type: DeviceType.android, // UDP discovery only from Android devices
        status: DeviceStatus.active,
        lastSeen: DateTime.now(),
        isCurrentDevice: false,
        localIp: device.ipAddress,
        lanPort: device.wsPort,
      );
      
      debugPrint('SyncManager: Probing UDP device "${device.deviceName}"...');
      final success = await probeLanDevice(connectedDevice);
      debugPrint('SyncManager: UDP Probe result for "${device.deviceName}": ${success ? "SUCCESS" : "FAILED"}');
    }
    
    // ========================================
    // Step 2: Also check Firebase repository (for session devices)
    // ========================================
    if (!_hasInternet) {
      debugPrint('SyncManager: No internet, skipping Firebase device check');
      return;
    }
    
    final deviceRepo = DeviceRepository();
    
    // Retry up to 3 times with 2-second delay if no devices have LAN info
    // This handles Firestore write propagation delay
    List<ConnectedDevice> devices = [];
    bool hasAnyLanInfo = false;
    
    for (int attempt = 1; attempt <= 3; attempt++) {
      devices = await deviceRepo.getDevices();
      debugPrint('SyncManager: Firebase attempt $attempt - Found ${devices.length} session devices');
      
      // Check if any OTHER device has LAN info
      hasAnyLanInfo = devices.any((d) => !d.isCurrentDevice && d.hasLanInfo);
      
      if (hasAnyLanInfo || devices.isEmpty) {
        break; // We have LAN info or no devices to check
      }
      
      if (attempt < 3) {
        debugPrint('SyncManager: No LAN info found, waiting 2s before retry...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    
    debugPrint('SyncManager: Final Firebase device count: ${devices.length}, hasAnyLanInfo: $hasAnyLanInfo');
    
    // Get IDs of devices already probed via UDP to avoid duplicates
    final udpDeviceIds = udpDevices.map((d) => d.deviceId).toSet();
    
    for (final device in devices) {
      // Skip if already probed via UDP
      if (udpDeviceIds.contains(device.id)) {
        debugPrint('SyncManager: Skipping "${device.name}" - already probed via UDP');
        continue;
      }
      
      // Show cached IP for current device (for debugging)
      final localIp = device.isCurrentDevice ? (device.localIp ?? _currentDeviceLocalIp) : device.localIp;
      final lanPort = device.isCurrentDevice ? (device.lanPort ?? _currentDeviceLanPort) : device.lanPort;
      
      debugPrint('SyncManager: Firebase Device "${device.name}" - isCurrentDevice=${device.isCurrentDevice}, localIp=$localIp, lanPort=$lanPort');
      
      if (device.isCurrentDevice) {
        debugPrint('SyncManager: Skipping current device');
        continue;
      }
      if (!device.hasLanInfo) {
        debugPrint('SyncManager: Device "${device.name}" has no LAN info, skipping');
        continue;
      }
      
      debugPrint('SyncManager: Probing Firebase device "${device.name}" at ${device.localIp}:${device.lanPort}');
      final success = await probeLanDevice(device);
      debugPrint('SyncManager: Firebase Probe result for "${device.name}": ${success ? "SUCCESS" : "FAILED"}');
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _routeController.close();
    await _receivedItemsController.close();
    _nearbyService.dispose();  // Returns void, don't await
    await _lanService.dispose();
    await _offlineQueue.dispose();
  }
}

/// Global instance
final syncManager = SyncManager.instance;
