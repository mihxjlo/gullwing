import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/clipboard_item.dart';

/// Widget for displaying image/file preview in clipboard items
class MediaPreview extends StatelessWidget {
  final ClipboardItem item;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final bool isCompact;

  const MediaPreview({
    super.key,
    required this.item,
    this.onTap,
    this.onDownload,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (item.type == ClipboardContentType.image) {
      return _buildImagePreview();
    } else if (item.type == ClipboardContentType.file) {
      return _buildFilePreview();
    }
    return const SizedBox.shrink();
  }

  Widget _buildImagePreview() {
    final imageUrl = item.thumbnailUrl ?? item.downloadUrl;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: isCompact ? 80 : 200,
          maxWidth: isCompact ? 80 : double.infinity,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl != null
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildLoadingIndicator(loadingProgress);
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return _buildErrorPlaceholder();
                  },
                )
              : _buildPendingPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // File icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              color: AppColors.primaryAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName ?? 'File',
                  style: AppTypography.bodyText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.formattedFileSize,
                  style: AppTypography.metadata,
                ),
              ],
            ),
          ),
          // Download button
          if (onDownload != null && item.downloadUrl != null)
            IconButton(
              icon: Icon(
                Icons.download_outlined,
                color: AppColors.primaryAccent,
              ),
              onPressed: onDownload,
            ),
          // Sync status
          _buildSyncStatus(),
        ],
      ),
    );
  }

  Widget _buildSyncStatus() {
    Color statusColor;
    switch (item.syncStatus) {
      case SyncStatus.pending:
        statusColor = AppColors.warningColor;
        break;
      case SyncStatus.syncing:
        statusColor = AppColors.primaryAccent;
        break;
      case SyncStatus.synced:
        statusColor = AppColors.onlineIndicator;
        break;
      case SyncStatus.failed:
        statusColor = AppColors.error;
        break;
    }

    return Icon(
      item.syncIcon,
      size: 18,
      color: statusColor,
    );
  }

  Widget _buildLoadingIndicator(ImageChunkEvent loadingProgress) {
    final progress = loadingProgress.expectedTotalBytes != null
        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
        : null;

    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          value: progress,
          strokeWidth: 2,
          color: AppColors.primaryAccent,
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: AppColors.cardBackground,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }

  Widget _buildPendingPlaceholder() {
    return Container(
      color: AppColors.cardBackground,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 8),
            Text('Uploading...', style: AppTypography.metadata),
          ],
        ),
      ),
    );
  }
}

/// Full screen image viewer
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? fileName;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          fileName ?? 'Image',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppColors.primaryAccent,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
