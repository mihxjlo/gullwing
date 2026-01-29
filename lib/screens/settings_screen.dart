import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/devices/devices_bloc.dart';
import '../blocs/devices/devices_state.dart';
import '../blocs/clipboard/clipboard.dart';
import '../models/connected_device.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/widgets.dart';
import '../services/settings_service.dart';
import '../blocs/pairing/pairing.dart';
import 'pairing_screen.dart';

/// Settings Screen
/// Control modes, privacy, and behavior
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state
  bool _autoDetectClipboard = false;
  bool _saveHistory = true;
  String _historyRetention = '7 days';

  final List<String> _retentionOptions = [
    '1 hour',
    '24 hours',
    '7 days',
    'Manual only',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await settingsService.init();
    setState(() {
      _autoDetectClipboard = settingsService.autoDetectClipboard;
      _saveHistory = settingsService.saveHistory;
      _historyRetention = _getRetentionLabel(settingsService.historyRetentionHours);
    });
  }

  String _getRetentionLabel(int hours) {
    switch (hours) {
      case 1: return '1 hour';
      case 24: return '24 hours';
      case 168: return '7 days';
      default: return 'Manual only';
    }
  }

  int _getRetentionHours(String label) {
    switch (label) {
      case '1 hour': return 1;
      case '24 hours': return 24;
      case '7 days': return 168;
      default: return -1; // Manual only
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 24),
              
              // Paired Devices Section
              _buildPairedDevicesSection(),
              const SizedBox(height: 16),
              
              // Sync Mode Section
              _buildSyncSection(),
              const SizedBox(height: 16),
              
              // History Section
              _buildHistorySection(),
              const SizedBox(height: 16),
              
              // Privacy Section
              _buildPrivacySection(),
              const SizedBox(height: 16),
              
              // Appearance Section
              _buildAppearanceSection(),
              const SizedBox(height: 16),
              
              // About Section
              _buildAboutSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: AppTypography.screenTitle,
        ),
        SizedBox(height: 4),
        Text(
          'Customize your sync preferences',
          style: AppTypography.screenSubtitle,
        ),
      ],
    );
  }

  Widget _buildPairedDevicesSection() {
    return BlocBuilder<PairingBloc, PairingState>(
      builder: (context, pairingState) {
        final isConnected = pairingState is PairingConnected;
        
        return BlocBuilder<DevicesBloc, DevicesState>(
          builder: (context, devicesState) {
            final devices = devicesState is DevicesLoaded 
                ? devicesState.devices 
                : <ConnectedDevice>[];
            final deviceCount = devices.length;
            
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isConnected 
                              ? AppColors.success.withAlpha(26) 
                              : AppColors.primaryAccent.withAlpha(26),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isConnected ? Icons.devices_outlined : Icons.link_off_outlined,
                          color: isConnected ? AppColors.success : AppColors.primaryAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paired Devices',
                              style: AppTypography.sectionHeader,
                            ),
                            Text(
                              isConnected 
                                  ? '$deviceCount device${deviceCount != 1 ? 's' : ''} in session'
                                  : 'Not paired with any devices',
                              style: AppTypography.metadata,
                            ),
                          ],
                        ),
                      ),
                      if (isConnected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha(26),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Connected',
                                style: AppTypography.smallLabel.copyWith(
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  // Device list
                  if (isConnected && devices.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    ...devices.map((device) => _buildDeviceListItem(device)),
                  ],
                  
                  // Session code display (for sharing with new devices)
                  if (isConnected && (pairingState as PairingConnected).session.pairingCode.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.key_outlined,
                            size: 18,
                            color: AppColors.secondaryText,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Session Code',
                                  style: AppTypography.metadata,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (pairingState as PairingConnected).session.pairingCode,
                                  style: AppTypography.codeText.copyWith(
                                    fontSize: 16,
                                    letterSpacing: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.copy,
                              size: 18,
                              color: AppColors.secondaryText,
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                text: (pairingState as PairingConnected).session.pairingCode,
                              ));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Session code copied!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  if (!isConnected || devices.isEmpty) const Divider(),
                  if (!isConnected || devices.isEmpty) const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: isConnected ? 'Manage Devices' : 'Pair a Device',
                      icon: isConnected ? Icons.settings_outlined : Icons.add_link_outlined,
                      onPressed: () async {
                        final result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (context) => const PairingScreen(),
                          ),
                        );
                        if (result == true && context.mounted) {
                          // Reload pairing state
                          context.read<PairingBloc>().add(const PairingSessionLoaded());
                        }
                      },
                    ),
                  ),
                  if (isConnected) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SecondaryButton(
                        label: 'Disconnect',
                        icon: Icons.link_off_outlined,
                        onPressed: () {
                          context.read<PairingBloc>().add(const PairingSessionLeft());
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeviceListItem(ConnectedDevice device) {
    final isOnline = device.isOnline;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              device.icon,
              color: AppColors.secondaryText,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      device.name,
                      style: AppTypography.bodyText,
                    ),
                    if (device.isCurrentDevice) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryAccent.withAlpha(26),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'This device',
                          style: AppTypography.smallLabel.copyWith(
                            color: AppColors.primaryAccent,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  device.lastSeenText,
                  style: AppTypography.metadata.copyWith(
                    color: isOnline ? AppColors.success : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? AppColors.success : AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sync_outlined,
                  color: AppColors.primaryAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Sync Mode',
                style: AppTypography.sectionHeader,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          SettingToggle(
            title: 'Auto-detect clipboard',
            description: 'Automatically capture clipboard changes when app is in foreground',
            value: _autoDetectClipboard,
            onChanged: (value) async {
              setState(() => _autoDetectClipboard = value);
              await settingsService.setAutoDetectClipboard(value);
              
              // Immediately start/stop clipboard monitoring
              if (mounted) {
                if (value) {
                  context.read<ClipboardBloc>().add(ClipboardMonitoringStarted());
                } else {
                  context.read<ClipboardBloc>().add(ClipboardMonitoringStopped());
                }
              }
            },
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primaryAccent.withAlpha(30),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: AppColors.primaryAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _autoDetectClipboard 
                          ? 'Clipboard changes are captured automatically'
                          : 'Use the input field on Live screen to manually sync content',
                      style: AppTypography.metadata.copyWith(
                        color: AppColors.primaryAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_outlined,
                  color: AppColors.primaryAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'History',
                style: AppTypography.sectionHeader,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          SettingToggle(
            title: 'Save clipboard history',
            description: 'Store copied items for later access',
            value: _saveHistory,
            onChanged: (value) async {
              setState(() => _saveHistory = value);
              await settingsService.setSaveHistory(value);
            },
          ),
          if (_saveHistory) ...[
            const SizedBox(height: 8),
            SettingDropdown<String>(
              title: 'History retention',
              description: 'How long to keep clipboard history',
              value: _historyRetention,
              items: _retentionOptions.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: (value) async {
                if (value != null) {
                  setState(() => _historyRetention = value);
                  await settingsService.setHistoryRetentionHours(
                    _getRetentionHours(value),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivacySection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.primaryAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Privacy',
                style: AppTypography.sectionHeader,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Your clipboard data is synced securely between paired devices only.',
            style: AppTypography.metadata,
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.palette_outlined,
                  color: AppColors.primaryAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Appearance',
                style: AppTypography.sectionHeader,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: AppTypography.bodyText),
                    SizedBox(height: 4),
                    Text(
                      'Dark mode is the default theme',
                      style: AppTypography.metadata,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.dark_mode_outlined,
                      size: 16,
                      color: AppColors.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Dark',
                      style: AppTypography.metadata.copyWith(
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Accent color', style: AppTypography.bodyText),
                    SizedBox(height: 4),
                    Text(
                      'Purple is the accent color',
                      style: AppTypography.metadata,
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withAlpha(51),
                    width: 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: AppColors.primaryAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'About',
                style: AppTypography.sectionHeader,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _aboutRow('App name', 'ClipSync'),
          const SizedBox(height: 12),
          _aboutRow('Version', '1.0.0'),
          const SizedBox(height: 12),
          _aboutRow('Type', 'Course Project'),
        ],
      ),
    );
  }

  Widget _aboutRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyTextSecondary),
        Text(value, style: AppTypography.bodyText),
      ],
    );
  }
}
