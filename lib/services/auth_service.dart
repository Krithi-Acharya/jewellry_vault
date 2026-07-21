import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import '../core/config/app_config.dart';
import '../core/constants/api_constants.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stores the current session's JWT token in memory
  String? _sessionToken;

  // Sign in
  Future<UserCredential> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Store the JWT in this session right after successful login
    _sessionToken = await credential.user?.getIdToken();

    return credential;
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
    _sessionToken = null;
  }

  // Send password reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Helper to get ID token for backend requests
  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  // Reads the token stored in this session (fast, no async needed)
  String? get currentSessionToken => _sessionToken;

  // Sync user profile to PostgreSQL backend
  Future<void> syncUserToBackend({
    String? displayName,
    String? firstName,
    String? lastName,
  }) async {
    final token = await getIdToken();
    if (token == null) return;

    try {
      final dio = Dio();
      final url = '${AppConfig.apiBaseUrl}${ApiConstants.syncUser}';
      await dio.post(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          if (displayName != null) 'displayName': displayName,
          if (firstName != null) 'firstName': firstName,
          if (lastName != null) 'lastName': lastName,
        },
      );
    } catch (e) {
      // In production, we'd log this securely or queue it for retry
      print('Failed to sync user to backend: $e');
    }
  }
}
