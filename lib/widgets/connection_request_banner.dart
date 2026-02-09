import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Persistent banner for incoming connection requests
/// Shows at top of screen with Accept/Decline buttons
class ConnectionRequestBanner extends StatelessWidget {
  final String deviceName;
  final String connectionType; // 'Nearby' or 'Local Network'
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  
  const ConnectionRequestBanner({
    super.key,
    required this.deviceName,
    required this.connectionType,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryAccent.withOpacity(0.9),
              AppColors.primaryAccent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  connectionType == 'Nearby' 
                      ? Icons.bluetooth_connected 
                      : Icons.wifi,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Connection Request',
                      style: AppTypography.metadata.copyWith(
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '"$deviceName" wants to connect via $connectionType',
                      style: AppTypography.bodyText.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Decline button
                  _ActionButton(
                    label: 'Decline',
                    onTap: onDecline,
                    isPrimary: false,
                  ),
                  const SizedBox(width: 8),
                  // Accept button
                  _ActionButton(
                    label: 'Accept',
                    onTap: onAccept,
                    isPrimary: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  
  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary 
          ? Colors.white 
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: isPrimary 
                ? null 
                : Border.all(color: Colors.white.withOpacity(0.5), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: AppTypography.metadata.copyWith(
              color: isPrimary ? AppColors.primaryAccent : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapper to show connection banner as overlay
class ConnectionRequestOverlay extends StatefulWidget {
  final Widget child;
  
  const ConnectionRequestOverlay({
    super.key,
    required this.child,
  });

  /// Global key to access state from anywhere
  static final GlobalKey<ConnectionRequestOverlayState> globalKey = 
      GlobalKey<ConnectionRequestOverlayState>();
  
  @override
  State<ConnectionRequestOverlay> createState() => ConnectionRequestOverlayState();
}

class ConnectionRequestOverlayState extends State<ConnectionRequestOverlay> {
  String? _pendingDeviceName;
  String? _pendingConnectionType;
  VoidCallback? _onAccept;
  VoidCallback? _onDecline;
  
  /// Show a connection request banner
  void showRequest({
    required String deviceName,
    required String connectionType,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
  }) {
    setState(() {
      _pendingDeviceName = deviceName;
      _pendingConnectionType = connectionType;
      _onAccept = () {
        onAccept();
        _dismissBanner();
      };
      _onDecline = () {
        onDecline();
        _dismissBanner();
      };
    });
  }
  
  /// Dismiss the current banner
  void _dismissBanner() {
    setState(() {
      _pendingDeviceName = null;
      _pendingConnectionType = null;
      _onAccept = null;
      _onDecline = null;
    });
  }
  
  /// Check if banner is showing
  bool get isShowing => _pendingDeviceName != null;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_pendingDeviceName != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ConnectionRequestBanner(
              deviceName: _pendingDeviceName!,
              connectionType: _pendingConnectionType!,
              onAccept: _onAccept!,
              onDecline: _onDecline!,
            ),
          ),
      ],
    );
  }
}
