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

/// New item detected from local clipboard
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
