import 'package:equatable/equatable.dart';
import '../../models/clipboard_item.dart';

/// Clipboard States
abstract class ClipboardState extends Equatable {
  const ClipboardState();
  
  @override
  List<Object?> get props => [];
}

/// Initial state
class ClipboardInitial extends ClipboardState {}

/// Loading clipboard data
class ClipboardLoading extends ClipboardState {}

/// Clipboard monitoring active
class ClipboardMonitoring extends ClipboardState {
  final List<ClipboardItem> items;
  final ClipboardItem? currentItem;
  final bool isMonitoring;
  
  const ClipboardMonitoring({
    this.items = const [],
    this.currentItem,
    this.isMonitoring = true,
  });
  
  @override
  List<Object?> get props => [items, currentItem, isMonitoring];
  
  ClipboardMonitoring copyWith({
    List<ClipboardItem>? items,
    ClipboardItem? currentItem,
    bool? isMonitoring,
  }) {
    return ClipboardMonitoring(
      items: items ?? this.items,
      currentItem: currentItem ?? this.currentItem,
      isMonitoring: isMonitoring ?? this.isMonitoring,
    );
  }
}

/// Clipboard history loaded
class ClipboardLoaded extends ClipboardState {
  final List<ClipboardItem> items;
  
  const ClipboardLoaded(this.items);
  
  @override
  List<Object?> get props => [items];
}

/// Error state
class ClipboardError extends ClipboardState {
  final String message;
  
  const ClipboardError(this.message);
  
  @override
  List<Object?> get props => [message];
}

/// Item copied confirmation
class ClipboardItemCopiedState extends ClipboardState {
  final ClipboardItem item;
  final List<ClipboardItem> items;
  
  const ClipboardItemCopiedState({
    required this.item,
    required this.items,
  });
  
  @override
  List<Object?> get props => [item, items];
}
