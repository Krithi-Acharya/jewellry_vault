import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/api_constants.dart';
import '../../../services/auth_service.dart';

class AdminService {
  static final AdminService instance = AdminService._internal();
  AdminService._internal();

  final Dio _dio = Dio();

  Future<Options> _authOptions() async {
    final token = await AuthService.instance.getIdToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ── Stats ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchStats() async {
    final response = await _dio.get(
      '${AppConfig.apiBaseUrl}${ApiConstants.adminStats}',
      options: await _authOptions(),
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  // ── Activity feed ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchActivity() async {
    final response = await _dio.get(
      '${AppConfig.apiBaseUrl}${ApiConstants.adminActivity}',
      options: await _authOptions(),
    );
    return List<Map<String, dynamic>>.from(response.data['data'] as List);
  }

  // ── AI Queue ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchQueue() async {
    final response = await _dio.get(
      '${AppConfig.apiBaseUrl}${ApiConstants.adminQueue}',
      options: await _authOptions(),
    );
    return List<Map<String, dynamic>>.from(response.data['data'] as List);
  }

  Future<void> retryItem(int itemId) async {
    await _dio.post(
      '${AppConfig.apiBaseUrl}${ApiConstants.adminItemRetry(itemId)}',
      options: await _authOptions(),
    );
  }

  // ── Users ──────────────────────────────────────────────────────────────

  Future<({List<Map<String, dynamic>> users, int totalPages})> fetchUsers({
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _dio.get(
      '${AppConfig.apiBaseUrl}${ApiConstants.adminUsers}',
      queryParameters: {'page': page, 'limit': limit},
      options: await _authOptions(),
    );
    final data = List<Map<String, dynamic>>.from(response.data['data'] as List);
    final meta = response.data['meta'] as Map<String, dynamic>? ?? {};
    final totalPages = (meta['totalPages'] as int?) ?? 1;
    return (users: data, totalPages: totalPages);
  }

  Future<void> updateUserRole(int userId, String role) async {
    await _dio.patch(
      '${AppConfig.apiBaseUrl}${ApiConstants.adminUsers}/$userId/role',
      data: {'role': role},
      options: await _authOptions(),
    );
  }

  // ── Items ──────────────────────────────────────────────────────────────

  Future<({List<Map<String, dynamic>> items, int totalPages})> fetchItems({
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _dio.get(
      '${AppConfig.apiBaseUrl}${ApiConstants.adminItems}',
      queryParameters: {'page': page, 'limit': limit},
      options: await _authOptions(),
    );
    final data = List<Map<String, dynamic>>.from(response.data['data'] as List);
    final meta = response.data['meta'] as Map<String, dynamic>? ?? {};
    final totalPages = (meta['totalPages'] as int?) ?? 1;
    return (items: data, totalPages: totalPages);
  }

  Future<void> deleteItem(int itemId) async {
    await _dio.delete(
      '${AppConfig.apiBaseUrl}${ApiConstants.adminItems}/$itemId',
      options: await _authOptions(),
    );
  }
}
