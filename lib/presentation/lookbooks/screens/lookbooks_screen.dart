import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/lookbook_service.dart';

class LookbooksScreen extends StatefulWidget {
  const LookbooksScreen({super.key});

  @override
  State<LookbooksScreen> createState() => _LookbooksScreenState();
}

class _LookbooksScreenState extends State<LookbooksScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Lookbook> _lookbooks = [];

  @override
  void initState() {
    super.initState();
    _loadLookbooks();
  }

  Future<void> _loadLookbooks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await LookbookService.instance.fetchLookbooks();
      setState(() {
        _lookbooks = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load lookbooks. Please try again.';
        _isLoading = false;
      });
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
        title: Text('My Lookbooks', style: AppTypography.headingMedium),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryEmerald),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: AppTypography.bodyMedium),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadLookbooks,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryEmerald,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _lookbooks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.collections_bookmark_outlined, size: 56, color: AppColors.mutedText),
                            const SizedBox(height: 16),
                            Text(
                              'No Saved Lookbooks Yet',
                              style: AppTypography.headingSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Use "Ask JewelVault" to generate outfit combinations and save your favorites here.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLookbooks,
                      color: AppColors.primaryEmerald,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _lookbooks.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final lookbook = _lookbooks[index];
                          final garmentItem = lookbook.items.isNotEmpty ? lookbook.items.first : null;
                          final jewelryItems = lookbook.items.length > 1 ? lookbook.items.sublist(1) : [];

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.bookmark, color: AppColors.accentGold, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        lookbook.name,
                                        style: AppTypography.headingSmall.copyWith(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Base Garment Item Row
                                if (garmentItem != null)
                                  Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: garmentItem.thumbnailUrl != null
                                            ? Image.network(
                                                garmentItem.thumbnailUrl!,
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Container(
                                                  width: 60,
                                                  height: 60,
                                                  color: AppColors.borderLight,
                                                  child: const Icon(Icons.checkroom, color: AppColors.secondaryText),
                                                ),
                                              )
                                            : Container(
                                                width: 60,
                                                height: 60,
                                                color: AppColors.borderLight,
                                                child: const Icon(Icons.checkroom, color: AppColors.secondaryText),
                                              ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              garmentItem.displayTitle,
                                              style: AppTypography.labelLarge.copyWith(fontSize: 14),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Base Garment • ${garmentItem.categoryName}',
                                              style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                // Jewelry pairings
                                if (jewelryItems.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    'Paired Jewelry (${jewelryItems.length})',
                                    style: AppTypography.labelSmall.copyWith(color: AppColors.mutedText),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 50,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: jewelryItems.length,
                                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                                      itemBuilder: (context, jIdx) {
                                        final jItem = jewelryItems[jIdx];
                                        return Tooltip(
                                          message: jItem.displayTitle,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: jItem.thumbnailUrl != null
                                                ? Image.network(
                                                    jItem.thumbnailUrl!,
                                                    width: 50,
                                                    height: 50,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => Container(
                                                      width: 50,
                                                      height: 50,
                                                      color: AppColors.borderLight,
                                                      child: const Icon(Icons.style, color: AppColors.secondaryText, size: 20),
                                                    ),
                                                  )
                                                : Container(
                                                    width: 50,
                                                    height: 50,
                                                    color: AppColors.borderLight,
                                                    child: const Icon(Icons.style, color: AppColors.secondaryText, size: 20),
                                                  ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
