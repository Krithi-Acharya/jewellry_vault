import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/app_config.dart';
import '../../../services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/jv_app_shell.dart';
import '../../../core/widgets/jv_button.dart';
import '../../../core/widgets/jv_card.dart';
import '../../../core/widgets/jv_metadata_display_tile.dart';
import '../../../core/widgets/jv_image_placeholder.dart';

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
        _isLoading = false;
        
        final attributes = data['attributes'] as List<dynamic>? ?? [];
        for (var attr in attributes) {
          _attrControllers[attr['name']] = TextEditingController(text: attr['value']?.toString() ?? '');
        }

        final colors = data['colors'] as List<dynamic>? ?? [];
        _editedColors = colors.map((c) => Map<String, dynamic>.from(c)).toList();
      });
    } catch (e) {
      print('Error fetching metadata: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> manualAttributes = {};
      for (var entry in _attrControllers.entries) {
        manualAttributes[entry.key] = entry.value.text;
      }

      final Map<String, dynamic> manualColors = {};
      for (var c in _editedColors) {
        manualColors[c['name']] = c['hex'];
      }

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
      Navigator.pushNamedAndRemoveUntil(context, '/closet', ModalRoute.withName('/dashboard'));
    } catch (e) {
      print('Error saving metadata: $e');
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
                    hexController.text = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
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
                  }).toList(),
                  
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
                  color: Colors.black.withOpacity(0.05),
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
