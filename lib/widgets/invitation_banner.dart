import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/discovery_service.dart';
import '../blocs/pairing/pairing.dart';
import '../theme/app_typography.dart';

/// Widget that shows a banner when an invitation is received
/// Should be placed in the widget tree to listen for invitations
class InvitationBanner extends StatefulWidget {
  final Widget child;
  
  const InvitationBanner({
    super.key,
    required this.child,
  });

  @override
  State<InvitationBanner> createState() => _InvitationBannerState();
}

class _InvitationBannerState extends State<InvitationBanner> {
  StreamSubscription<Invitation>? _invitationSubscription;
  Invitation? _currentInvitation;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _listenForInvitations();
  }

  @override
  void dispose() {
    _invitationSubscription?.cancel();
    super.dispose();
  }

  void _listenForInvitations() {
    _invitationSubscription = discoveryService.invitations.listen((invitation) {
      debugPrint('InvitationBanner: Received invitation from ${invitation.hostName}');
      setState(() {
        _currentInvitation = invitation;
      });
    });
  }

  Future<void> _acceptInvitation() async {
    if (_currentInvitation == null || _isJoining) return;
    
    setState(() {
      _isJoining = true;
    });
    
    debugPrint('InvitationBanner: Accepting invitation to session ${_currentInvitation!.sessionId}');
    
    // Join the session directly by ID via PairingBloc
    final pairingBloc = context.read<PairingBloc>();
    pairingBloc.add(PairingSessionJoinedById(_currentInvitation!.sessionId));
    

    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() {
        _currentInvitation = null;
        _isJoining = false;
      });
    }
  }

  void _declineInvitation() {
    debugPrint('InvitationBanner: Declined invitation');
    setState(() {
      _currentInvitation = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Invitation banner
        if (_currentInvitation != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // WiFi icon
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.wifi,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Message
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clipboard Invitation',
                                    style: AppTypography.bodyText.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_currentInvitation!.hostName} is inviting you to share clipboards',
                                    style: AppTypography.metadata.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Actions
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: _isJoining ? null : _declineInvitation,
                                child: Text(
                                  'Decline',
                                  style: AppTypography.buttonText.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isJoining ? null : _acceptInvitation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF34D399),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isJoining
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(
                                        'Accept',
                                        style: AppTypography.buttonText.copyWith(
                                          color: const Color(0xFF34D399),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
