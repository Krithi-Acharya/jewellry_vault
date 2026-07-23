import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:typed_data';
import '../../../core/config/app_config.dart';
import '../../../services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_radius.dart';

class ItemDetailsScreen extends StatefulWidget {
  final int itemId;

  const ItemDetailsScreen({super.key, required this.itemId});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  final Dio _dio = Dio();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  Map<String, dynamic>? _metadata;

  bool _isSaving = false;
  bool _isFavorite = false;

  final Map<String, TextEditingController> _attrControllers = {};
  List<Map<String, dynamic>> _editedColors = [];

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
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
        _isFavorite = data['isFavorite'] ?? false;
        _isLoading = false;

        _initEditState();
      });
    } catch (e) {
      print('Error fetching metadata: $e');
      setState(() => _isLoading = false);
    }
  }

  void _initEditState() {
    if (_metadata == null) return;

    _attrControllers.clear();
    final attributes = _metadata!['attributes'] as List<dynamic>? ?? [];
    for (var attr in attributes) {
      _attrControllers[attr['name']] = TextEditingController(text: attr['value']?.toString() ?? '');
    }

    final colors = _metadata!['colors'] as List<dynamic>? ?? [];
    _editedColors = colors.map((c) => Map<String, dynamic>.from(c)).toList();
  }

  Future<void> _toggleFavorite() async {
    setState(() => _isFavorite = !_isFavorite);
    try {
      final token = await AuthService.instance.getIdToken();
      final url = '${AppConfig.apiBaseUrl}/items/${widget.itemId}';
      
      await _dio.put(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {'isFavorite': _isFavorite},
      );
    } catch (e) {
      print('Error toggling favorite: $e');
      setState(() => _isFavorite = !_isFavorite); // Revert on failure
    }
  }

  Future<void> _replaceImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final Uint8List imageBytes = await image.readAsBytes();

    if (!mounted) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Replace Image', style: AppTypography.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to replace this item\'s image?', style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(imageBytes, height: 200, fit: BoxFit.cover),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryEmerald),
            child: Text('Upload', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final token = await AuthService.instance.getIdToken();
      final url = '${AppConfig.apiBaseUrl}/items/${widget.itemId}/image';

      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(imageBytes, filename: image.name),
      });

      final response = await _dio.post(
        url,
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final jobId = response.data['data']['job']['id'];

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/processing',
        arguments: {'jobId': jobId, 'itemId': widget.itemId},
      );
    } catch (e) {
      print('Error replacing image: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to replace image')));
      }
    }
  }

  Future<void> _deleteItem() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Item?', style: AppTypography.headingSmall),
        content: Text('This removes it from your closet. This action cannot be undone.', style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Delete', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final token = await AuthService.instance.getIdToken();
      final url = '${AppConfig.apiBaseUrl}/items/${widget.itemId}';

      await _dio.delete(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!mounted) return;
      Navigator.pop(context); // Go back to closet
    } catch (e) {
      print('Error deleting item: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> manualAttributes = {};
      for (var entry in _attrControllers.entries) {
        manualAttributes[entry.key] = entry.value.text;
      }

      // Sent as an ordered list (index 0 = primary, 1 = secondary) so the
      // backend can replace ai_colors positionally instead of merging by
      // display name, which previously left stale colors behind under
      // whatever name a chip happened to be showing at edit time.
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
        },
      );

      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved successfully')));
      }
      _fetchMetadata(); // Refresh
    } catch (e) {
      print('Error saving: $e');
      setState(() => _isSaving = false);
    }
  }

  void _showColorPicker(int index) {
    String currentHex = _editedColors[index]['hex'];
    Color currentColor = Color(int.parse(currentHex.replaceFirst('#', '0xff')));
    TextEditingController hexController = TextEditingController(text: currentHex.toUpperCase());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pick a color', style: AppTypography.headingSmall),
          content: SingleChildScrollView(
            child: Column(
              children: [
                ColorPicker(
                  pickerColor: currentColor,
                  onColorChanged: (color) {
                    currentColor = color;
                    hexController.text = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                  },
                  pickerAreaHeightPercent: 0.8,
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsvWithHue,
                  labelTypes: const [],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hexController,
                  decoration: const InputDecoration(
                    labelText: 'HEX Color',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    if (val.length == 7 && val.startsWith('#')) {
                      try {
                        setState(() {
                          currentColor = Color(int.parse(val.replaceFirst('#', '0xff')));
                        });
                      } catch (e) {}
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

  String _generateTitle() {
    if (_metadata == null) return 'Item Details';
    final attrs = _metadata!['attributes'] as List<dynamic>? ?? [];
    
    String category = 'Item';
    String color = '';
    
    for (var attr in attrs) {
      if (attr['name'] == 'category' || attr['name'] == 'clothing_type') {
        category = attr['value'].toString();
      }
    }
    
    final colors = _metadata!['colors'] as List<dynamic>? ?? [];
    if (colors.isNotEmpty) {
      color = colors.first['name'].toString();
    }
    
    if (color.isNotEmpty) {
      return '${color[0].toUpperCase()}${color.substring(1)} ${category[0].toUpperCase()}${category.substring(1)}';
    }
    return '${category[0].toUpperCase()}${category.substring(1)}';
  }

  String _generateSubtitle() {
    if (_metadata == null) return '';
    final attrs = _metadata!['attributes'] as List<dynamic>? ?? [];
    
    String fabric = '';
    String style = '';
    
    for (var attr in attrs) {
      if (attr['name'] == 'fabric') fabric = attr['value'].toString();
      if (attr['name'] == 'style') style = attr['value'].toString();
    }
    
    List<String> parts = [];
    if (fabric.isNotEmpty) parts.add('${fabric[0].toUpperCase()}${fabric.substring(1)}');
    if (style.isNotEmpty) parts.add('${style[0].toUpperCase()}${style.substring(1)}');
    
    return parts.join(' • ');
  }

  Widget _buildTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.9),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.primaryEmerald),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.9),
                child: IconButton(
                  icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryEmerald),
                  tooltip: 'Replace Image',
                  onPressed: _replaceImage,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.9),
                child: IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? AppColors.accentGold : AppColors.primaryEmerald,
                  ),
                  tooltip: 'Favorite',
                  onPressed: _toggleFavorite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_generateTitle(), style: AppTypography.headingLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(_generateSubtitle(), style: AppTypography.bodyLarge.copyWith(color: AppColors.secondaryText)),
      ],
    );
  }

  Widget _buildStyleWithAiSection() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/recommendations', arguments: widget.itemId);
        },
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text('Style with AI', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryEmerald,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildAiAnalysisSection() {
    final attributes = _metadata!['attributes'] as List<dynamic>? ?? [];
    double confidence = 0.0;
    if (attributes.isNotEmpty && attributes.first['confidence'] != null) {
      confidence = (attributes.first['confidence'] as num).toDouble();
    }
    final int percent = (confidence * 100).round();
    final history = _metadata!['aiHistory'];

    String formattedDate = 'Unknown';
    if (history != null && history['timestamp'] != null) {
      DateTime dt = DateTime.parse(history['timestamp']).toLocal();
      formattedDate = '${dt.month}/${dt.day}/${dt.year}';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: AppColors.primaryEmerald, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text('AI Analysis', style: AppTypography.headingMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: confidence,
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percent >= 85 ? Colors.green : (percent >= 60 ? Colors.orange : AppColors.error),
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text('$percent%', style: AppTypography.labelLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Analyzed by ${history?['model'] ?? 'AI'} on $formattedDate',
            style: AppTypography.labelSmall.copyWith(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildManualMetadataSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manual Metadata', style: AppTypography.headingMedium),
          const SizedBox(height: AppSpacing.md),
          Text('Colors', style: AppTypography.labelLarge),
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
                child: Chip(
                  avatar: CircleAvatar(backgroundColor: Color(colorVal)),
                  label: Text(c['name'], style: AppTypography.labelSmall),
                  backgroundColor: AppColors.background,
                  side: const BorderSide(color: AppColors.border),
                  deleteIcon: const Icon(Icons.edit, size: 14, color: AppColors.mutedText),
                  onDeleted: () => _showColorPicker(index),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Attributes', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          ..._attrControllers.entries.map((entry) {
            final name = entry.key;
            final controller = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: TextField(
                controller: controller,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  labelText: name.replaceAll('_', ' ').toUpperCase(),
                  labelStyle: AppTypography.labelSmall.copyWith(color: AppColors.mutedText),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primaryEmerald),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: AppColors.background,
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryEmerald,
                side: const BorderSide(color: AppColors.primaryEmerald),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Save Metadata', style: AppTypography.labelLarge),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text('Danger Zone', style: AppTypography.headingMedium.copyWith(color: AppColors.error)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Deleting this item will permanently remove it from your closet and any associated outfits.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _deleteItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error.withOpacity(0.1),
                foregroundColor: AppColors.error,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Delete Item', style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primaryEmerald)),
      );
    }

    if (_metadata == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Failed to load metadata')),
      );
    }

    final imageUrl = _metadata!['image'] != null 
        ? '${AppConfig.apiBaseUrl.replaceAll('/api/v1', '')}${_metadata!['image']}'
        : null;

    final bool isWide = !AppLayout.isMobile(context);
    final bool isDesktop = AppLayout.isDesktop(context);

    final Widget details = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummarySection(),
          const SizedBox(height: AppSpacing.xl),

          _buildStyleWithAiSection(),
          const SizedBox(height: AppSpacing.xl),

          _buildAiAnalysisSection(),
          const SizedBox(height: AppSpacing.xl),

          _buildManualMetadataSection(),
          const SizedBox(height: AppSpacing.xl),

          _buildDangerZone(),
          const SizedBox(height: 60), // padding for scrolling
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            // Desktop must not stretch edge to edge, so content is centred
            // within the same max width the rest of the app uses.
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppLayout.desktopMaxWidth),
                child: isWide
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxl),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // The image keeps its own proportions instead of
                            // being cropped into a wide letterbox strip.
                            Expanded(
                              flex: isDesktop ? 30 : 40,
                              child: Padding(
                                padding: const EdgeInsets.only(left: AppSpacing.lg),
                                child: _buildHeroImage(imageUrl, aspectRatio: 3 / 4),
                              ),
                            ),
                            Expanded(
                              flex: isDesktop ? 70 : 60,
                              child: details,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            width: double.infinity,
                            child: _buildHeroImage(imageUrl),
                          ),
                          details,
                        ],
                      ),
              ),
            ),
          ),

          _buildTopBar(),
        ],
      ),
    );
  }

  /// Hero image for the item. When [aspectRatio] is supplied the image keeps
  /// that shape (used on wider layouts); otherwise it fills the given space.
  Widget _buildHeroImage(String? imageUrl, {double? aspectRatio}) {
    final Widget image = imageUrl != null
        ? Image.network(
            imageUrl,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.border,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, color: AppColors.mutedText),
              ),
            ),
          )
        : Container(color: AppColors.border);

    if (aspectRatio == null) return image;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AspectRatio(aspectRatio: aspectRatio, child: image),
    );
  }
}
