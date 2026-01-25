import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ClipSync Typography System
/// Clean, readable typography with Inter-like styling
class AppTypography {
  static const String fontFamily = 'Inter';
  
  // Screen titles - 20-22px, SemiBold
  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    letterSpacing: -0.5,
  );
  
  // Screen subtitle
  static const TextStyle screenSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
    letterSpacing: 0,
  );
  
  // Section headers - 14-16px, Medium
  static const TextStyle sectionHeader = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryText,
    letterSpacing: -0.2,
  );
  
  // Body text - 14px, Regular
  static const TextStyle bodyText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryText,
    height: 1.5,
  );
  
  // Body text secondary
  static const TextStyle bodyTextSecondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
    height: 1.5,
  );
  
  // Metadata - 12px, Regular, reduced opacity
  static const TextStyle metadata = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
    letterSpacing: 0.1,
  );
  
  // Button text
  static const TextStyle buttonText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    letterSpacing: 0.2,
  );
  
  // Small label
  static const TextStyle smallLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
    letterSpacing: 0.5,
  );
  
  // Code/Monospace text
  static const TextStyle codeText = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryText,
    height: 1.6,
  );
}
