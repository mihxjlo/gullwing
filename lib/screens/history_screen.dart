import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../blocs/blocs.dart';

/// History Mode Screen
/// Browsable clipboard archive
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            
            // History List
            Expanded(
              child: BlocBuilder<ClipboardBloc, ClipboardState>(
                builder: (context, state) {
                  List<ClipboardItem> items = [];
                  
                  if (state is ClipboardMonitoring) {
                    items = state.items;
                  } else if (state is ClipboardLoaded) {
                    items = state.items;
                  }
                  
                  if (items.isEmpty) {
                    return _buildEmptyState();
                  }
                  
                  return _buildHistoryList(items);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clipboard History',
                  style: AppTypography.screenTitle,
                ),
                SizedBox(height: 4),
                Text(
                  'Your recent clipboard items',
                  style: AppTypography.screenSubtitle,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // Filter options - feature planned
            },
            icon: const Icon(
              Icons.filter_list_outlined,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.content_paste_off_outlined,
      title: 'No clipboard history',
      subtitle: 'Your clipboard history will appear here',
    );
  }

  Widget _buildHistoryList(List<ClipboardItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildHistoryItem(item);
      },
    );
  }

  Widget _buildHistoryItem(ClipboardItem item) {
    final isExpanded = _expandedId == item.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded 
              ? AppColors.primaryAccent.withAlpha(77)
              : AppColors.cardBorder,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (always visible)
          GestureDetector(
            onTap: () {
              setState(() {
                _expandedId = isExpanded ? null : item.id;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContentTypeBadge(icon: item.icon, isCompact: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.getPreview(maxLines: 2, maxChars: 100),
                          style: item.type == ClipboardContentType.code
                              ? AppTypography.codeText.copyWith(fontSize: 12)
                              : AppTypography.bodyText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              item.relativeTime,
                              style: AppTypography.metadata,
                            ),
                            if (item.sourceDevice != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.sourceDevice!,
                                style: AppTypography.metadata,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded content
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full content
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: SelectableText(
                          item.content,
                          style: item.type == ClipboardContentType.code
                              ? AppTypography.codeText
                              : AppTypography.bodyText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Copy',
                              icon: Icons.content_copy_outlined,
                              onPressed: () {
                                context.read<ClipboardBloc>().add(
                                  ClipboardItemCopied(item),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Copied to clipboard'),
                                    backgroundColor: AppColors.secondaryBackground,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SecondaryButton(
                            label: 'Delete',
                            icon: Icons.delete_outline,
                            isDanger: true,
                            onPressed: () => _showDeleteConfirmation(item),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(ClipboardItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete item?',
          style: AppTypography.sectionHeader,
        ),
        content: const Text(
          'This action cannot be undone.',
          style: AppTypography.bodyTextSecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ClipboardBloc>().add(ClipboardItemDeleted(item.id));
              setState(() {
                if (_expandedId == item.id) _expandedId = null;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
