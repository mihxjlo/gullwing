import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Auth BLoC
/// Manages user authentication state
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription? _authSubscription;
  
  AuthBloc({
    AuthRepository? authRepository,
  }) : _authRepository = authRepository ?? AuthRepository(),
       super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSignInAnonymousRequested>(_onSignInAnonymous);
    on<AuthSignOutRequested>(_onSignOut);
    on<AuthStateChanged>(_onStateChanged);
    
    // Listen to auth state changes
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      add(AuthStateChanged(
        isAuthenticated: user != null,
        userId: user?.uid,
      ));
    });
  }
  
  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = _authRepository.currentUser;
    if (user != null) {
      emit(AuthAuthenticated(user.uid));
    } else {
      emit(AuthUnauthenticated());
    }
  }
  
  Future<void> _onSignInAnonymous(
    AuthSignInAnonymousRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      final user = await _authRepository.signInAnonymously();
      emit(AuthAuthenticated(user.uid));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
  
  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      await _authRepository.signOut();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
  
  void _onStateChanged(
    AuthStateChanged event,
    Emitter<AuthState> emit,
  ) {
    if (event.isAuthenticated && event.userId != null) {
      emit(AuthAuthenticated(event.userId!));
    } else {
      emit(AuthUnauthenticated());
    }
  }
  
  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
