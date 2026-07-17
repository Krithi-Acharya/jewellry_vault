import 'package:dio/dio.dart';
import '../core/config/app_config.dart';
import '../core/constants/api_constants.dart';
import 'auth_service.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();

  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Define public endpoints that don't need a token
          const publicEndpoints = [
            ApiConstants.login,
          ];

          if (!publicEndpoints.contains(options.path)) {
            // Use the token cached in this session
            final token = AuthService.instance.currentSessionToken;
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Centralized error handling can be done here
          return handler.next(e);
        },
      ),
    );
  }

  Dio get client => _dio;
}