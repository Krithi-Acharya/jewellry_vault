import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/closet_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../services/auth_service.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/jv_app_shell.dart';
import '../../../core/widgets/jv_button.dart';
import '../../../core/widgets/jv_metadata_display_tile.dart';
import '../../../core/widgets/jv_image_placeholder.dart';
import '../services/closet_service.dart';

class MetadataReviewScreen extends StatefulWidget {
  final int itemId;

  const MetadataReviewScreen({super.key, required this.itemId});

  @override
  State<MetadataReviewScreen> createState() => _MetadataReviewScreenState();
}

class _MetadataReviewScreenState extends State<MetadataReviewScreen> {
  final Dio _dio = Dio();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  Map<String, dynamic>? _metadata;

  final Map<String, TextEditingController> _attrControllers = {};
  List<Map<String, dynamic>> _editedColors = [];

  // Clarification state
  String _selectedType = 'garment'; // 'garment' or 'jewelry'
  String? _selectedCategory;
  bool _isClarifying = false;

  List<String> _garmentCategories = [
    'Saree', 'Lehenga', 'Top', 'Pants', 'Dress', 'Skirt', 'Shirt', 'Outerwear', 'Full Outfit / Co-ord Set', 'Shoes', 'Bag', 'Accessory'
  ];
  List<String> _jewelryCategories = [
    'Ring', 'Necklace', 'Earrings', 'Bracelet', 'Watch'
  ];

  static const Set<String> _jewelryNames = {
    'ring', 'necklace', 'earrings', 'bracelet', 'watch', 'pendant', 'bangle', 'anklet', 'jewelry', 'jewelry set'
  };


