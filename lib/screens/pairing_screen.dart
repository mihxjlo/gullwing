import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/widgets.dart';
import '../blocs/pairing/pairing.dart';

/// Pairing Screen
/// Allows users to create or join a pairing session
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PairingBloc()..add(const PairingSessionLoaded()),
      child: Scaffold(
        backgroundColor: AppColors.primaryBackground,
        appBar: AppBar(
          backgroundColor: AppColors.primaryBackground,
          title: Text('Pair Devices', style: AppTypography.screenTitle),
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.primaryText),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocConsumer<PairingBloc, PairingState>(
          listenWhen: (previous, current) {
            // Only listen for the first PairingConnected state transition
            if (current is PairingConnected && previous is! PairingConnected) {
              return true;
            }
            // Always listen for errors
            if (current is PairingError) {
              return true;
            }
            return false;
          },
          listener: (context, state) {
            if (state is PairingError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                ),
              );
            } else if (state is PairingConnected && !_hasNavigated) {
              _hasNavigated = true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Successfully connected!'),
                  backgroundColor: AppColors.success,
                ),
              );
              // Use addPostFrameCallback to ensure navigation happens after build cycle
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop(true);
                }
              });
            }
          },
          builder: (context, state) {
            if (state is PairingLoading) {
              return _buildLoading(state.message);
            }
            
            if (state is PairingCodeGenerated) {
              return _buildCodeDisplay(context, state);
            }
            
            if (state is PairingConnected) {
              return _buildConnected(context, state);
            }
            
            // Default: show create/join options
            return _buildPairingOptions(context);
          },
        ),
      ),
    );
  }

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primaryAccent),
          const SizedBox(height: 16),
          Text(message, style: AppTypography.bodyTextSecondary),
        ],
      ),
    );
  }

  Widget _buildPairingOptions(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab bar for Create/Join
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primaryAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.secondaryText,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Create Session'),
                Tab(text: 'Join Session'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Tab content
          SizedBox(
            height: 350,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreateTab(context),
                _buildJoinTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent.withAlpha(26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.devices_outlined,
                      color: AppColors.primaryAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Host a Session',
                          style: AppTypography.sectionHeader,
                        ),
                        Text(
                          'Share the code with other devices',
                          style: AppTypography.metadata,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'A pairing code will be generated that other devices can use to connect to your session. The code expires after 5 minutes.',
                style: AppTypography.bodyTextSecondary,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Generate Pairing Code',
                  icon: Icons.qr_code_2_outlined,
                  onPressed: () {
                    context.read<PairingBloc>().add(const PairingSessionCreated());
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJoinTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryAccent.withAlpha(26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.link_outlined,
                      color: AppColors.secondaryAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Join a Session',
                          style: AppTypography.sectionHeader,
                        ),
                        Text(
                          'Enter the code from another device',
                          style: AppTypography.metadata,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Code input field
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: TextField(
                  controller: _codeController,
                  focusNode: _codeFocusNode,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: AppTypography.codeText.copyWith(
                    fontSize: 28,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: '------',
                    hintStyle: AppTypography.codeText.copyWith(
                      fontSize: 28,
                      letterSpacing: 8,
                      color: AppColors.secondaryText,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    UpperCaseTextFormatter(),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Connect',
                  icon: Icons.link,
                  onPressed: _codeController.text.length == 6
                      ? () {
                          context.read<PairingBloc>().add(
                            PairingSessionJoined(_codeController.text),
                          );
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCodeDisplay(BuildContext context, PairingCodeGenerated state) {
    final minutes = state.timeRemaining.inMinutes;
    final seconds = state.timeRemaining.inSeconds % 60;
    final timeString = '$minutes:${seconds.toString().padLeft(2, '0')}';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AppCard(
            child: Column(
              children: [
                const Icon(
                  Icons.devices_outlined,
                  size: 48,
                  color: AppColors.primaryAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your Pairing Code',
                  style: AppTypography.sectionHeader,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter this code on another device',
                  style: AppTypography.bodyTextSecondary,
                ),
                const SizedBox(height: 24),
                // Large code display
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryAccent.withAlpha(77),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    state.pairingCode,
                    style: AppTypography.codeText.copyWith(
                      fontSize: 36,
                      letterSpacing: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Timer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: state.isCodeExpired 
                          ? AppColors.error 
                          : AppColors.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.isCodeExpired ? 'Expired' : timeString,
                      style: AppTypography.metadata.copyWith(
                        color: state.isCodeExpired 
                            ? AppColors.error 
                            : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Copy button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: state.pairingCode),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied!')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                    ),
                    if (state.isCodeExpired)
                      TextButton.icon(
                        onPressed: () {
                          context.read<PairingBloc>().add(
                            const PairingCodeRefreshed(),
                          );
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Waiting indicator
          AppCard(
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Waiting for devices to join...',
                  style: AppTypography.bodyTextSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () {
              context.read<PairingBloc>().add(const PairingSessionLeft());
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnected(BuildContext context, PairingConnected state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AppCard(
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_outlined,
                  size: 48,
                  color: AppColors.success,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connected!',
                  style: AppTypography.sectionHeader.copyWith(
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${state.deviceCount} device${state.deviceCount != 1 ? 's' : ''} in session',
                  style: AppTypography.bodyTextSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Text input formatter to convert to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
