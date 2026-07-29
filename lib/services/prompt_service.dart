import '../core/config/app_config.dart';
import '../core/constants/api_constants.dart';
import 'api_service.dart';

String? resolveImageUrl(String? rawUrl) {
  if (rawUrl == null) return null;
  if (rawUrl.startsWith('/')) {
    return '${AppConfig.apiBaseUrl.replaceAll('/api/v1', '')}$rawUrl';
  }
  return rawUrl;
}

class RecommendedItem {
  final int id;
  final String categoryName;
  final String displayTitle;
  final String? thumbnailUrl;
  final List<String> images;

  RecommendedItem({
    required this.id,
    required this.categoryName,
    required this.displayTitle,
    this.thumbnailUrl,
    required this.images,
  });

  factory RecommendedItem.fromJson(Map<String, dynamic> json) {
    final String? rawThumb = (json['thumbnail_url'] ?? json['thumbnailUrl']) as String?;
    final String? resolvedThumb = resolveImageUrl(rawThumb);

    final rawImages = ((json['images'] ?? []) as List<dynamic>).map((e) => e.toString()).toList();
    final resolvedImages = rawImages.map((img) => resolveImageUrl(img)!).toList();

    return RecommendedItem(
      id: json['id'] as int? ?? 0,
      categoryName: (json['categoryName'] ?? json['category_name'] ?? '') as String,
      displayTitle: (json['display_title'] ?? json['displayTitle'] ?? 'Closet Item') as String,
      thumbnailUrl: resolvedThumb,
      images: resolvedImages,
    );
  }
}

class PromptResponse {
  final String prompt;
  final String suggestionText;
  final List<RecommendedItem> recommendedItems;

  PromptResponse({
    required this.prompt,
    required this.suggestionText,
    required this.recommendedItems,
  });

  factory PromptResponse.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['recommendedItems'] as List<dynamic>?)
            ?.map((e) => RecommendedItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return PromptResponse(
      prompt: json['prompt'] as String? ?? '',
      suggestionText: json['suggestionText'] as String? ?? '',
      recommendedItems: itemsList,
    );
  }
}

class JewelryRecommendation {
  final RecommendedItem item;
  final int score;

  JewelryRecommendation({required this.item, required this.score});

  factory JewelryRecommendation.fromJson(Map<String, dynamic> json) {
    return JewelryRecommendation(
      item: RecommendedItem.fromJson(json['item'] as Map<String, dynamic>),
      score: json['score'] as int? ?? 0,
    );
  }
}

class OutfitSuggestion {
  final RecommendedItem garment;
  final int matchScore;
  final List<JewelryRecommendation> jewelryRecommendations;

  OutfitSuggestion({
    required this.garment,
    required this.matchScore,
    required this.jewelryRecommendations,
  });

  factory OutfitSuggestion.fromJson(Map<String, dynamic> json) {
    final jList = (json['jewelryRecommendations'] as List<dynamic>?)
            ?.map((e) => JewelryRecommendation.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return OutfitSuggestion(
      garment: RecommendedItem.fromJson(json['garment'] as Map<String, dynamic>),
      matchScore: json['matchScore'] as int? ?? 0,
      jewelryRecommendations: jList,
    );
  }
}

class OutfitResponse {
  final String prompt;
  final String suggestionText;
  final List<OutfitSuggestion> outfits;

  OutfitResponse({
    required this.prompt,
    required this.suggestionText,
    required this.outfits,
  });

  factory OutfitResponse.fromJson(Map<String, dynamic> json) {
    final outfitList = (json['outfits'] as List<dynamic>?)
            ?.map((e) => OutfitSuggestion.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return OutfitResponse(
      prompt: json['prompt'] as String? ?? '',
      suggestionText: json['suggestionText'] as String? ?? '',
      outfits: outfitList,
    );
  }
}

class PromptService {
  static final PromptService instance = PromptService._internal();
  PromptService._internal();

  Future<PromptResponse> getPromptSuggestion(String prompt) async {
    final response = await ApiService.instance.client.post(
      ApiConstants.promptRecommendation,
      data: {'prompt': prompt},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return PromptResponse.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch recommendation');
  }

  Future<OutfitResponse> getOutfitRecommendations(String prompt) async {
    final response = await ApiService.instance.client.post(
      ApiConstants.outfitRecommendation,
      data: {'prompt': prompt},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return OutfitResponse.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch outfit recommendations');
  }
}
