import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'core/config/app_config.dart';

class ApiService {
  // This pointed at a standalone prototype server (localhost:3000/api/closet)
  // that predates the real backend and no longer exists, which is why the
  // Dashboard could never load items. AppConfig.apiBaseUrl is the same
  // backend every other screen (Closet, Item Details, Upload) already
  // talks to.
  static String get baseUrl => AppConfig.apiBaseUrl;

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
      Uri.parse('$baseUrl/items'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      // The real API wraps results as {success, data: [...], meta}, not a
      // bare array.
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> data = body['data'] as List<dynamic>? ?? [];
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load closet items (${response.statusCode})');
  }

  // addClosetItem/updateClosetItem/deleteClosetItem below still point at the
  // same nonexistent /closet path as the old baseUrl did. They're currently
  // unreachable from the UI - the sidebar's "My Closet" and "Add New Item"
  // taps both redirect to the real /closet and /upload routes (which use
  // ClosetService/UploadProvider) instead of the inline _ClosetView/
  // _AddItemView these methods back. Left as-is rather than guessing at the
  // real /items create-schema contract for a code path nothing currently
  // calls; worth deleting alongside _ClosetView/_AddItemView in a follow-up
  // cleanup rather than maintaining two parallel item-creation paths.

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
