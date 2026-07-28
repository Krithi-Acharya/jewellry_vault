import 'package:dio/dio.dart';
import '../core/config/app_config.dart';
import 'auth_service.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();

  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Every route on this backend runs through verifyToken server-side,
          // so every request needs the Firebase ID token attached — there
          // are no public endpoints to exempt.
          final token = await AuthService.instance.getIdToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          return handler.next(e);
        },
      ),
    );
  }

  Dio get client => _dio;
}
