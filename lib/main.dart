import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'navigation/navigation.dart';
import 'blocs/blocs.dart';
import 'models/models.dart';
import 'services/settings_service.dart';
import 'services/pairing_service.dart';

/// Helper to convert device type string to enum
DeviceType _deviceTypeFromString(String type) {
  switch (type) {
    case 'android': return DeviceType.android;
    case 'ios': return DeviceType.ios;
    case 'web': return DeviceType.web;
    default: return DeviceType.desktop;
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
              listener: (context, state) {
                // When disconnecting, clear clipboard history first
                if (state is PairingDisconnected) {
                  context.read<ClipboardBloc>().add(ClipboardHistoryCleared());
                }
                
                // Reload clipboard and devices when session changes
                context.read<ClipboardBloc>().add(ClipboardHistoryLoaded());
                context.read<DevicesBloc>().add(DevicesLoadStarted());
                
                // Register current device to start heartbeat
                if (state is PairingConnected) {
                  final device = ConnectedDevice(
                    id: pairingService.deviceId,
                    name: pairingService.deviceName,
                    type: _deviceTypeFromString(pairingService.deviceType),
                    status: DeviceStatus.active,
                    lastSeen: DateTime.now(),
                    isCurrentDevice: true,
                    sessionId: pairingService.currentSessionId,
                  );
                  context.read<DevicesBloc>().add(DeviceRegistered(device));
                }
              },
            ),
          ],
          child: const NavigationShell(),
        ),
      ),
    );
  }
}
