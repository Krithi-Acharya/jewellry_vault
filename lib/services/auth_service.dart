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

  // Fetches the caller's own backend profile. Used to decide whether to show
  // admin-only UI; always hits the network rather than trusting a cached
  // value, since a role can be changed by another admin mid-session.
  Future<bool> checkIsAdmin() async {
    final token = await getIdToken();
    if (token == null) return false;

    try {
      final dio = Dio();
      final url = '${AppConfig.apiBaseUrl}${ApiConstants.me}';
      final response = await dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final role = response.data?['data']?['user']?['usr_role'];
      return role == 'admin';
    } catch (e) {
      return false;
    }
  }

  // Fetches the caller's synced profile (role + display name) in one call.
  // The display name here is the one stored in Postgres via sync-user, which
  // is independent of Firebase Auth's own currentUser.displayName - that
  // field is only set if something explicitly calls updateProfile() on the
  // Firebase user, which this app never does, so it's null even for accounts
  // that provided a name on signup.
  Future<({bool isAdmin, String? displayName})> fetchProfile() async {
    final token = await getIdToken();
    if (token == null) return (isAdmin: false, displayName: null);

    try {
      final dio = Dio();
      final url = '${AppConfig.apiBaseUrl}${ApiConstants.me}';
      final response = await dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final user = response.data?['data']?['user'];
      return (
        isAdmin: user?['usr_role'] == 'admin',
        displayName: user?['usr_display_name'] as String?,
      );
    } catch (e) {
      return (isAdmin: false, displayName: null);
    }
  }
}
