import 'package:dio/dio.dart';
import 'dart:io';
import '../../../core/config/app_config.dart';
import '../../../services/auth_service.dart';

class ClosetService {
  static final ClosetService instance = ClosetService._internal();
  ClosetService._internal();

  final Dio _dio = Dio();

  // Helper to add Auth token
  Future<Options> _getAuthOptions() async {
    final token = await AuthService.instance.getIdToken();
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
  }

  // Upload item (returns item and job metadata)
  Future<Map<String, dynamic>> uploadItem(File imageFile) async {
    final options = await _getAuthOptions();
    
    // Multipart setup
    String fileName = imageFile.path.split('/').last;
    FormData formData = FormData.fromMap({
      "image": await MultipartFile.fromFile(imageFile.path, filename: fileName),
    });

    final url = '${AppConfig.apiBaseUrl}/items/upload';
    
    final response = await _dio.post(
      url,
      data: formData,
      options: options,
    );
    
    return response.data['data']; // Returns { item: {...}, job: {...} }
  }

  // Upload item using bytes (supports Web)
  Future<Map<String, dynamic>> uploadItemBytes(List<int> bytes, String fileName) async {
    final options = await _getAuthOptions();
    
    FormData formData = FormData.fromMap({
      "image": MultipartFile.fromBytes(bytes, filename: fileName),
    });

    final url = '${AppConfig.apiBaseUrl}/items/upload';
    
    final response = await _dio.post(
      url,
      data: formData,
      options: options,
    );
    
    return response.data['data'];
  }
}
