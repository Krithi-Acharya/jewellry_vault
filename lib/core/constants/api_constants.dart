class ApiConstants {
  // NOTE: there's no /auth/login or /auth/sync-user on the backend.
  // Sign-in happens entirely through Firebase on the client; the backend's
  // verifyToken middleware auto-provisions the Postgres user row on the
  // first authenticated request. No separate "sync" call is needed.
  static const String dashboard = '/dashboard';
  static const String closet = '/closet';
}
