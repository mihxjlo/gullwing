import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Empty state widget with illustration and message
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.cardBorder,
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTypography.sectionHeader,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: AppTypography.bodyTextSecondary,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Content type badge/chip
class ContentTypeBadge extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool isCompact;

  const ContentTypeBadge({
    super.key,
    required this.icon,
    this.label,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primaryAccent.withAlpha(26),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: AppColors.primaryAccent,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryAccent.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.primaryAccent,
          ),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: AppTypography.smallLabel.copyWith(
                color: AppColors.primaryAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Device chip showing device name and status
class DeviceChip extends StatelessWidget {
  final IconData icon;
  final String name;
  final bool isActive;
  final bool isCurrentDevice;

  const DeviceChip({
    super.key,
    required this.icon,
    required this.name,
    this.isActive = true,
    this.isCurrentDevice = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrentDevice 
            ? AppColors.primaryAccent.withAlpha(26)
            : AppColors.cardBorder.withAlpha(128),
        borderRadius: BorderRadius.circular(20),
        border: isCurrentDevice
            ? Border.all(color: AppColors.primaryAccent.withAlpha(77))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive 
                  ? AppColors.onlineIndicator 
                  : AppColors.idleIndicator,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            icon,
            size: 16,
            color: isCurrentDevice 
                ? AppColors.primaryAccent 
                : AppColors.secondaryText,
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: AppTypography.metadata.copyWith(
              color: isCurrentDevice 
                  ? AppColors.primaryText 
                  : AppColors.secondaryText,
            ),
          ),
          if (isCurrentDevice) ...[
            const SizedBox(width: 6),
            Text(
              '(This device)',
              style: AppTypography.metadata.copyWith(
                color: AppColors.primaryAccent,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Toggle setting row with switch
class SettingToggle extends StatelessWidget {
  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingToggle({
    super.key,
    required this.title,
    this.description,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyText),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: AppTypography.metadata,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Dropdown setting row
class SettingDropdown<T> extends StatelessWidget {
  final String title;
  final String? description;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const SettingDropdown({
    super.key,
    required this.title,
    this.description,
    required this.value,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.bodyText),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description!,
                        style: AppTypography.metadata,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              dropdownColor: AppColors.secondaryBackground,
              underline: const SizedBox(),
              style: AppTypography.bodyText,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
