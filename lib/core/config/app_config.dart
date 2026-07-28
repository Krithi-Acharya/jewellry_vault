import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl {
    if (dotenv.isInitialized) {
      return dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000/api/v1';
    }
    return 'http://localhost:5000/api/v1';
  }
}
