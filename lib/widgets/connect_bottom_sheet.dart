import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../blocs/pairing/pairing.dart';
import '../services/sync_manager.dart';
import '../services/nearby_service.dart';
import '../services/discovery_service.dart';
import '../services/pairing_service.dart';
import '../models/connected_device.dart';
import 'pulsing_radar.dart';

/// Unified Connect Bottom Sheet for LAN + Nearby discovery
/// Automatically switches modes based on network connectivity
class ConnectBottomSheet extends StatefulWidget {
  const ConnectBottomSheet({super.key});

  @override
  State<ConnectBottomSheet> createState() => _ConnectBottomSheetState();

  /// Show the connect bottom sheet
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ConnectBottomSheet(),
    );
  }
}

class _ConnectBottomSheetState extends State<ConnectBottomSheet> {
  // Connectivity state
  bool _isOnWifi = false;
  bool _isChecking = true;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // LAN discovery state
  List<DiscoveredDevice> _lanDevices = [];
  bool _isProbing = false;
  Timer? _lanRefreshTimer;
  StreamSubscription<List<DiscoveredDevice>>? _lanDevicesSubscription;

  // Nearby state
  bool _isNearbyScanning = false;
  List<NearbyDevice> _nearbyDevices = [];
  StreamSubscription<List<NearbyDevice>>? _nearbyDevicesSubscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _lanRefreshTimer?.cancel();
    _lanDevicesSubscription?.cancel();
    _nearbyDevicesSubscription?.cancel();
    super.dispose();
  }

  void _setupListeners() {
    // Listen to LAN discovered devices (via UDP broadcast)
    _lanDevicesSubscription = discoveryService.discoveredDevices.listen((devices) {
      if (mounted) {
        setState(() => _lanDevices = devices);
      }
    });

    // Listen to Nearby discovered devices
    _nearbyDevicesSubscription = nearbyService.connectedDevicesStream.listen((devices) {
      if (mounted) {
        setState(() => _nearbyDevices = devices);
      }
    });

    // Also get Nearby discovered (not yet connected) devices via callback
    nearbyService.onDeviceDiscovered = (device) {
      if (mounted) {
        setState(() {
          // Add to nearby devices if not already present
          final exists = _nearbyDevices.any((d) => d.endpointId == device.endpointId);
          if (!exists) {
            _nearbyDevices = [..._nearbyDevices, device];
          }
        });
      }
    };

    nearbyService.onDeviceLost = (endpointId) {
      if (mounted) {
        setState(() {
          _nearbyDevices = _nearbyDevices.where((d) => d.endpointId != endpointId).toList();
        });
      }
    };
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOnWifi = result == ConnectivityResult.wifi;
      _isChecking = false;
    });

    // Auto-start LAN discovery if on WiFi
    if (_isOnWifi) {
      _startLanDiscovery();
    }

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final wasOnWifi = _isOnWifi;
      setState(() {
        _isOnWifi = result == ConnectivityResult.wifi;
      });

      // Switch modes on connectivity change
      if (_isOnWifi && !wasOnWifi) {
        _stopNearbyDiscovery();
        _startLanDiscovery();
      } else if (!_isOnWifi && wasOnWifi) {
        _stopLanDiscovery();
      }
    });
  }

  // ============ LAN Discovery ============

  Future<void> _startLanDiscovery() async {
    if (_isProbing) return;

    if (mounted) setState(() => _isProbing = true);

    // Probe all devices for LAN availability
    await syncManager.probeAllDevicesForLan();

    // Get current LAN devices from UDP discovery
    if (mounted) {
      setState(() {
        _lanDevices = discoveryService.currentDiscoveredDevices;
        _isProbing = false;
      });
    }

    // Auto-refresh every 5 seconds
    _lanRefreshTimer?.cancel();
    _lanRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await syncManager.probeAllDevicesForLan();
      if (mounted) {
        setState(() {
          _lanDevices = discoveryService.currentDiscoveredDevices;
        });
      }
    });
  }

  void _stopLanDiscovery() {
    _lanRefreshTimer?.cancel();
    _lanRefreshTimer = null;
    setState(() {
      _lanDevices = [];
      _isProbing = false;
    });
  }

  Future<void> _connectToLanDevice(DiscoveredDevice device) async {
    // Show connecting state
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Creating session and inviting ${device.deviceName}...')),
    );

    try {
      // Step 1: Create a new session (this device becomes host)
      final pairingBloc = context.read<PairingBloc>();
      
      // If already in a session, use that session
      if (!pairingService.isInSession) {
        pairingBloc.add(const PairingSessionCreated());
        
        // Wait for session to be created (give it a moment)
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      
      // Step 2: Get the current session
      final session = await pairingService.getCurrentSession();
      if (session == null) {
        throw Exception('Failed to create session');
      }
      
      // Step 3: Send UDP invitation to the discovered device
      final inviteSent = await discoveryService.sendInvitation(
        targetIp: device.ipAddress,
        sessionId: session.id,
      );
      
      if (!inviteSent) {
        throw Exception('Failed to send invitation');
      }
      
      // Step 4: Now probe and connect via WebSocket
      final connectedDevice = ConnectedDevice(
        id: device.deviceId,
        name: device.deviceName,
        type: DeviceType.android,
        status: DeviceStatus.active,
        lastSeen: DateTime.now(),
        isCurrentDevice: false,
        localIp: device.ipAddress,
        lanPort: device.wsPort,
      );

      final probeSuccess = await syncManager.probeLanDevice(connectedDevice);

      if (mounted) {
        if (probeSuccess) {
          Navigator.of(context).pop(); // Close sheet on success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${device.deviceName} via LAN! Session code: ${session.pairingCode}'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          // Probe failed but invitation sent - device may join via code
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invitation sent to ${device.deviceName}. They can join with code: ${session.pairingCode}'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ============ Nearby Discovery ============

  Future<void> _startNearbyDiscovery() async {
    // Check platform support
    if (!NearbyService.isSupported) {
      _showError('Nearby Connections is only supported on Android');
      return;
    }

    // Request permissions
    final hasPermissions = await _requestNearbyPermissions();
    if (!hasPermissions) {
      _showError('Nearby permissions are required');
      return;
    }

    setState(() => _isNearbyScanning = true);

    // Start advertising and discovery
    final started = await syncManager.startNearby();

    if (!started && mounted) {
      setState(() => _isNearbyScanning = false);
      _showError('Failed to start Nearby scanning');
    }
  }

  Future<bool> _requestNearbyPermissions() async {
    // Location permission (required for Nearby)
    var locationStatus = await Permission.locationWhenInUse.status;
    if (!locationStatus.isGranted) {
      locationStatus = await Permission.locationWhenInUse.request();
    }
    if (!locationStatus.isGranted) return false;

    // Bluetooth permissions (Android 12+)
    if (!kIsWeb) {
      var bluetoothScan = await Permission.bluetoothScan.status;
      if (!bluetoothScan.isGranted) {
        bluetoothScan = await Permission.bluetoothScan.request();
      }

      var bluetoothConnect = await Permission.bluetoothConnect.status;
      if (!bluetoothConnect.isGranted) {
        bluetoothConnect = await Permission.bluetoothConnect.request();
      }

      var bluetoothAdvertise = await Permission.bluetoothAdvertise.status;
      if (!bluetoothAdvertise.isGranted) {
        bluetoothAdvertise = await Permission.bluetoothAdvertise.request();
      }

      // Nearby WiFi devices (Android 13+)
      var nearbyWifi = await Permission.nearbyWifiDevices.status;
      if (!nearbyWifi.isGranted) {
        nearbyWifi = await Permission.nearbyWifiDevices.request();
      }
    }

    return true;
  }

  void _stopNearbyDiscovery() {
    syncManager.stopNearby();
    setState(() {
      _isNearbyScanning = false;
      _nearbyDevices = [];
    });
  }

  Future<void> _connectToNearbyDevice(NearbyDevice device) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Requesting connection to ${device.name}...')),
    );

    final success = await nearbyService.requestConnection(device.endpointId);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to ${device.name}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    // Connection result handled via callback - sheet closes on success
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.devices,
                      color: AppColors.primaryAccent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Connect to Devices',
                      style: AppTypography.sectionHeader,
                    ),
                    const Spacer(),
                    // Connection mode indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _isOnWifi
                            ? AppColors.success.withOpacity(0.2)
                            : AppColors.warning.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isOnWifi ? Icons.wifi : Icons.bluetooth,
                            size: 14,
                            color: _isOnWifi
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isOnWifi ? 'LAN' : 'Nearby',
                            style: AppTypography.metadata.copyWith(
                              color: _isOnWifi
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: _isChecking
                    ? const Center(child: CircularProgressIndicator())
                    : _isOnWifi
                        ? _buildLanMode(scrollController)
                        : _buildNearbyMode(scrollController),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============ LAN Mode UI ============

  Widget _buildLanMode(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Pulsing radar animation during scanning
        if (_isProbing) ...[
          Center(
            child: PulsingRadar(
              isActive: true,
              size: 180,
              color: AppColors.success, // Green for Wi-Fi/LAN
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi,
                  color: AppColors.success,
                  size: 30,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Scanning local network...',
              style: AppTypography.metadata,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isProbing = false;
                });
              },
              child: const Text('Stop Scanning'),
            ),
          ),
          const SizedBox(height: 24),
        ] else ...[
          // Status row (when not actively scanning)
          Row(
            children: [
              Text(
                '${_lanDevices.length} device(s) found',
                style: AppTypography.metadata,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _startLanDiscovery,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Device list
        if (_lanDevices.isEmpty && !_isProbing)
          _buildEmptyState(
            icon: Icons.wifi_find,
            message: 'No devices found on local network',
            submessage: 'Make sure other devices have ClipSync open',
          )
        else if (!_isProbing || _lanDevices.isNotEmpty)
          ..._lanDevices.map((device) => _buildLanDeviceTile(device)),
      ],
    );
  }

  Widget _buildLanDeviceTile(DiscoveredDevice device) {
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.wifi,
            color: AppColors.success,
            size: 20,
          ),
        ),
        title: Text(device.deviceName, style: AppTypography.bodyText),
        subtitle: Text(
          device.ipAddress,
          style: AppTypography.metadata,
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.secondaryText,
        ),
        onTap: () => _connectToLanDevice(device),
      ),
    );
  }

  // ============ Nearby Mode UI ============

  Widget _buildNearbyMode(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        if (!_isNearbyScanning) ...[
          // Inactive state - show start button
          const SizedBox(height: 40),
          Center(
            child: PulsingRadar(
              isActive: false,
              size: 200,
              child: ElevatedButton.icon(
                onPressed: _startNearbyDiscovery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Start Nearby Scan'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Find nearby Android devices\nfor offline clipboard sharing',
              textAlign: TextAlign.center,
              style: AppTypography.metadata,
            ),
          ),
        ] else ...[
          // Active scanning state
          Center(
            child: PulsingRadar(
              isActive: true,
              size: 180,
              color: const Color(0xFF22D3EE),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF22D3EE).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bluetooth_searching,
                  color: Color(0xFF22D3EE),
                  size: 30,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Scanning for nearby devices...',
              style: AppTypography.metadata,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _stopNearbyDiscovery,
              child: const Text('Stop Scanning'),
            ),
          ),
          const SizedBox(height: 24),

          // Nearby devices list
          if (_nearbyDevices.isEmpty)
            _buildEmptyState(
              icon: Icons.bluetooth_disabled,
              message: 'No nearby devices found',
              submessage: 'Make sure other devices are scanning too',
            )
          else ...[
            Text(
              '${_nearbyDevices.length} device(s) found',
              style: AppTypography.metadata,
            ),
            const SizedBox(height: 12),
            ..._nearbyDevices.map((device) => _buildNearbyDeviceTile(device)),
          ],
        ],
      ],
    );
  }

  Widget _buildNearbyDeviceTile(NearbyDevice device) {
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF22D3EE).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.phone_android,
            color: Color(0xFF22D3EE),
            size: 20,
          ),
        ),
        title: Text(device.name, style: AppTypography.bodyText),
        subtitle: Text(
          device.state.name,
          style: AppTypography.metadata.copyWith(
            color: device.state == NearbyConnectionState.connected
                ? AppColors.success
                : AppColors.secondaryText,
          ),
        ),
        trailing: device.state == NearbyConnectionState.connecting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryAccent,
                ),
              )
            : Icon(
                Icons.chevron_right,
                color: AppColors.secondaryText,
              ),
        onTap: device.state == NearbyConnectionState.disconnected
            ? () => _connectToNearbyDevice(device)
            : null,
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? submessage,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: AppColors.secondaryText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.bodyText.copyWith(
              color: AppColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          if (submessage != null) ...[
            const SizedBox(height: 8),
            Text(
              submessage,
              style: AppTypography.metadata,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
