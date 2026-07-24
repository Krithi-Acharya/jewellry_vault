import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

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

  /// Fetch the dashboard greeting payload, e.g. { username, message }.
  /// `username` is the server-resolved display name (falls back to the
  /// email's local part server-side if none has been synced yet).
  static Future<Map<String, dynamic>> fetchDashboard() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load dashboard (${response.statusCode})');
  }

  /// Push the name typed at signup to the backend, once, right after the
  /// Firebase account is created. Safe to call again later too (it's a
  /// plain UPDATE, not an insert).
  static Future<void> syncUser({required String displayName}) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/sync-user'),
      headers: headers,
      body: jsonEncode({'displayName': displayName}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to sync user profile (${response.statusCode})');
    }
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

  /// Uploads a photo of a new piece and asks the backend to run it through
  /// the AI model. The server is expected to store the image (returning a
  /// durable `imageUrl`, e.g. from cloud storage) and return the extracted
  /// details in one shot:
  /// { imageUrl, title, category, brand, color, season }
  ///
  /// This does NOT save the item to the closet yet — call [addClosetItem]
  /// with the returned map (plus any user edits) to persist it.
  static Future<Map<String, dynamic>> analyzeItemImage(XFile image) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }
    final token = await user.getIdToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/closet/analyze'),
    )..headers['Authorization'] = 'Bearer $token';

    final bytes = await image.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: image.name.isNotEmpty ? image.name : 'item.jpg',
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to analyze image (${response.statusCode})');
  }

  /// Fetch every saved look ("outfit") for the logged-in user.
  /// Each entry is expected to look like: { id, itemIds, createdAt }.
  /// Item details/images are resolved client-side against the closet list
  /// that's already loaded, so the backend doesn't need to duplicate them.
  static Future<List<Map<String, dynamic>>> fetchOutfits() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/outfits'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load outfits (${response.statusCode})');
  }

  /// Combine selected closet items into a new saved look.
  static Future<Map<String, dynamic>> createOutfit(List<String> itemIds) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/outfits'),
      headers: headers,
      body: jsonEncode({'itemIds': itemIds}),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create look (${response.statusCode})');
  }

  /// Uploads a single photo of a full outfit and saves it directly as a
  /// look — this is the flow the Outfits tab's camera/gallery picker
  /// actually uses (as opposed to [createOutfit], which composes a look
  /// out of already-catalogued closet items). Mirrors [analyzeItemImage]'s
  /// multipart upload pattern. Expects the server to store the image and
  /// return the saved look in one shot: { id, imageUrl, createdAt }.
  static Future<Map<String, dynamic>> createOutfitFromPhoto(XFile image) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }
    final token = await user.getIdToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/outfits/photo'),
    )..headers['Authorization'] = 'Bearer $token';

    final bytes = await image.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: image.name.isNotEmpty ? image.name : 'outfit.jpg',
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to save outfit photo (${response.statusCode})');
  }

  /// Remove a saved look.
  static Future<void> deleteOutfit(String id) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/outfits/$id'),
      headers: headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete look (${response.statusCode})');
    }
  }
}
