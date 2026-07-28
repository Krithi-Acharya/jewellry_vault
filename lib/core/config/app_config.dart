import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Base URL for the backend, e.g. http://10.0.2.2:3000/api
  /// (backend routes are all under /api — no /v1 prefix).
  static String get apiBaseUrl {
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    // Fallback when .env doesn't set API_BASE_URL — mirrors your backend's
    // default PORT=3000 and /api route prefix.
    if (kIsWeb) return 'http://localhost:3000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    return 'http://localhost:3000/api';
  }
}
