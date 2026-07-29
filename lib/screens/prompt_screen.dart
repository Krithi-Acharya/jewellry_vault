import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../services/prompt_service.dart';
import '../services/lookbook_service.dart';

class PromptScreen extends StatefulWidget {
  const PromptScreen({super.key});

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen> {
  final TextEditingController _promptController = TextEditingController();

  bool _isLoading = false;
  OutfitResponse? _outfitResponse;
  String? _errorMessage;
  final Set<int> _savingOutfitGarmentIds = {};
  final Set<int> _savedOutfitGarmentIds = {};

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _submitPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isLoading = true;
      _outfitResponse = null;
      _errorMessage = null;
    });

    try {
      final response = await PromptService.instance.getOutfitRecommendations(prompt);
      setState(() {
        _outfitResponse = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to get outfit recommendations. Please check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToLookbook(OutfitSuggestion outfit) async {
    final garmentId = outfit.garment.id;
    if (_savingOutfitGarmentIds.contains(garmentId) || _savedOutfitGarmentIds.contains(garmentId)) return;

    setState(() {
      _savingOutfitGarmentIds.add(garmentId);
    });

    try {
      final jewelryIds = outfit.jewelryRecommendations.map((j) => j.item.id).toList();
      final lookbook = await LookbookService.instance.createLookbookFromOutfit(
        garmentItemId: garmentId,
        jewelryItemIds: jewelryIds,
        name: '${outfit.garment.displayTitle} Look',
      );

      if (mounted) {
        setState(() {
          _savedOutfitGarmentIds.add(garmentId);
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text('Saved "${lookbook.name}" to Lookbooks!'),
            backgroundColor: AppColors.primaryEmerald,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                Navigator.of(context).pushNamed('/lookbooks');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text('Failed to save lookbook: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingOutfitGarmentIds.remove(garmentId);
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFFE8E2D9),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primaryText, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text('Ask JewelVault', style: AppTypography.headingMedium),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined, color: AppColors.primaryText),
            tooltip: 'View Saved Lookbooks',
            onPressed: () => Navigator.of(context).pushNamed('/lookbooks'),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

            Text(
              'What are you dressing for?',
              style: AppTypography.headingSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'e.g. "I want a dress for a wedding" — we\'ll find candidate outfits and jewelry pairings from your closet.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),

            // Prompt Input Box
            TextField(
              controller: _promptController,
              maxLines: 4,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.primaryText),
              decoration: InputDecoration(
                hintText: 'Type what you need an outfit for...',
                hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primaryEmerald,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.all(18),
              ),
            ),
            const SizedBox(height: 20),

            // Get Suggestion Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPrompt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Get Suggestion',
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 28),

            // Error display
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),

            // AI Outfit Result Area
            if (_outfitResponse != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _outfitResponse!.suggestionText,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white,
                          height: 1.6,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_outfitResponse!.outfits.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Recommended Outfit Combinations',
                  style: AppTypography.headingSmall,
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _outfitResponse!.outfits.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final outfit = _outfitResponse!.outfits[index];
                    final garment = outfit.garment;
                    final jewelryList = outfit.jewelryRecommendations;
                    final isSaving = _savingOutfitGarmentIds.contains(garment.id);
                    final isSaved = _savedOutfitGarmentIds.contains(garment.id);
                    final matchScore = outfit.matchScore;

                    final bool isHighMatch = matchScore >= 70;
                    final bool isMediumMatch = matchScore >= 50 && matchScore < 70;
                    final Color badgeColor = isHighMatch
                        ? AppColors.primaryEmerald
                        : (isMediumMatch ? const Color(0xFFD97706) : AppColors.secondaryText);
                    final String badgeText = isHighMatch
                        ? 'High Match'
                        : (isMediumMatch ? 'Possible Match' : 'Vault Option');

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Base Garment Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.borderLight, width: 1),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: garment.thumbnailUrl != null
                                      ? Image.network(
                                          garment.thumbnailUrl!,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 80,
                                            height: 80,
                                            color: AppColors.borderLight,
                                            child: const Icon(Icons.checkroom, color: AppColors.secondaryText, size: 28),
                                          ),
                                        )
                                      : Container(
                                          width: 80,
                                          height: 80,
                                          color: AppColors.borderLight,
                                          child: const Icon(Icons.checkroom, color: AppColors.secondaryText, size: 28),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isHighMatch ? Icons.auto_awesome : Icons.checkroom_outlined,
                                                size: 11,
                                                color: badgeColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                badgeText,
                                                style: AppTypography.labelSmall.copyWith(
                                                  color: badgeColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Outfit ${index + 1}: ${garment.displayTitle}',
                                      style: AppTypography.headingSmall.copyWith(fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Base Garment • ${garment.categoryName}',
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: (isSaving || isSaved) ? null : () => _saveToLookbook(outfit),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: isSaved ? AppColors.primaryEmerald.withValues(alpha: 0.1) : Colors.transparent,
                                  foregroundColor: AppColors.primaryEmerald,
                                  side: BorderSide(
                                    color: isSaved ? AppColors.primaryEmerald.withValues(alpha: 0.4) : AppColors.primaryEmerald,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                icon: isSaving
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryEmerald),
                                      )
                                    : Icon(isSaved ? Icons.check : Icons.bookmark_add_outlined, size: 16),
                                label: Text(
                                  isSaving
                                      ? 'Saving...'
                                      : (isSaved ? 'Saved' : 'Save to Lookbook'),
                                  style: AppTypography.labelSmall.copyWith(color: AppColors.primaryEmerald),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),
                          const Divider(color: AppColors.borderLight, height: 1),
                          const SizedBox(height: 14),

                          // Jewelry recommendations
                          Text(
                            'Recommended Jewelry Pairings',
                            style: AppTypography.labelLarge.copyWith(fontSize: 13, color: AppColors.primaryText, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),

                          if (jewelryList.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No matching jewelry items in your closet yet. Upload pieces to complete this outfit!',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.mutedText),
                              ),
                            )
                          else
                            SizedBox(
                              height: 125,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: jewelryList.length,
                                separatorBuilder: (context, idx) => const SizedBox(width: 12),
                                itemBuilder: (context, jIdx) {
                                  final jItem = jewelryList[jIdx].item;
                                  return Container(
                                    width: 100,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.borderLight),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: jItem.thumbnailUrl != null
                                                ? Image.network(
                                                    jItem.thumbnailUrl!,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => Container(
                                                      color: AppColors.borderLight,
                                                      child: const Icon(Icons.style, color: AppColors.secondaryText, size: 20),
                                                    ),
                                                  )
                                                : Container(
                                                    color: AppColors.borderLight,
                                                    child: const Icon(Icons.style, color: AppColors.secondaryText, size: 20),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          jItem.displayTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.labelSmall.copyWith(fontSize: 11, color: AppColors.primaryText, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          jItem.categoryName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    ),
    ),
    );
  }
}
