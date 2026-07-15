import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Singleton instance
  static final AuthService instance = AuthService._internal();

  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign in
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign up
  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Send password reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Helper to get ID token for backend requests
  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Pass forceRefresh: false to use cached token if still valid
      return await user.getIdToken();
    }
    return null;
  }
}
