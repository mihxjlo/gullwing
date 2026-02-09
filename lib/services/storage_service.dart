import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/clipboard_item.dart';

/// Callback for upload/download progress (0.0 to 1.0)
typedef ProgressCallback = void Function(double progress);

/// Result of a file upload operation
class UploadResult {
  final String downloadUrl;
  final String? thumbnailUrl;
  final String storagePath;

  const UploadResult({
    required this.downloadUrl,
    this.thumbnailUrl,
    required this.storagePath,
  });
}

/// Service for uploading/downloading files to Firebase Storage
class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  
  StorageService._();
  
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Maximum file size (10MB)
  static const int maxFileSize = maxFileSizeBytes;

  /// Upload a file to Firebase Storage
  /// 
  /// Returns [UploadResult] with download URL and storage path
  Future<UploadResult> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String sessionId,
    required String itemId,
    String? mimeType,
    ProgressCallback? onProgress,
  }) async {
    // Validate file size
    if (bytes.length > maxFileSize) {
      throw StorageException('File exceeds maximum size of 10MB');
    }
    
    // Build storage path
    final storagePath = 'sessions/$sessionId/files/$itemId/$fileName';
    final ref = _storage.ref(storagePath);
    
    // Set metadata
    final metadata = SettableMetadata(
      contentType: mimeType ?? 'application/octet-stream',
      customMetadata: {
        'originalFileName': fileName,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );
    
    // Upload with progress tracking
    final uploadTask = ref.putData(bytes, metadata);
    
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      });
    }
    
    // Wait for upload to complete
    await uploadTask;
    
    // Get download URL
    final downloadUrl = await ref.getDownloadURL();
    
    // Generate thumbnail for images
    String? thumbnailUrl;
    if (mimeType?.startsWith('image/') == true) {
      thumbnailUrl = await _uploadThumbnail(
        bytes: bytes,
        sessionId: sessionId,
        itemId: itemId,
      );
    }
    
    return UploadResult(
      downloadUrl: downloadUrl,
      thumbnailUrl: thumbnailUrl,
      storagePath: storagePath,
    );
  }

  /// Upload a thumbnail for an image
  Future<String?> _uploadThumbnail({
    required Uint8List bytes,
    required String sessionId,
    required String itemId,
  }) async {
    try {
      // For MVP, just use the original image as thumbnail
      // In production, we'd resize the image
      final thumbnailPath = 'sessions/$sessionId/thumbnails/$itemId.jpg';
      final ref = _storage.ref(thumbnailPath);
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );
      
      await ref.putData(bytes, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      // Thumbnail generation is optional, don't fail the upload
      return null;
    }
  }

  /// Download a file from Firebase Storage
  Future<Uint8List?> downloadFile(String downloadUrl, {
    ProgressCallback? onProgress,
  }) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      
      // Get file data with max size limit
      final data = await ref.getData(maxFileSize);
      return data;
    } catch (e) {
      throw StorageException('Failed to download file: $e');
    }
  }

  /// Delete a file from Firebase Storage
  Future<void> deleteFile(String storagePath) async {
    try {
      final ref = _storage.ref(storagePath);
      await ref.delete();
    } catch (e) {
      // Ignore deletion errors (file may not exist)
    }
  }

  /// Delete all files for a clipboard item
  Future<void> deleteItemFiles(String sessionId, String itemId) async {
    try {
      // Delete main file
      final filesRef = _storage.ref('sessions/$sessionId/files/$itemId');
      final files = await filesRef.listAll();
      for (final file in files.items) {
        await file.delete();
      }
      
      // Delete thumbnail
      try {
        final thumbnailRef = _storage.ref('sessions/$sessionId/thumbnails/$itemId.jpg');
        await thumbnailRef.delete();
      } catch (_) {
        // Thumbnail may not exist
      }
    } catch (e) {
      // Ignore errors during cleanup
    }
  }

  /// Delete all files for an entire session
  /// Called when leaving a session to free up storage quota
  Future<void> deleteSessionFiles(String sessionId) async {
    try {
      final sessionRef = _storage.ref('sessions/$sessionId');
      
      // List all folders in session (files, thumbnails)
      final result = await sessionRef.listAll();
      
      // Delete all files in prefixes (folders)
      for (final prefix in result.prefixes) {
        await _deleteFolder(prefix);
      }
      
      // Delete any direct items
      for (final item in result.items) {
        try {
          await item.delete();
        } catch (_) {}
      }
    } catch (e) {
      // Ignore errors - best effort cleanup
    }
  }

  /// Helper to recursively delete a folder
  Future<void> _deleteFolder(Reference folderRef) async {
    try {
      final result = await folderRef.listAll();
      
      // Delete items in subfolders
      for (final prefix in result.prefixes) {
        await _deleteFolder(prefix);
      }
      
      // Delete files in this folder
      for (final item in result.items) {
        try {
          await item.delete();
        } catch (_) {}
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Get storage usage for a session
  Future<int> getSessionStorageUsage(String sessionId) async {
    try {
      final ref = _storage.ref('sessions/$sessionId');
      final result = await ref.listAll();
      
      int totalSize = 0;
      for (final item in result.items) {
        final metadata = await item.getMetadata();
        totalSize += metadata.size ?? 0;
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}

/// Storage-related exception
class StorageException implements Exception {
  final String message;
  const StorageException(this.message);
  
  @override
  String toString() => 'StorageException: $message';
}

/// Singleton instance
final storageService = StorageService.instance;
