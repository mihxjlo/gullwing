import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

/// Authentication Repository
/// Handles user authentication using Firebase Auth
class AuthRepository {
  final FirebaseService _firebase;
  
  AuthRepository({FirebaseService? firebase}) 
      : _firebase = firebase ?? FirebaseService.instance;
  
  /// Get current user
  User? get currentUser => _firebase.auth.currentUser;
  
  /// Get current user ID
  String? get userId => currentUser?.uid;
  
  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _firebase.auth.authStateChanges();
  
  /// Sign in anonymously
  /// Returns the User on success, throws on failure
  Future<User> signInAnonymously() async {
    try {
      final result = await _firebase.auth.signInAnonymously();
      if (result.user == null) {
        throw Exception('Anonymous sign in failed - no user returned');
      }
      return result.user!;
    } on FirebaseAuthException catch (e) {
      throw Exception('Authentication failed: ${e.message}');
    }
  }
  
  /// Sign in with email and password
  Future<User> signInWithEmail(String email, String password) async {
    try {
      final result = await _firebase.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user == null) {
        throw Exception('Sign in failed - no user returned');
      }
      return result.user!;
    } on FirebaseAuthException catch (e) {
      throw Exception('Authentication failed: ${e.message}');
    }
  }
  
  /// Create account with email and password
  Future<User> createAccountWithEmail(String email, String password) async {
    try {
      final result = await _firebase.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user == null) {
        throw Exception('Account creation failed - no user returned');
      }
      return result.user!;
    } on FirebaseAuthException catch (e) {
      throw Exception('Account creation failed: ${e.message}');
    }
  }
  
  /// Sign out current user
  Future<void> signOut() async {
    await _firebase.auth.signOut();
  }
  
  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;
}
