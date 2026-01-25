import 'package:equatable/equatable.dart';

/// Auth States
abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

/// Initial state - checking auth
class AuthInitial extends AuthState {}

/// Loading auth state
class AuthLoading extends AuthState {}

/// User is authenticated
class AuthAuthenticated extends AuthState {
  final String userId;
  
  const AuthAuthenticated(this.userId);
  
  @override
  List<Object?> get props => [userId];
}

/// User is not authenticated
class AuthUnauthenticated extends AuthState {}

/// Auth error
class AuthError extends AuthState {
  final String message;
  
  const AuthError(this.message);
  
  @override
  List<Object?> get props => [message];
}
