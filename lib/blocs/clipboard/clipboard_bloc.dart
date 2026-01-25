import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/clipboard_item.dart';
import '../../services/clipboard_repository.dart';
import 'clipboard_event.dart';
import 'clipboard_state.dart';

/// Clipboard BLoC
/// Manages clipboard monitoring, history, and sync
class ClipboardBloc extends Bloc<ClipboardEvent, ClipboardState> {
  final ClipboardRepository _repository;
  StreamSubscription<List<ClipboardItem>>? _itemsSubscription;
  Timer? _monitoringTimer;
  String? _lastClipboardContent;
  
  ClipboardBloc({
    ClipboardRepository? repository,
  }) : _repository = repository ?? ClipboardRepository(),
       super(ClipboardInitial()) {
    on<ClipboardHistoryLoaded>(_onHistoryLoaded);
    on<ClipboardMonitoringStarted>(_onMonitoringStarted);
    on<ClipboardMonitoringStopped>(_onMonitoringStopped);
    on<ClipboardItemDetected>(_onItemDetected);
    on<ClipboardItemsReceived>(_onItemsReceived);
    on<ClipboardItemCopied>(_onItemCopied);
    on<ClipboardItemDeleted>(_onItemDeleted);
    on<ClipboardHistoryCleared>(_onHistoryCleared);
  }
  
  Future<void> _onHistoryLoaded(
    ClipboardHistoryLoaded event,
    Emitter<ClipboardState> emit,
  ) async {
    emit(ClipboardLoading());
    
    try {
      // Subscribe to real-time updates
      _itemsSubscription?.cancel();
      _itemsSubscription = _repository.watchClipboardItems().listen(
        (items) => add(ClipboardItemsReceived(items)),
        onError: (error) => emit(ClipboardError(error.toString())),
      );
    } catch (e) {
      emit(ClipboardError(e.toString()));
    }
  }
  
  Future<void> _onMonitoringStarted(
    ClipboardMonitoringStarted event,
    Emitter<ClipboardState> emit,
  ) async {
    final currentState = state;
    List<ClipboardItem> currentItems = [];
    
    if (currentState is ClipboardMonitoring) {
      currentItems = currentState.items;
    } else if (currentState is ClipboardLoaded) {
      currentItems = currentState.items;
    }
    
    emit(ClipboardMonitoring(items: currentItems, isMonitoring: true));
    
    // Start polling clipboard (foreground only)
    _startClipboardPolling();
    
    // Subscribe to Firestore updates if not already
    _itemsSubscription ??= _repository.watchClipboardItems().listen(
      (items) => add(ClipboardItemsReceived(items)),
    );
  }
  
  Future<void> _onMonitoringStopped(
    ClipboardMonitoringStopped event,
    Emitter<ClipboardState> emit,
  ) async {
    _stopClipboardPolling();
    
    final currentState = state;
    if (currentState is ClipboardMonitoring) {
      emit(currentState.copyWith(isMonitoring: false));
    }
  }
  
  void _startClipboardPolling() {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _checkClipboard(),
    );
  }
  
  void _stopClipboardPolling() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }
  
  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final content = data?.text;
      
      if (content != null && 
          content.isNotEmpty && 
          content != _lastClipboardContent) {
        _lastClipboardContent = content;
        add(ClipboardItemDetected(
          content: content,
          deviceName: 'This Device', // Will be replaced with actual device name
        ));
      }
    } catch (e) {
      // Clipboard access may fail in background
    }
  }
  
  Future<void> _onItemDetected(
    ClipboardItemDetected event,
    Emitter<ClipboardState> emit,
  ) async {
    try {
      // Check if content already exists to avoid duplicates
      final exists = await _repository.contentExists(event.content);
      if (exists) return;
      
      // Create new clipboard item
      final item = ClipboardItem.create(
        content: event.content,
        deviceName: event.deviceName,
      );
      
      // Add to Firestore
      await _repository.addClipboardItem(item);
      
      // Update current item in state
      final currentState = state;
      if (currentState is ClipboardMonitoring) {
        emit(currentState.copyWith(currentItem: item));
      }
    } catch (e) {
      // Handle error silently for now
    }
  }
  
  void _onItemsReceived(
    ClipboardItemsReceived event,
    Emitter<ClipboardState> emit,
  ) {
    final currentState = state;
    
    if (currentState is ClipboardMonitoring) {
      emit(currentState.copyWith(
        items: event.items,
        currentItem: event.items.isNotEmpty ? event.items.first : null,
      ));
    } else {
      emit(ClipboardLoaded(event.items));
    }
  }
  
  Future<void> _onItemCopied(
    ClipboardItemCopied event,
    Emitter<ClipboardState> emit,
  ) async {
    try {
      // Copy to system clipboard
      await Clipboard.setData(ClipboardData(text: event.item.content));
      _lastClipboardContent = event.item.content;
      
      // Emit copied state briefly
      final currentState = state;
      List<ClipboardItem> items = [];
      
      if (currentState is ClipboardMonitoring) {
        items = currentState.items;
      } else if (currentState is ClipboardLoaded) {
        items = currentState.items;
      }
      
      emit(ClipboardItemCopiedState(item: event.item, items: items));
      
      // Return to previous state after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (state is ClipboardItemCopiedState) {
        emit(ClipboardMonitoring(items: items, currentItem: event.item));
      }
    } catch (e) {
      emit(ClipboardError('Failed to copy: $e'));
    }
  }
  
  Future<void> _onItemDeleted(
    ClipboardItemDeleted event,
    Emitter<ClipboardState> emit,
  ) async {
    try {
      await _repository.deleteClipboardItem(event.itemId);
    } catch (e) {
      emit(ClipboardError('Failed to delete: $e'));
    }
  }
  
  Future<void> _onHistoryCleared(
    ClipboardHistoryCleared event,
    Emitter<ClipboardState> emit,
  ) async {
    try {
      await _repository.clearHistory();
      emit(const ClipboardLoaded([]));
    } catch (e) {
      emit(ClipboardError('Failed to clear history: $e'));
    }
  }
  
  @override
  Future<void> close() {
    _itemsSubscription?.cancel();
    _monitoringTimer?.cancel();
    return super.close();
  }
}
