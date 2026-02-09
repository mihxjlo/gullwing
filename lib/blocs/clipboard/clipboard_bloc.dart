import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/clipboard_item.dart';
import '../../services/clipboard_repository.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../../services/pairing_service.dart';
import '../../services/sync_manager.dart';
import 'clipboard_event.dart';
import 'clipboard_state.dart';

/// Clipboard BLoC
/// Manages clipboard monitoring, history, sync, and media uploads
class ClipboardBloc extends Bloc<ClipboardEvent, ClipboardState> {
  final ClipboardRepository _repository;
  final StorageService _storageService;
  final SyncManager _syncManager = syncManager;
  StreamSubscription<List<ClipboardItem>>? _itemsSubscription;
  StreamSubscription<ClipboardItem>? _localItemsSubscription;
  Timer? _monitoringTimer;
  String? _lastClipboardContent;
  
  ClipboardBloc({
    ClipboardRepository? repository,
    StorageService? storageService,
  }) : _repository = repository ?? ClipboardRepository(),
       _storageService = storageService ?? StorageService.instance,
       super(ClipboardInitial()) {
    on<ClipboardHistoryLoaded>(_onHistoryLoaded);
    on<ClipboardMonitoringStarted>(_onMonitoringStarted);
    on<ClipboardMonitoringStopped>(_onMonitoringStopped);
    on<ClipboardItemDetected>(_onItemDetected);
    on<ClipboardImagePasted>(_onImagePasted);
    on<ClipboardFileAttached>(_onFileAttached);
    on<ClipboardSyncStatusChanged>(_onSyncStatusChanged);
    on<ClipboardItemsReceived>(_onItemsReceived);
    on<ClipboardItemCopied>(_onItemCopied);
    on<ClipboardItemDeleted>(_onItemDeleted);
    on<ClipboardHistoryCleared>(_onHistoryCleared);
    on<ClipboardFileDownloadRequested>(_onFileDownloadRequested);
  }
  
