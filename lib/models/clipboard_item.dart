import 'package:flutter/material.dart';

/// Content type enumeration for clipboard items
enum ClipboardContentType {
  text,
  link,
  code,
  image,
  file,     // General files (PDF, ZIP, DOC, etc.)
  unknown,
}

/// Sync status for clipboard items
enum SyncStatus {
  pending,   // Waiting to sync
  syncing,   // Currently uploading/syncing
  synced,    // Successfully synced
  failed,    // Sync failed
}

/// Maximum file size allowed (10MB)
const int maxFileSizeBytes = 10 * 1024 * 1024;

/// Represents a clipboard item with metadata
class ClipboardItem {
  final String id;
  final String content;           // Text content OR download URL for files
  final ClipboardContentType type;
  final DateTime timestamp;
  final String? sourceDevice;
  final bool isSynced;
  
  // File/Image metadata
  final String? fileName;         // Original file name
  final int? fileSize;            // Size in bytes
  final String? mimeType;         // MIME type (e.g., image/png, application/pdf)
  final String? thumbnailUrl;     // Firebase Storage thumbnail URL (images only)
  final String? downloadUrl;      // Firebase Storage download URL
  final SyncStatus syncStatus;    // Current sync status

  ClipboardItem({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.sourceDevice,
    this.isSynced = false,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.thumbnailUrl,
    this.downloadUrl,
    this.syncStatus = SyncStatus.synced,
  });

  /// Check if this is a media item (image or file)
  bool get isMediaItem => type == ClipboardContentType.image || type == ClipboardContentType.file;

