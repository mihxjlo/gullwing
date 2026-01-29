import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import '../../models/clipboard_item.dart';

/// Clipboard Events
abstract class ClipboardEvent extends Equatable {
  const ClipboardEvent();
  
  @override
  List<Object?> get props => [];
}

/// Start monitoring clipboard
class ClipboardMonitoringStarted extends ClipboardEvent {}

/// Stop monitoring clipboard
class ClipboardMonitoringStopped extends ClipboardEvent {}

/// New text item detected from local clipboard
class ClipboardItemDetected extends ClipboardEvent {
  final String content;
  final String deviceName;
  
  const ClipboardItemDetected({
    required this.content,
    required this.deviceName,
  });
  
  @override
  List<Object?> get props => [content, deviceName];
}

/// Image pasted/selected for sync
class ClipboardImagePasted extends ClipboardEvent {
  final Uint8List imageBytes;
  final String fileName;
  final String mimeType;
  final String deviceName;
  
  const ClipboardImagePasted({
    required this.imageBytes,
    required this.fileName,
    required this.mimeType,
    required this.deviceName,
  });
  
  @override
  List<Object?> get props => [imageBytes, fileName, mimeType, deviceName];
}

/// File attached for sync
class ClipboardFileAttached extends ClipboardEvent {
  final Uint8List fileBytes;
  final String fileName;
  final String mimeType;
  final String deviceName;
  
  const ClipboardFileAttached({
    required this.fileBytes,
    required this.fileName,
    required this.mimeType,
    required this.deviceName,
  });
  
  @override
  List<Object?> get props => [fileBytes, fileName, mimeType, deviceName];
}

/// Sync status changed for an item
class ClipboardSyncStatusChanged extends ClipboardEvent {
  final String itemId;
  final SyncStatus status;
  final String? errorMessage;
  
  const ClipboardSyncStatusChanged({
    required this.itemId,
    required this.status,
    this.errorMessage,
  });
  
  @override
  List<Object?> get props => [itemId, status, errorMessage];
}

/// Items received from Firestore sync
class ClipboardItemsReceived extends ClipboardEvent {
  final List<ClipboardItem> items;
  
  const ClipboardItemsReceived(this.items);
  
  @override
  List<Object?> get props => [items];
}

/// User copied an item from history
class ClipboardItemCopied extends ClipboardEvent {
  final ClipboardItem item;
  
  const ClipboardItemCopied(this.item);
  
  @override
  List<Object?> get props => [item];
}

/// User deleted an item
class ClipboardItemDeleted extends ClipboardEvent {
  final String itemId;
  
  const ClipboardItemDeleted(this.itemId);
  
  @override
  List<Object?> get props => [itemId];
}

/// Clear all history
class ClipboardHistoryCleared extends ClipboardEvent {}

/// Load clipboard history
class ClipboardHistoryLoaded extends ClipboardEvent {}

/// Download file for local viewing
class ClipboardFileDownloadRequested extends ClipboardEvent {
  final ClipboardItem item;
  
  const ClipboardFileDownloadRequested(this.item);
  
  @override
  List<Object?> get props => [item];
}
