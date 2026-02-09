import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Dialog for accepting/rejecting nearby connection requests
/// Shows device name and optional auth token for security
class ConnectionRequestDialog extends StatelessWidget {
  final String deviceName;
  final String? authToken;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const ConnectionRequestDialog({
    super.key,
    required this.deviceName,
    this.authToken,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bluetooth_connected,
                color: AppColors.primaryAccent,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Connection Request',
              style: AppTypography.screenTitle,
            ),
            const SizedBox(height: 12),

            // Device name
            Text(
              'Accept connection from',
              style: AppTypography.bodyText.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              deviceName,
              style: AppTypography.sectionHeader.copyWith(
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 16),

            // Auth token (if available)
            if (authToken != null && authToken!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.security,
                          color: AppColors.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verify code matches',
                          style: AppTypography.metadata.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      authToken!,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: AppColors.primaryText,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onReject();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onAccept();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show the connection request dialog
  static Future<void> show({
    required BuildContext context,
    required String deviceName,
    String? authToken,
    required VoidCallback onAccept,
    required VoidCallback onReject,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConnectionRequestDialog(
        deviceName: deviceName,
        authToken: authToken,
        onAccept: onAccept,
        onReject: onReject,
      ),
    );
  }
}
