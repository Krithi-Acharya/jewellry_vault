import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../services/auth_service.dart';

class ClosetProvider extends ChangeNotifier {
  final Dio _dio = Dio();
  
  List<dynamic> _items = [];
  List<dynamic> get items => _items;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _searchQuery = '';
  String? _selectedCategory; // 'All', 'Clothing', 'Jewelry', 'Archived'

  Future<void> fetchItems() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await AuthService.instance.getIdToken();
      
      // Build query params
      Map<String, dynamic> queryParams = {};
      if (_selectedCategory != null && _selectedCategory != 'All' && _selectedCategory != 'Archived') {
        queryParams['category'] = _selectedCategory;
      }
      if (_selectedCategory == 'Archived') {
        queryParams['status'] = 'ARCHIVED';
      }

      final url = '${AppConfig.apiBaseUrl}/items';
      
      final response = await _dio.get(
        url,
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final List<dynamic> fetchedItems = response.data['data'];
      
      // Client-side search filtering (since backend doesn't have ?search yet)
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        _items = fetchedItems.where((item) {
          final cat = item['categoryName']?.toString().toLowerCase() ?? '';
          return cat.contains(query);
        }).toList();
      } else {
        _items = fetchedItems;
      }
    } catch (e) {
      print('Error fetching closet items: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    fetchItems();
  }

  void setCategory(String? category) {
    _selectedCategory = category;
    fetchItems();
  }
}
