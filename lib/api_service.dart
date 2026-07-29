import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
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
