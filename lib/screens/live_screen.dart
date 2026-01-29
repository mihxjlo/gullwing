import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../blocs/blocs.dart';
import '../services/settings_service.dart';

/// Live Mode Screen
/// Shows current clipboard state + connected devices with manual input support
class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> with WidgetsBindingObserver {
  bool _isCopied = false;
  bool _isSending = false;
  bool _autoDetect = false;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await settingsService.init();
    if (!mounted) return;
    
    setState(() {
      _autoDetect = settingsService.autoDetectClipboard;
    });
    
    if (_autoDetect) {
      context.read<ClipboardBloc>().add(ClipboardMonitoringStarted());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final clipboardBloc = context.read<ClipboardBloc>();
    
    if (state == AppLifecycleState.resumed) {
      // Reload auto-detect setting on resume to catch changes from settings screen
      final currentAutoDetect = settingsService.autoDetectClipboard;
      setState(() => _autoDetect = currentAutoDetect);
      
      if (currentAutoDetect) {
        clipboardBloc.add(ClipboardMonitoringStarted());
      } else {
        // Ensure monitoring is stopped if auto-detect was disabled
        clipboardBloc.add(ClipboardMonitoringStopped());
      }
    } else if (state == AppLifecycleState.paused) {
      // Always stop monitoring when app goes to background
      clipboardBloc.add(ClipboardMonitoringStopped());
    }
  }

  Future<void> _copyToDevice(String content) async {
    if (content.isEmpty) return;
    
    await Clipboard.setData(ClipboardData(text: content));
    setState(() => _isCopied = true);
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isCopied = false);
      }
    });
  }

  Future<void> _sendToClipboard() async {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;
    
    setState(() => _isSending = true);
    
    try {
      // Add to Firestore via BLoC
      context.read<ClipboardBloc>().add(ClipboardItemDetected(
        content: content,
        deviceName: 'This Device',
      ));
      
      // Clear input after sending
      _inputController.clear();
      _inputFocusNode.unfocus();
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Synced to all devices!'),
            backgroundColor: AppColors.primaryAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _inputController.text = data.text!;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: data.text!.length),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 24),
              
              // Manual Input Card (always visible)
              _buildManualInputCard(),
              const SizedBox(height: 16),
              
              // Connection Status Card
              _buildConnectionCard(),
              const SizedBox(height: 16),
              
              // Clipboard Preview Card (shows latest synced item)
              _buildClipboardCard(),
              const SizedBox(height: 24),
              
              // Copy Action Button
              _buildCopyButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return BlocBuilder<ClipboardBloc, ClipboardState>(
      builder: (context, state) {
        final isMonitoring = _autoDetect && 
            state is ClipboardMonitoring && state.isMonitoring;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // App logo
                Image.asset(
                  'assets/gullwinglogo.png',
                  width: 36,
                  height: 36,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Live Clipboard',
                  style: AppTypography.screenTitle,
                ),
                const SizedBox(width: 12),
                if (isMonitoring)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Auto',
                          style: AppTypography.smallLabel.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _autoDetect 
                  ? 'Auto-detecting clipboard changes'
                  : 'Paste or type content to sync',
              style: AppTypography.screenSubtitle,
            ),
          ],
        );
      },
    );
  }

  Widget _buildManualInputCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_outlined,
                color: AppColors.primaryAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Share to Devices',
                style: AppTypography.sectionHeader,
              ),
              const Spacer(),
              // Paste button
              IconButton(
                onPressed: _pasteFromClipboard,
                icon: const Icon(
                  Icons.content_paste_outlined,
                  color: AppColors.secondaryText,
                  size: 20,
                ),
                tooltip: 'Paste from clipboard',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Text input field
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              maxLines: 4,
              minLines: 2,
              style: AppTypography.bodyText,
              decoration: InputDecoration(
                hintText: 'Type or paste text, links, code...',
                hintStyle: AppTypography.bodyTextSecondary.copyWith(
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          // Send button
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: _isSending ? 'Syncing...' : 'Sync to All Devices',
              icon: _isSending 
                  ? Icons.cloud_sync_outlined 
                  : Icons.cloud_upload_outlined,
              onPressed: _inputController.text.trim().isEmpty || _isSending
                  ? null
                  : _sendToClipboard,
              fullWidth: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return BlocBuilder<PairingBloc, PairingState>(
      builder: (context, state) {
        final isConnected = state is PairingConnected;
        final deviceCount = isConnected ? (state).deviceCount : 0;
        
        return AppCard(
          child: Row(
            children: [
              ConnectionIndicator(
                deviceCount: deviceCount,
                isConnected: isConnected,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Status',
                      style: AppTypography.sectionHeader,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      !isConnected 
                          ? 'Not paired with any devices'
                          : '$deviceCount device${deviceCount != 1 ? 's' : ''} connected',
                      style: AppTypography.bodyTextSecondary,
                    ),
                  ],
                ),
              ),
              if (isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(26),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Syncing',
                        style: AppTypography.smallLabel.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClipboardCard() {
    return BlocBuilder<ClipboardBloc, ClipboardState>(
      builder: (context, state) {
        List<ClipboardItem> items = [];
        
        if (state is ClipboardMonitoring) {
          items = state.items;
        } else if (state is ClipboardLoaded) {
          items = state.items;
        }
        
        // Take the last 5 items
        final recentItems = items.take(5).toList();
        final hasContent = recentItems.isNotEmpty;
        
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.cloud_done_outlined,
                    color: AppColors.primaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Latest Synced',
                    style: AppTypography.sectionHeader,
                  ),
                  const Spacer(),
                  if (hasContent)
                    Text(
                      '${recentItems.length} item${recentItems.length != 1 ? 's' : ''}',
                      style: AppTypography.metadata,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (!hasContent)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Text(
                    'No synced content yet',
                    style: AppTypography.bodyTextSecondary.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...recentItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Column(
                    children: [
                      if (index > 0) const Divider(height: 1),
                      _buildSyncedItemRow(item),
                    ],
                  );
                }),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildSyncedItemRow(ClipboardItem item) {
    final isLink = item.type == ClipboardContentType.link;
    
    return InkWell(
      onTap: () => _copyToDevice(item.content),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContentTypeBadge(
              icon: item.icon,
              isCompact: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.getPreview(maxLines: 2, maxChars: 80),
                    style: item.type == ClipboardContentType.code
                        ? AppTypography.codeText.copyWith(fontSize: 13)
                        : AppTypography.bodyText.copyWith(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.relativeTime} • ${item.sourceDevice ?? "Unknown"}',
                    style: AppTypography.metadata.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isLink)
              IconButton(
                icon: Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: AppColors.primaryAccent,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _openUrl(item.content),
                tooltip: 'Open link',
              ),
            if (isLink) const SizedBox(width: 12),
            Icon(
              Icons.content_copy_outlined,
              size: 16,
              color: AppColors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyButton() {
    return BlocBuilder<ClipboardBloc, ClipboardState>(
      builder: (context, state) {
        String content = '';
        
        if (state is ClipboardMonitoring && state.items.isNotEmpty) {
          content = state.items.first.content;
        } else if (state is ClipboardLoaded && state.items.isNotEmpty) {
          content = state.items.first.content;
        }
        
        return SizedBox(
          width: double.infinity,
          child: SecondaryButton(
            label: _isCopied ? 'Copied!' : 'Copy Latest to Clipboard',
            icon: _isCopied ? Icons.check_rounded : Icons.content_copy_outlined,
            onPressed: content.isEmpty || _isCopied 
                ? null 
                : () => _copyToDevice(content),
          ),
        );
      },
    );
  }
}
