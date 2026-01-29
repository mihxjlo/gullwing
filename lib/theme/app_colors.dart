import 'package:flutter/material.dart';

/// ClipSync Color Palette
/// Dark theme with purple accents - productivity-focused design
class AppColors {
  // Primary backgrounds
  static const Color primaryBackground = Color(0xFF0E0E12);
  static const Color secondaryBackground = Color(0xFF1A1A24);
  
  // Accent colors
  static const Color primaryAccent = Color(0xFF8B5CF6);
  static const Color secondaryAccent = Color(0xFFA78BFA);
  
  // Status colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningColor = warning;  // Alias for consistency
  static const Color error = Color(0xFFEF4444);
  
  // Text colors
  static const Color primaryText = Color(0xFFE5E7EB);
  static const Color secondaryText = Color(0xFF9CA3AF);
  static const Color mutedText = Color(0xFF6B7280);
  
  // Surface colors
  static const Color cardBackground = Color(0xFF1A1A24);
  static const Color cardBorder = Color(0xFF2A2A34);
  static const Color divider = Color(0xFF2A2A34);
  
  // Interactive states
  static const Color inactiveIcon = Color(0xFF6B7280);
  static const Color activeIcon = primaryAccent;
  
  // Status indicators
  static const Color onlineIndicator = success;
  static const Color idleIndicator = Color(0xFF6B7280);
  
  // Shadows and glows
  static const Color purpleGlow = Color(0x408B5CF6);
  static const Color purpleGlowStrong = Color(0x808B5CF6);
}
