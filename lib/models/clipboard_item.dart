import 'package:flutter/material.dart';

/// Content type enumeration for clipboard items
enum ClipboardContentType {
  text,
  link,
  code,
  image,
  unknown,
}

/// Represents a clipboard item with metadata
class ClipboardItem {
  final String id;
  final String content;
  final ClipboardContentType type;
  final DateTime timestamp;
  final String? sourceDevice;
  final bool isSynced;

  ClipboardItem({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.sourceDevice,
    this.isSynced = false,
  });

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
      case ClipboardContentType.unknown:
        return Icons.content_paste_outlined;
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
  }) {
    return ClipboardItem(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      sourceDevice: sourceDevice ?? this.sourceDevice,
      isSynced: isSynced ?? this.isSynced,
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
    );
  }

  /// Create a new item from clipboard content
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
    );
  }
}

