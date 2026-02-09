import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/clipboard_item.dart';

/// Queued item with metadata for offline sync
class QueuedItem {
  final String id;
  final ClipboardItem item;
  final DateTime queuedAt;
  final int retryCount;
  final Uint8List? fileBytes;

  QueuedItem({
    required this.id,
    required this.item,
    required this.queuedAt,
    this.retryCount = 0,
    this.fileBytes,
  });

  /// Create a copy with updated retry count
  QueuedItem withRetry() => QueuedItem(
    id: id,
    item: item,
    queuedAt: queuedAt,
    retryCount: retryCount + 1,
    fileBytes: fileBytes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'item': item.toFirestore(),
    'queuedAt': queuedAt.toIso8601String(),
    'retryCount': retryCount,
    'hasFileBytes': fileBytes != null,
  };

  factory QueuedItem.fromJson(Map<String, dynamic> json) => QueuedItem(
    id: json['id'] ?? '',
    item: ClipboardItem.fromFirestore(json['item'] ?? {}, json['id'] ?? ''),
    queuedAt: DateTime.tryParse(json['queuedAt'] ?? '') ?? DateTime.now(),
    retryCount: json['retryCount'] ?? 0,
  );
}

/// Service for managing offline queue using Hive
/// Handles clipboard items that couldn't be synced due to no available route
class OfflineQueueService {
  static const String _queueBoxName = 'offline_queue';
  static const String _fileBytesBoxName = 'offline_queue_files';
  static const int maxRetries = 3;
  
  Box<String>? _queueBox;
  Box<Uint8List>? _fileBytesBox;
  bool _isInitialized = false;
  
  /// Processed item IDs to prevent duplicates (in-memory cache)
  final Set<String> _processedIds = {};
  
  /// Initialize Hive and open boxes
  Future<void> init() async {
    if (_isInitialized) return;
    
    await Hive.initFlutter();
    
    _queueBox = await Hive.openBox<String>(_queueBoxName);
    _fileBytesBox = await Hive.openBox<Uint8List>(_fileBytesBoxName);
    
    _isInitialized = true;
  }
  
  /// Check if queue is empty
  bool get isEmpty => _queueBox?.isEmpty ?? true;
  
  /// Get queue length
  int get length => _queueBox?.length ?? 0;
  
  /// Enqueue a clipboard item for later sync
  Future<void> enqueue(ClipboardItem item, {Uint8List? fileBytes}) async {
    if (!_isInitialized) await init();
    
    // Check for duplicate by item ID + timestamp
    final dedupeKey = _getDedupeKey(item);
    if (_processedIds.contains(dedupeKey)) {
      return; // Already in queue or processed
    }
    
    final queuedItem = QueuedItem(
      id: item.id,
      item: item,
      queuedAt: DateTime.now(),
      fileBytes: fileBytes,
    );
    
    // Store item metadata as JSON
    await _queueBox?.put(item.id, jsonEncode(queuedItem.toJson()));
    
    // Store file bytes separately if present
    if (fileBytes != null) {
      await _fileBytesBox?.put(item.id, fileBytes);
    }
    
    _processedIds.add(dedupeKey);
  }
  
  /// Dequeue the next item (FIFO)
  Future<QueuedItem?> dequeue() async {
    if (!_isInitialized) await init();
    if (_queueBox?.isEmpty ?? true) return null;
    
    // Get first key
    final key = _queueBox!.keys.first as String;
    final json = _queueBox!.get(key);
    
    if (json == null) return null;
    
    final queuedItem = QueuedItem.fromJson(jsonDecode(json));
    
    // Get file bytes if available
    final fileBytes = _fileBytesBox?.get(key);
    
    // Remove from queue
    await _queueBox!.delete(key);
    await _fileBytesBox?.delete(key);
    
    return QueuedItem(
      id: queuedItem.id,
      item: queuedItem.item,
      queuedAt: queuedItem.queuedAt,
      retryCount: queuedItem.retryCount,
      fileBytes: fileBytes,
    );
  }
  
  /// Peek at the next item without removing it
  Future<QueuedItem?> peek() async {
    if (!_isInitialized) await init();
    if (_queueBox?.isEmpty ?? true) return null;
    
    final key = _queueBox!.keys.first as String;
    final json = _queueBox!.get(key);
    
    if (json == null) return null;
    
    return QueuedItem.fromJson(jsonDecode(json));
  }
  
  /// Get all queued items
  Future<List<QueuedItem>> getAllItems() async {
    if (!_isInitialized) await init();
    
    final items = <QueuedItem>[];
    for (final key in _queueBox?.keys ?? []) {
      final json = _queueBox?.get(key);
      if (json != null) {
        items.add(QueuedItem.fromJson(jsonDecode(json)));
      }
    }
    
    // Sort by queued time (FIFO)
    items.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return items;
  }
  
  /// Re-queue an item that failed to sync (with retry count)
  Future<void> requeue(QueuedItem item) async {
    if (!_isInitialized) await init();
    
    if (item.retryCount >= maxRetries) {
      // Max retries exceeded, discard item
      await _fileBytesBox?.delete(item.id);
      return;
    }
    
    final retryItem = item.withRetry();
    await _queueBox?.put(item.id, jsonEncode(retryItem.toJson()));
  }
  
  /// Remove a specific item from queue
  Future<void> remove(String itemId) async {
    if (!_isInitialized) await init();
    
    await _queueBox?.delete(itemId);
    await _fileBytesBox?.delete(itemId);
  }
  
  /// Check if an item is already in queue (by ID)
  bool contains(String itemId) {
    return _queueBox?.containsKey(itemId) ?? false;
  }
  
  /// Clear the entire queue
  Future<void> clear() async {
    if (!_isInitialized) await init();
    
    await _queueBox?.clear();
    await _fileBytesBox?.clear();
    _processedIds.clear();
  }
  
  /// Get dedupe key for an item
  String _getDedupeKey(ClipboardItem item) {
    return '${item.id}_${item.timestamp.millisecondsSinceEpoch}';
  }
  
  /// Mark an item as processed (to prevent re-adding)
  void markProcessed(ClipboardItem item) {
    _processedIds.add(_getDedupeKey(item));
  }
  
  /// Check if item was already processed
  bool wasProcessed(ClipboardItem item) {
    return _processedIds.contains(_getDedupeKey(item));
  }
  
  /// Cleanup processed IDs cache (call periodically)
  void cleanupProcessedCache() {
    // Keep only recent IDs (last 1000)
    if (_processedIds.length > 1000) {
      final toRemove = _processedIds.length - 500;
      _processedIds.removeAll(_processedIds.take(toRemove).toList());
    }
  }
  
  /// Close Hive boxes
  Future<void> dispose() async {
    await _queueBox?.close();
    await _fileBytesBox?.close();
  }
}

/// Global instance
final offlineQueueService = OfflineQueueService();