  @override
  void initState() {
    super.initState();
    _fetchMetadata();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final cats = await ClosetService.instance.fetchCategories();
      if (mounted && cats.isNotEmpty) {
        final jList = <String>[];
        final gList = <String>[];
        for (final cat in cats) {
          if (_jewelryNames.contains(cat.toLowerCase())) {
            jList.add(cat);
          } else {
            gList.add(cat);
          }
        }
        setState(() {
          if (jList.isNotEmpty) _jewelryCategories = jList;
          if (gList.isNotEmpty) _garmentCategories = gList;
        });
      }
    } catch (_) {}
  }


  @override
  void dispose() {
    for (var controller in _attrControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchMetadata() async {
    try {
      final token = await AuthService.instance.getIdToken();
      final url = '${AppConfig.apiBaseUrl}/items/${widget.itemId}/metadata';

      final response = await _dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data['data'];
      setState(() {
        _metadata = data;
        _isLoading = false;
        
        final attributes = data['attributes'] as List<dynamic>? ?? [];
        for (var attr in attributes) {
          _attrControllers[attr['name']] = TextEditingController(text: attr['value']?.toString() ?? '');
        }

        final colors = data['colors'] as List<dynamic>? ?? [];
        _editedColors = colors.map((c) => Map<String, dynamic>.from(c)).toList();

        // Default pre-selected category guess
        if (data['categoryName'] != null) {
          _selectedCategory = data['categoryName'];
        }
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitClarification() async {
    if (_selectedCategory == null) return;
    setState(() => _isClarifying = true);

    try {
      await ClosetService.instance.clarifyItem(
        widget.itemId,
        _selectedType,
        _selectedCategory!,
      );

      if (mounted) {
        setState(() {
          _isClarifying = false;
          _metadata?['status_label'] = 'Verified';
          _metadata?['status'] = 'ACTIVE';
          _metadata?['categoryName'] = _selectedCategory;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category set to "$_selectedCategory"!'),
            backgroundColor: AppColors.primaryEmerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClarifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update category: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> manualAttributes = {};
      for (var entry in _attrControllers.entries) {
        manualAttributes[entry.key] = entry.value.text;
      }

      final List<Map<String, dynamic>> manualColors = _editedColors
          .map((c) => {'name': c['name'], 'hex': c['hex']})
          .toList();

      final token = await AuthService.instance.getIdToken();
      final url = '${AppConfig.apiBaseUrl}/items/${widget.itemId}';

      await _dio.put(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {
          'manualAttributes': manualAttributes,
          'manualColors': manualColors,
          'status': 'ACTIVE',
        },
      );

      if (!mounted) return;
      try {
        context.read<ClosetProvider>().fetchItems();
      } catch (_) {}
      Navigator.pushNamedAndRemoveUntil(context, '/closet', ModalRoute.withName('/dashboard'));
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save')));
      }
    }
  }


  void _showColorPicker(int index) {
    if (!_isEditing) return;
    
    String currentHex = _editedColors[index]['hex'];
    Color currentColor = Color(int.parse(currentHex.replaceFirst('#', '0xff')));
    TextEditingController hexController = TextEditingController(text: currentHex.toUpperCase());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
          title: Text('Pick a color', style: AppTypography.headingSmall),
          content: SingleChildScrollView(
            child: Column(
              children: [
                ColorPicker(
                  pickerColor: currentColor,
                  onColorChanged: (color) {
                    currentColor = color;
                    hexController.text = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                  },
                  pickerAreaHeightPercent: 0.8,
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsvWithHue,
                  labelTypes: const [],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: hexController,
                  decoration: InputDecoration(
                    labelText: 'HEX Color',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input)),
                  ),
                  onChanged: (val) {
                    if (val.length == 7 && val.startsWith('#')) {
                      try {
                        setState(() {
                          currentColor = Color(int.parse(val.replaceFirst('#', '0xff')));
                        });
                      } catch (_) {}
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.mutedText)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _editedColors[index]['hex'] = hexController.text;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryEmerald),
              child: Text('Select', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryGroup(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            title,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((cat) {
            final isSelected = _selectedCategory?.toLowerCase() == cat.toLowerCase();
            return ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: AppColors.primaryEmerald,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: isSelected ? AppColors.primaryEmerald : AppColors.border,
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.primaryText,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (val) {
                if (val) setState(() => _selectedCategory = cat);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGroupedCategoryChips(List<String> categoryList) {
    if (_selectedType == 'jewelry') {
      return _buildCategoryGroup('JEWELRY & WATCHES', categoryList);
    }

    final ethnic = categoryList.where((c) => ['Saree', 'Lehenga'].contains(c)).toList();
    final topsBottoms = categoryList.where((c) => ['Top', 'Shirt', 'Pants', 'Dress', 'Skirt'].contains(c)).toList();
    final outerwearOutfits = categoryList.where((c) => ['Outerwear', 'Full Outfit / Co-ord Set'].contains(c)).toList();
    final accessories = categoryList.where((c) => ['Shoes', 'Bag', 'Accessory'].contains(c)).toList();
    final other = categoryList.where((c) => !ethnic.contains(c) && !topsBottoms.contains(c) && !outerwearOutfits.contains(c) && !accessories.contains(c)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topsBottoms.isNotEmpty) _buildCategoryGroup('TOPS, BOTTOMS & DRESSES', topsBottoms),
        if (ethnic.isNotEmpty) _buildCategoryGroup('ETHNIC WEAR', ethnic),
        if (outerwearOutfits.isNotEmpty) _buildCategoryGroup('OUTERWEAR & SETS', outerwearOutfits),
        if (accessories.isNotEmpty) _buildCategoryGroup('SHOES & ACCESSORIES', accessories),
        if (other.isNotEmpty) _buildCategoryGroup('OTHER CATEGORIES', other),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const JVAppShell(
        title: 'Review Details',
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryEmerald)),
      );
    }

    if (_metadata == null) {
      return JVAppShell(
        title: 'Error',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Failed to load metadata', style: AppTypography.bodyLarge),
              const SizedBox(height: AppSpacing.md),
              JVButton(
                text: 'Go Back',
                onPressed: () => Navigator.pop(context),
                isFullWidth: false,
              ),
            ],
          ),
        ),
      );
    }

    final imageUrl = _metadata!['image'] != null 
        ? '${AppConfig.apiBaseUrl.replaceAll('/api/v1', '')}${_metadata!['image']}'
        : null;

    final isNeedsClarification = _metadata!['status_label'] == 'Needs Info' ||
        _metadata!['status'] == 'NEEDS_CLARIFICATION';

    final displayedCategoryList = _selectedType == 'jewelry'
        ? _jewelryCategories
        : _garmentCategories;

    return JVAppShell(
      title: 'Review Details',
      actions: [
        IconButton(
          icon: Icon(_isEditing ? Icons.check : Icons.edit, color: AppColors.primaryEmerald),
          onPressed: () {
            setState(() {
              _isEditing = !_isEditing;
            });
          },
          tooltip: _isEditing ? 'Done Editing' : 'Edit',
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clarification Interception Card
                  if (isNeedsClarification) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.help_outline, color: AppColors.warning, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                "What's the main focus of this photo?",
                                style: AppTypography.headingSmall.copyWith(fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Multiple items or outfit pieces (Top/Bottom) are visible. Select what you would like to save this item as:',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
                          ),

                          const SizedBox(height: 14),

                          // Garment / Jewelry Type Segmented Switch
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('Garment & Clothing')),
                                  selected: _selectedType == 'garment',
                                  selectedColor: AppColors.primaryEmerald,
                                  labelStyle: TextStyle(
                                    color: _selectedType == 'garment' ? Colors.white : AppColors.primaryText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedType = 'garment';
                                        _selectedCategory = _garmentCategories.first;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('Jewelry & Accessories')),
                                  selected: _selectedType == 'jewelry',
                                  selectedColor: AppColors.primaryEmerald,
                                  labelStyle: TextStyle(
                                    color: _selectedType == 'jewelry' ? Colors.white : AppColors.primaryText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedType = 'jewelry';
                                        _selectedCategory = _jewelryCategories.first;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Text('Select Category:', style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          _buildGroupedCategoryChips(displayedCategoryList),
                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isClarifying ? null : _submitClarification,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryEmerald,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isClarifying
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Confirm Category & Unlock Details'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  Text(
                    'AI has analyzed your item. Please review and make any necessary corrections.',
                    style: AppTypography.bodyLarge.copyWith(color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Image Preview
                  Center(
                    child: SizedBox(
                      height: 250,
                      width: 250,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: imageUrl != null 
                          ? CachedNetworkImage(
                              imageUrl: imageUrl, 
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => const JVImagePlaceholder(showAction: false),
                            )
                          : const JVImagePlaceholder(showAction: false),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  
                  // Colors Section
                  Text('Colors', style: AppTypography.headingSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: List.generate(_editedColors.length, (index) {
                      final c = _editedColors[index];
                      final hexString = c['hex'] as String;
                      final colorVal = int.parse(hexString.replaceFirst('#', '0xff'));
                      
                      return GestureDetector(
                        onTap: () => _showColorPicker(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.button),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Color(colorVal),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black12),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(c['name'], style: AppTypography.bodyMedium),
                              if (_isEditing) ...[
                                const SizedBox(width: AppSpacing.sm),
                                const Icon(Icons.edit, size: 16, color: AppColors.mutedText),
                              ]
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  
                  // Attributes Section
                  Text('Details', style: AppTypography.headingSmall),
                  const SizedBox(height: AppSpacing.md),
                  ..._attrControllers.entries.map((entry) {
                    final name = entry.key;
                    final controller = entry.value;

                    if (_isEditing) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: TextField(
                          controller: controller,
                          style: AppTypography.bodyMedium,
                          decoration: InputDecoration(
                            labelText: name.replaceAll('_', ' ').toUpperCase(),
                            labelStyle: AppTypography.labelSmall.copyWith(color: AppColors.mutedText),
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
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: JVMetadataDisplayTile(
                          label: name.replaceAll('_', ' ').toUpperCase(),
                          value: controller.text.isEmpty ? 'Not specified' : controller.text,
                        ),
                      );
                    }
                  }),
                  
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              top: AppSpacing.md,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                )
              ],
            ),
            child: JVButton(
              text: 'Save to Closet',
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _saveAndContinue,
            ),
          ),
        ],
      ),
    );
  }
}
