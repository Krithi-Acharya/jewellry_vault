import '../core/constants/api_constants.dart';
import 'api_service.dart';
import 'prompt_service.dart';

class Lookbook {
  final int id;
  final String name;
  final List<RecommendedItem> items;

  Lookbook({
    required this.id,
    required this.name,
    required this.items,
  });

  factory Lookbook.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((e) => RecommendedItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return Lookbook(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Saved Lookbook',
      items: itemsList,
    );
  }
}

class LookbookService {
  static final LookbookService instance = LookbookService._internal();
  LookbookService._internal();

  Future<Lookbook> createLookbookFromOutfit({
    required int garmentItemId,
    required List<int> jewelryItemIds,
    String? name,
  }) async {
    final response = await ApiService.instance.client.post(
      ApiConstants.lookbookFromOutfit,
      data: {
        'garmentItemId': garmentItemId,
        'jewelryItemIds': jewelryItemIds,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );

    if ((response.statusCode == 200 || response.statusCode == 201) && response.data['success'] == true) {
      return Lookbook.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to save lookbook');
  }

  Future<List<Lookbook>> fetchLookbooks() async {
    final response = await ApiService.instance.client.get(
      ApiConstants.lookbooks,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = (response.data['data'] as List<dynamic>?)
              ?.map((e) => Lookbook.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return list;
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch lookbooks');
  }
}
