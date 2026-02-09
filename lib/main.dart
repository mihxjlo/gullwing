import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'navigation/navigation.dart';
import 'blocs/blocs.dart';
import 'models/models.dart';
import 'services/settings_service.dart';
import 'services/pairing_service.dart';
import 'services/sync_manager.dart';
import 'services/trusted_devices_service.dart';
import 'services/nearby_service.dart';
import 'widgets/invitation_banner.dart';
import 'widgets/connection_request_dialog.dart';

/// Global navigator key for showing dialogs from services
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Helper to convert device type string to enum
DeviceType _deviceTypeFromString(String type) {
  switch (type) {
    case 'android': return DeviceType.android;
    case 'ios': return DeviceType.ios;
    case 'web': return DeviceType.web;
    default: return DeviceType.desktop;
  }
}

/// Setup Nearby connection handler with platform safety guards
/// Only runs on Android - Desktop platforms (Windows/macOS) cannot use Nearby Connections
void _setupNearbyHandler() {
  // Skip on Web (no dart:io Platform available)
  if (kIsWeb) {
    debugPrint('main: Skipping Nearby setup on Web');
    return;
  }
  
  // Skip on non-Android platforms (Windows, macOS, Linux)
  if (!Platform.isAndroid) {
    debugPrint('main: Skipping Nearby setup on ${Platform.operatingSystem} (not supported)');
    return;
  }
  
  // Try-catch to handle any plugin initialization errors gracefully
  try {
    nearbyService.onConnectionRequested = (device) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        ConnectionRequestDialog.show(
          context: context,
          deviceName: device.name,
          authToken: device.authToken,
          onAccept: () async {
            await nearbyService.acceptConnection(device.endpointId);
          },
          onReject: () async {
            await nearbyService.rejectConnection(device.endpointId);
          },
        );
      }
    };
    debugPrint('main: Nearby handler registered successfully');
  } catch (e) {
    debugPrint('main: Failed to setup Nearby handler (plugin may be unavailable): $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize settings
  await settingsService.init();
  
  // Initialize pairing service (loads saved session)
  await pairingService.init();
  
  // Initialize trusted devices service
  await trustedDevicesService.init();
  
  // Initialize sync manager with device info
  await syncManager.init(
    deviceId: pairingService.deviceId,
    deviceName: pairingService.deviceName,
    sessionId: pairingService.currentSessionId,
  );
  
  // Setup Nearby connection request handler
  // Only on Android - Nearby Connections requires Google Play Services
  // Desktop platforms (Windows/macOS) cannot use this plugin
  _setupNearbyHandler();
  
  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A1A24),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(const ClipSyncApp());
}

class ClipSyncApp extends StatelessWidget {
  const ClipSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc()..add(AuthSignInAnonymousRequested()),
        ),
        BlocProvider<ClipboardBloc>(
          create: (context) => ClipboardBloc(),
        ),
        BlocProvider<DevicesBloc>(
          create: (context) => DevicesBloc(),
        ),
        BlocProvider<PairingBloc>(
          create: (context) => PairingBloc()..add(const PairingSessionLoaded()),
        ),
      ],
      child: MaterialApp(
        title: 'ClipSync',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        navigatorKey: navigatorKey,
        home: MultiBlocListener(
          listeners: [
            BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthAuthenticated) {
                  // Load clipboard history when authenticated
                  context.read<ClipboardBloc>().add(ClipboardHistoryLoaded());
                  context.read<DevicesBloc>().add(DevicesLoadStarted());
                }
              },
            ),
            BlocListener<PairingBloc, PairingState>(
              listenWhen: (previous, current) {
                // Listen when session changes (connected or disconnected)
                return (previous is! PairingConnected && current is PairingConnected) ||
                       (previous is PairingConnected && current is! PairingConnected);
              },
              listener: (context, state) async {
                // When disconnecting, clear clipboard history first
                if (state is PairingDisconnected) {
                  context.read<ClipboardBloc>().add(ClipboardHistoryCleared());
                  // Update SyncManager session (stops LAN server)
                  await syncManager.updateSession(null);
                }
                
                // Reload clipboard and devices when session changes
                context.read<ClipboardBloc>().add(ClipboardHistoryLoaded());
                context.read<DevicesBloc>().add(DevicesLoadStarted());
                
                // Register current device to start heartbeat
                if (state is PairingConnected) {
                  // Update SyncManager with new session (starts LAN server and publishes IP)
                  await syncManager.updateSession(pairingService.currentSessionId);
                  
                  // Get LAN info from sync manager (set by _autoStartLanServer)
                  final localIp = syncManager.currentDeviceLocalIp;
                  const lanPort = 8765; // LanService.defaultPort
                  
                  final device = ConnectedDevice(
                    id: pairingService.deviceId,
                    name: pairingService.deviceName,
                    type: _deviceTypeFromString(pairingService.deviceType),
                    status: DeviceStatus.active,
                    lastSeen: DateTime.now(),
                    isCurrentDevice: true,
                    sessionId: pairingService.currentSessionId,
                    localIp: localIp,
                    lanPort: localIp != null ? lanPort : null,
                  );
                  context.read<DevicesBloc>().add(DeviceRegistered(device));
                  
                  // Probe other devices for LAN availability (smart promotion)
                  // Delay gives time for Firebase real-time updates to propagate
                  Future.delayed(const Duration(seconds: 4), () {
                    syncManager.probeAllDevicesForLan();
                  });
                }
              },
            ),
          ],
          child: const InvitationBanner(
            child: NavigationShell(),
          ),
        ),
      ),
    );
  }
}
