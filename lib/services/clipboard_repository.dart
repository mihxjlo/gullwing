import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/clipboard_item.dart';
import 'firebase_service.dart';
import 'pairing_service.dart';

/// Clipboard Repository
/// Manages clipboard data persistence and real-time sync via Firestore
/// 
/// Data is stored at /sessions/{sessionId}/clipboard_items for cross-device sync
class ClipboardRepository {
  final FirebaseService _firebase;
  final PairingService _pairingService;
  
  ClipboardRepository({
    FirebaseService? firebase,
    PairingService? pairingServiceParam,
  }) : _firebase = firebase ?? FirebaseService.instance,
       _pairingService = pairingServiceParam ?? pairingService;
  
  /// Get the clipboard items collection reference for current session
  CollectionReference<Map<String, dynamic>>? get _clipboardCollection {
    final sessionId = _pairingService.currentSessionId;
    if (sessionId == null) return null;
    
    return _firebase.firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('clipboard_items');
  }
  
  /// Check if we have an active session
  bool get hasActiveSession => _pairingService.currentSessionId != null;
  
  /// Watch clipboard items in real-time (ordered by timestamp, newest first)
  Stream<List<ClipboardItem>> watchClipboardItems({int limit = 50}) {
    final collection = _clipboardCollection;
    if (collection == null) {
      return Stream.value([]);
    }
    
    return collection
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ClipboardItem.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }
  
  /// Get recent clipboard items (non-realtime)
  Future<List<ClipboardItem>> getRecentItems({int limit = 10}) async {
    final collection = _clipboardCollection;
    if (collection == null) return [];
    
    final snapshot = await collection
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs.map((doc) {
      return ClipboardItem.fromFirestore(doc.data(), doc.id);
    }).toList();
  }
  
  /// Add a new clipboard item
  Future<String?> addClipboardItem(ClipboardItem item) async {
    final collection = _clipboardCollection;
    if (collection == null) return null;
    
    final docRef = await collection.add(item.toFirestore());
    return docRef.id;
  }
  
  /// Update an existing clipboard item
  Future<void> updateClipboardItem(ClipboardItem item) async {
    final collection = _clipboardCollection;
    if (collection == null) return;
    
    await collection.doc(item.id).update(item.toFirestore());
  }
  
  /// Delete a clipboard item
  Future<void> deleteClipboardItem(String id) async {
    final collection = _clipboardCollection;
    if (collection == null) return;
    
    await collection.doc(id).delete();
  }
  
  /// Clear all clipboard history
  Future<void> clearHistory() async {
    final collection = _clipboardCollection;
    if (collection == null) return;
    
    final batch = _firebase.firestore.batch();
    final snapshot = await collection.get();
    
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }
  
  /// Delete items older than specified duration
  Future<int> cleanupOldItems(Duration maxAge) async {
    final collection = _clipboardCollection;
    if (collection == null) return 0;
    
    final cutoff = DateTime.now().subtract(maxAge);
    final snapshot = await collection
        .where('timestamp', isLessThan: cutoff.toIso8601String())
        .get();
    
    final batch = _firebase.firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
    return snapshot.docs.length;
  }
  
  /// Check if content already exists (to avoid duplicates)
  Future<bool> contentExists(String content) async {
    final collection = _clipboardCollection;
    if (collection == null) return false;
    
    final snapshot = await collection
        .where('content', isEqualTo: content)
        .limit(1)
        .get();
    
    return snapshot.docs.isNotEmpty;
  }
}
