import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../providers/closet_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/jv_app_shell.dart';
import '../../../core/widgets/jv_closet_card.dart';
import '../../../core/widgets/jv_empty_state.dart';
import '../../../core/widgets/jv_skeleton.dart';

class ClosetScreen extends StatefulWidget {
  const ClosetScreen({super.key});

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  final List<String> _categories = ['All', 'Garment', 'Jewelry', 'Bag', 'Accessory'];
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClosetProvider>().fetchItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return JVAppShell(
      title: 'My Closet',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          color: AppColors.primaryEmerald,
          onPressed: () {
            Navigator.pushNamed(context, '/upload');
          },
          tooltip: 'Upload Garment',
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'Curate and rediscover your personal collection.',
              style: AppTypography.bodyLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search closet...',
                hintStyle: AppTypography.bodyMedium,
                prefixIcon: const Icon(Icons.search, color: AppColors.mutedText, size: 20),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: const BorderSide(color: AppColors.primaryEmerald),
                ),
              ),
              onChanged: (val) {
                context.read<ClosetProvider>().setSearchQuery(val);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Custom Chips
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = category);
                      context.read<ClosetProvider>().setCategory(category == 'All' ? '' : category);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryEmerald : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryEmerald : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: AppTypography.labelLarge.copyWith(
                            color: isSelected ? Colors.white : AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Grid
          Expanded(
            child: Consumer<ClosetProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return MasonryGridView.count(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    itemCount: 6,
                    itemBuilder: (context, index) => const JVClosetGridSkeleton(),
                  );
                }
                
                if (provider.items.isEmpty) {
                  return const JVEmptyState(
                    title: 'No items found',
                    message: 'Your closet is looking a little bare. Upload some items to get started.',
                  );
                }

                return MasonryGridView.count(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  itemCount: provider.items.length,
                  itemBuilder: (context, index) {
                    final item = provider.items[index];
                    final String? thumbnail = item['thumbnail_url'];
                    final String imageUrl = thumbnail != null
                        ? '${AppConfig.apiBaseUrl.replaceAll('/api/v1', '')}$thumbnail'
                        : '';
                        
                    final String title = item['display_title'] ?? 'Unknown Item';
                    final String subtitle = item['display_subtitle'] ?? 'Unknown details';
                    final String badgeStatus = item['status_label'] ?? 'Processing';
                    
                    return JVClosetCard(
                      imageUrl: imageUrl,
                      title: title,
                      subtitle: subtitle,
                      status: badgeStatus,
                      onTap: () {
                        Navigator.pushNamed(context, '/item-details', arguments: item['id']);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
