import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

// Platform-specific imports
import 'download_service_stub.dart'
    if (dart.library.io) 'download_service_io.dart'
    if (dart.library.html) 'download_service_web.dart' as platform;

/// Service for downloading files to device storage
class DownloadService {
  static DownloadService? _instance;
  static DownloadService get instance => _instance ??= DownloadService._();
  
  DownloadService._();

  /// Download a file from URL and save to device
  /// Returns the saved file path on success, null on failure
  Future<String?> downloadFile({
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Download file bytes
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        return null;
      }
      
      final bytes = response.bodyBytes;
      final sanitizedName = _sanitizeFileName(fileName);
      
      // Use platform-specific save method
      return await platform.saveFile(bytes, sanitizedName);
    } catch (e) {
      return null;
    }
  }

  /// Sanitize filename for filesystem
  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }
}

/// Singleton instance
final downloadService = DownloadService.instance;
