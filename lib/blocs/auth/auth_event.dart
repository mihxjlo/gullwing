import 'package:equatable/equatable.dart';

/// Auth Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  
  @override
  List<Object?> get props => [];
}

/// Check current auth state
class AuthCheckRequested extends AuthEvent {}

/// Sign in anonymously
class AuthSignInAnonymousRequested extends AuthEvent {}

/// Sign out
class AuthSignOutRequested extends AuthEvent {}

/// Auth state changed (from stream)
class AuthStateChanged extends AuthEvent {
  final bool isAuthenticated;
  final String? userId;
  
  const AuthStateChanged({
    required this.isAuthenticated,
    this.userId,
  });
  
  @override
  List<Object?> get props => [isAuthenticated, userId];
}
