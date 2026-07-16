import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  // Android emulator -> 10.0.2.2 maps to your computer's localhost.
  // iOS simulator / web -> localhost works directly.
  // Physical device (either OS) -> replace with your computer's LAN IP,
  //   e.g. 'http://192.168.1.42:3000/api', and make sure the phone is on
  //   the same Wi-Fi network as the backend.
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    return 'http://localhost:3000/api';
  }

  static Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Handing over the ID card!
    };
  }

  /// Fetch every closet item belonging to the logged-in user.
  static Future<List<Map<String, dynamic>>> fetchClosetItems() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/closet'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load closet items (${response.statusCode})');
  }

  /// Catalog a new item. Returns the saved item, including its server-assigned id.
  static Future<Map<String, dynamic>> addClosetItem(
    Map<String, dynamic> item,
  ) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/closet'),
      headers: headers,
      body: jsonEncode(item),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to add item (${response.statusCode})');
  }

  /// Update fields on an existing item, e.g. {'isFavorite': true}.
  static Future<Map<String, dynamic>> updateClosetItem(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/closet/$id'),
      headers: headers,
      body: jsonEncode(updates),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to update item (${response.statusCode})');
  }

  /// Remove an item from the vault.
  static Future<void> deleteClosetItem(String id) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/closet/$id'),
      headers: headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete item (${response.statusCode})');
    }
  }
}
