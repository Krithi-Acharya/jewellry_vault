import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/lookbook_service.dart';

String? _resolveImageUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.isEmpty) return null;
  if (rawUrl.startsWith('/')) {
    return '${AppConfig.apiBaseUrl.replaceAll('/api/v1', '')}$rawUrl';
  }
  return rawUrl;
}

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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primaryText, size: 18),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text('My Lookbooks', style: AppTypography.headingMedium),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryEmerald),
            onPressed: _loadLookbooks,
            tooltip: 'Refresh Lookbooks',
          ),
          const SizedBox(width: 8),
        ],
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
                        const Icon(Icons.error_outline_rounded, size: 52, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: AppTypography.bodyMedium),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadLookbooks,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryEmerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _lookbooks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: AppColors.accentGoldLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.collections_bookmark_outlined,
                                size: 48,
                                color: AppColors.accentGold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No Saved Lookbooks Yet',
                              style: AppTypography.headingSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Save curated outfit and jewelry pairings from your vault to build your digital lookbook.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.secondaryText),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/closet'),
                              icon: const Icon(Icons.checkroom_outlined, size: 18),
                              label: const Text('Explore Closet'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryEmerald,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLookbooks,
                      color: AppColors.primaryEmerald,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Curated Styling Archives',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isWide = constraints.maxWidth > 800;
                                    final crossAxisCount = isWide ? 2 : 1;

                                    if (isWide) {
                                      return GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 20,
                                          mainAxisSpacing: 20,
                                          mainAxisExtent: 310,
                                        ),
                                        itemCount: _lookbooks.length,
                                        itemBuilder: (context, index) {
                                          return _LookbookCard(lookbook: _lookbooks[index]);
                                        },
                                      );
                                    }

                                    return ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _lookbooks.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 20),
                                      itemBuilder: (context, index) {
                                        return _LookbookCard(lookbook: _lookbooks[index]);
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }
}

class _LookbookCard extends StatelessWidget {
  final Lookbook lookbook;

  const _LookbookCard({required this.lookbook});

  @override
  Widget build(BuildContext context) {
    final garmentItem = lookbook.items.isNotEmpty ? lookbook.items.first : null;
    final jewelryItems = lookbook.items.length > 1 ? lookbook.items.sublist(1) : [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryEmerald.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card Header: Icon + Title + Count Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentGoldLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.collections_bookmark,
                  color: AppColors.accentGold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lookbook.name,
                  style: AppTypography.headingSmall.copyWith(fontSize: 17),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryEmerald.withOpacity(0.2)),
                ),
                child: Text(
                  '${lookbook.items.length} Piece${lookbook.items.length == 1 ? '' : 's'}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primaryEmerald,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 16),

          // Base Garment Showcase Row
          if (garmentItem != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 72,
                    height: 82,
                    color: AppColors.tagGarment,
                    child: garmentItem.thumbnailUrl != null
                        ? Image.network(
                            _resolveImageUrl(garmentItem.thumbnailUrl!)!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackIcon(Icons.checkroom),
                          )
                        : _fallbackIcon(Icons.checkroom),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryEmerald.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'BASE GARMENT',
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 9,
                            color: AppColors.primaryEmerald,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        garmentItem.displayTitle,
                        style: AppTypography.labelLarge.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        garmentItem.categoryName,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          // Paired Jewelry Grid / Row
          if (jewelryItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'PAIRED JEWELRY (${jewelryItems.length})',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.mutedText,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: jewelryItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final jItem = jewelryItems[index];
                  return Tooltip(
                    message: '${jItem.displayTitle} (${jItem.categoryName})',
                    child: Container(
                      width: 64,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: jItem.thumbnailUrl != null
                                ? Image.network(
                                    _resolveImageUrl(jItem.thumbnailUrl!)!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _fallbackIcon(Icons.diamond_outlined, size: 16),
                                  )
                                : _fallbackIcon(Icons.diamond_outlined, size: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            color: AppColors.background,
                            child: Text(
                              jItem.displayTitle,
                              textAlign: TextAlign.center,
                              style: AppTypography.labelSmall.copyWith(fontSize: 8.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
  }

  Widget _fallbackIcon(IconData icon, {double size = 24}) {
    return Container(
      color: AppColors.tagGarment,
      child: Center(
        child: Icon(icon, size: size, color: AppColors.primaryEmerald.withOpacity(0.5)),
      ),
    );
  }
}