  /// Get formatted file size string
  String get formattedFileSize {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Auto-detect content type from content
  static ClipboardContentType detectType(String content) {
    final trimmed = content.trim();
    
    // Check for URL/Link
    if (RegExp(r'^https?:\/\/').hasMatch(trimmed) ||
        RegExp(r'^www\.').hasMatch(trimmed)) {
      return ClipboardContentType.link;
    }
    
    // Check for code patterns
    if (_looksLikeCode(trimmed)) {
      return ClipboardContentType.code;
    }
    
    return ClipboardContentType.text;
  }

  /// Detect type from MIME type
  static ClipboardContentType detectTypeFromMime(String? mimeType) {
    if (mimeType == null) return ClipboardContentType.file;
    
    if (mimeType.startsWith('image/')) {
      return ClipboardContentType.image;
    }
    
    return ClipboardContentType.file;
  }

  static bool _looksLikeCode(String content) {
    final codePatterns = [
      RegExp(r'^\s*(import|export|from|require)\s'),
      RegExp(r'^\s*(function|const|let|var|class|def|pub|fn)\s'),
      RegExp(r'[{}\[\]];?\s*$'),
      RegExp(r'=>|->'),
      RegExp(r'^\s*#include'),
      RegExp(r'^\s*package\s'),
    ];
    
    for (final pattern in codePatterns) {
      if (pattern.hasMatch(content)) return true;
    }
    
    // Check for multiple lines with common code indentation
    final lines = content.split('\n');
    if (lines.length > 2) {
      final indentedLines = lines.where((l) => l.startsWith('  ') || l.startsWith('\t')).length;
      if (indentedLines > lines.length * 0.3) return true;
    }
    
    return false;
  }

  /// Get icon data for this content type
  IconData get icon {
    switch (type) {
      case ClipboardContentType.text:
        return Icons.text_fields_outlined;
      case ClipboardContentType.link:
        return Icons.link_outlined;
      case ClipboardContentType.code:
        return Icons.code_outlined;
      case ClipboardContentType.image:
        return Icons.image_outlined;
      case ClipboardContentType.file:
        return _getFileIcon();
      case ClipboardContentType.unknown:
        return Icons.content_paste_outlined;
    }
  }

  /// Get appropriate icon for file type
  IconData _getFileIcon() {
    if (mimeType == null) return Icons.insert_drive_file_outlined;
    
    if (mimeType!.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mimeType!.contains('zip') || mimeType!.contains('archive')) return Icons.folder_zip_outlined;
    if (mimeType!.contains('document') || mimeType!.contains('word')) return Icons.description_outlined;
    if (mimeType!.contains('spreadsheet') || mimeType!.contains('excel')) return Icons.table_chart_outlined;
    if (mimeType!.contains('presentation') || mimeType!.contains('powerpoint')) return Icons.slideshow_outlined;
    
    return Icons.insert_drive_file_outlined;
  }

  /// Get sync status icon
  IconData get syncIcon {
    switch (syncStatus) {
      case SyncStatus.pending:
        return Icons.cloud_queue_outlined;
      case SyncStatus.syncing:
        return Icons.cloud_upload_outlined;
      case SyncStatus.synced:
        return Icons.cloud_done_outlined;
      case SyncStatus.failed:
        return Icons.cloud_off_outlined;
    }
  }

  /// Get relative time string
  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 10) return 'Copied just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds} seconds ago';
    if (diff.inMinutes < 60) {
      return diff.inMinutes == 1 ? '1 minute ago' : '${diff.inMinutes} minutes ago';
    }
    if (diff.inHours < 24) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    }
    if (diff.inDays < 7) {
      return diff.inDays == 1 ? 'Yesterday' : '${diff.inDays} days ago';
    }
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  /// Get truncated preview of content
  String getPreview({int maxLines = 3, int maxChars = 200}) {
    // For media items, show file name instead of URL
    if (isMediaItem && fileName != null) {
      return fileName!;
    }
    
    String preview = content.length > maxChars 
        ? '${content.substring(0, maxChars)}...'
        : content;
    
    final lines = preview.split('\n');
    if (lines.length > maxLines) {
      preview = '${lines.take(maxLines).join('\n')}...';
    }
    
    return preview;
  }

  ClipboardItem copyWith({
    String? id,
    String? content,
    ClipboardContentType? type,
    DateTime? timestamp,
    String? sourceDevice,
    bool? isSynced,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? thumbnailUrl,
    String? downloadUrl,
    SyncStatus? syncStatus,
  }) {
    return ClipboardItem(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      sourceDevice: sourceDevice ?? this.sourceDevice,
      isSynced: isSynced ?? this.isSynced,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'sourceDevice': sourceDevice,
      'isSynced': isSynced,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'thumbnailUrl': thumbnailUrl,
      'downloadUrl': downloadUrl,
      'syncStatus': syncStatus.name,
    };
  }

  /// Create from Firestore document
  factory ClipboardItem.fromFirestore(Map<String, dynamic> data, String docId) {
    return ClipboardItem(
      id: docId,
      content: data['content'] as String? ?? '',
      type: ClipboardContentType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => ClipboardContentType.text,
      ),
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'] as String)
          : DateTime.now(),
      sourceDevice: data['sourceDevice'] as String?,
      isSynced: data['isSynced'] as bool? ?? true,
      fileName: data['fileName'] as String?,
      fileSize: data['fileSize'] as int?,
      mimeType: data['mimeType'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      downloadUrl: data['downloadUrl'] as String?,
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == data['syncStatus'],
        orElse: () => SyncStatus.synced,
      ),
    );
  }

  /// Create a new text item from clipboard content
  factory ClipboardItem.create({
    required String content,
    required String deviceName,
  }) {
    return ClipboardItem(
      id: '', // Will be assigned by Firestore
      content: content,
      type: ClipboardItem.detectType(content),
      timestamp: DateTime.now(),
      sourceDevice: deviceName,
      isSynced: false,
      syncStatus: SyncStatus.pending,
    );
  }

  /// Create a new media item (image or file)
  factory ClipboardItem.createMedia({
    required String fileName,
    required int fileSize,
    required String mimeType,
    required String deviceName,
    String? downloadUrl,
    String? thumbnailUrl,
  }) {
    return ClipboardItem(
      id: '', // Will be assigned by Firestore
      content: downloadUrl ?? '', // Will be updated after upload
      type: ClipboardItem.detectTypeFromMime(mimeType),
      timestamp: DateTime.now(),
      sourceDevice: deviceName,
      isSynced: false,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      downloadUrl: downloadUrl,
      thumbnailUrl: thumbnailUrl,
      syncStatus: downloadUrl != null ? SyncStatus.synced : SyncStatus.pending,
    );
  }
}
