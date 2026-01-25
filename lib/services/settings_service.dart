import 'package:shared_preferences/shared_preferences.dart';

/// Settings Service
/// Manages app settings with local persistence
class SettingsService {
  static const String _autoDetectClipboardKey = 'auto_detect_clipboard';
  static const String _saveHistoryKey = 'save_history';
  static const String _historyRetentionKey = 'history_retention';
  
  SharedPreferences? _prefs;
  
  /// Initialize the settings service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Auto-detect clipboard changes (default: false - manual input by default)
  bool get autoDetectClipboard {
    return _prefs?.getBool(_autoDetectClipboardKey) ?? false;
  }
  
  Future<void> setAutoDetectClipboard(bool value) async {
    await _prefs?.setBool(_autoDetectClipboardKey, value);
  }
  
  /// Save clipboard history (default: true)
  bool get saveHistory {
    return _prefs?.getBool(_saveHistoryKey) ?? true;
  }
  
  Future<void> setSaveHistory(bool value) async {
    await _prefs?.setBool(_saveHistoryKey, value);
  }
  
  /// History retention period in hours (default: 168 = 7 days)
  int get historyRetentionHours {
    return _prefs?.getInt(_historyRetentionKey) ?? 168;
  }
  
  Future<void> setHistoryRetentionHours(int hours) async {
    await _prefs?.setInt(_historyRetentionKey, hours);
  }
}

/// Global settings instance
final settingsService = SettingsService();