  Future<void> _onHistoryLoaded(
    ClipboardHistoryLoaded event,
    Emitter<ClipboardState> emit,
  ) async {
    emit(ClipboardLoading());
    
    try {
      // Subscribe to real-time updates from Firestore
      _itemsSubscription?.cancel();
      _itemsSubscription = _repository.watchClipboardItems().listen(
        (items) => add(ClipboardItemsReceived(items)),
        onError: (error) => emit(ClipboardError(error.toString())),
      );
      
      // Subscribe to items received via local connections (Nearby/LAN)
      _localItemsSubscription?.cancel();
      _localItemsSubscription = _syncManager.receivedItems.listen(
        (item) => add(ClipboardItemsReceived([item])),
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
          deviceName: 'This Device',
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
      
      // Route through SyncManager (Nearby -> LAN -> Firebase)
      final result = await _syncManager.syncItem(item);
      
      // If save history is disabled and sync was successful, schedule deletion
      if (!settingsService.saveHistory && result.success) {
        Future.delayed(const Duration(seconds: 30), () async {
          try {
            await _repository.deleteClipboardItem(item.id);
          } catch (_) {}
        });
      }
      
      // Update current item in state
      final currentState = state;
      if (currentState is ClipboardMonitoring) {
        emit(currentState.copyWith(currentItem: item));
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Handle image paste - upload to Firebase Storage then sync metadata
  Future<void> _onImagePasted(
    ClipboardImagePasted event,
    Emitter<ClipboardState> emit,
  ) async {
    await _handleMediaUpload(
      bytes: event.imageBytes,
      fileName: event.fileName,
      mimeType: event.mimeType,
      deviceName: event.deviceName,
      emit: emit,
    );
  }

  /// Handle file attach - upload to Firebase Storage then sync metadata
  Future<void> _onFileAttached(
    ClipboardFileAttached event,
    Emitter<ClipboardState> emit,
  ) async {
    await _handleMediaUpload(
      bytes: event.fileBytes,
      fileName: event.fileName,
      mimeType: event.mimeType,
      deviceName: event.deviceName,
      emit: emit,
    );
  }

  /// Common method for uploading media (images and files)
  /// FIXED: Upload to Storage FIRST, then create Firestore item only after success
  Future<void> _handleMediaUpload({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String deviceName,
    required Emitter<ClipboardState> emit,
  }) async {
    // Validate file size
    if (bytes.length > maxFileSizeBytes) {
      // Don't emit error state that clears history, just show snackbar via UI
      return;
    }

    final sessionId = pairingService.currentSessionId;
    if (sessionId == null) {
      // Session not connected - don't crash the bloc
      return;
    }

    try {
      // Generate a temporary item ID for storage path
      final tempItemId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // STEP 1: Upload to Firebase Storage FIRST
      UploadResult uploadResult;
      try {
        uploadResult = await _storageService.uploadFile(
          bytes: bytes,
          fileName: fileName,
          sessionId: sessionId,
          itemId: tempItemId,
          mimeType: mimeType,
          onProgress: (progress) {
            // Progress tracking could be added here
          },
        );
      } catch (storageError) {
        // Storage upload failed - don't create Firestore item
        // Don't emit error that clears state
        return;
      }

      // STEP 2: Create Firestore item ONLY after successful upload
      final mediaItem = ClipboardItem.createMedia(
        fileName: fileName,
        fileSize: bytes.length,
        mimeType: mimeType,
        deviceName: deviceName,
        downloadUrl: uploadResult.downloadUrl,
        thumbnailUrl: uploadResult.thumbnailUrl,
      );

      // Add complete item to Firestore (with valid download URL)
      final itemId = await _repository.addClipboardItem(mediaItem);
      
      if (itemId == null) {
        // Firestore creation failed - cleanup storage
        try {
          await _storageService.deleteItemFiles(sessionId, tempItemId);
        } catch (_) {}
        return;
      }

      // If save history is disabled, schedule deletion
      if (!settingsService.saveHistory) {
        Future.delayed(const Duration(seconds: 30), () async {
          try {
            await _repository.deleteClipboardItem(itemId);
            await _storageService.deleteItemFiles(sessionId, tempItemId);
          } catch (_) {}
        });
      }

    } catch (e) {
      // Catch-all: don't crash the bloc or clear history
      // Error is logged silently
    }
  }

  /// Handle sync status change
  Future<void> _onSyncStatusChanged(
    ClipboardSyncStatusChanged event,
    Emitter<ClipboardState> emit,
  ) async {
    // Update item status in repository
    // This would be called when offline->online sync completes
  }

  /// Handle file download request
  Future<void> _onFileDownloadRequested(
    ClipboardFileDownloadRequested event,
    Emitter<ClipboardState> emit,
  ) async {
    if (event.item.downloadUrl == null) return;

    try {
      final bytes = await _storageService.downloadFile(event.item.downloadUrl!);
      if (bytes != null) {
        // Emit download complete state or handle file
        emit(ClipboardFileDownloaded(
          item: event.item,
          bytes: bytes,
        ));
      }
    } catch (e) {
      emit(ClipboardError('Download failed: $e'));
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
      // For media items, don't copy content to clipboard
      if (!event.item.isMediaItem) {
        await Clipboard.setData(ClipboardData(text: event.item.content));
        _lastClipboardContent = event.item.content;
      }
      
      final currentState = state;
      List<ClipboardItem> items = [];
      
      if (currentState is ClipboardMonitoring) {
        items = currentState.items;
      } else if (currentState is ClipboardLoaded) {
        items = currentState.items;
      }
      
      emit(ClipboardItemCopiedState(item: event.item, items: items));
      
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
      
      // Also delete associated files from storage
      final sessionId = pairingService.currentSessionId;
      if (sessionId != null) {
        await _storageService.deleteItemFiles(sessionId, event.itemId);
      }
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
    _localItemsSubscription?.cancel();
    _monitoringTimer?.cancel();
    return super.close();
  }
}
