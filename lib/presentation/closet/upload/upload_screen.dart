import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/jv_app_shell.dart';
import '../../../core/widgets/jv_button.dart';
import '../../../core/widgets/jv_card.dart';
import 'upload_provider.dart';
import 'upload_preview_screen.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UploadProvider(),
      child: const _UploadScreenContent(),
    );
  }
}

class _UploadScreenContent extends StatelessWidget {
  const _UploadScreenContent();

  void _handleImagePick(BuildContext context, ImageSource source) async {
    final provider = context.read<UploadProvider>();
    await provider.pickImage(source);
    
    if (provider.hasImage && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const UploadPreviewScreen(),
          ),
        ),
      );
    } else if (provider.error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return JVAppShell(
      title: 'Upload Garment',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JVCard(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 64, color: AppColors.primaryEmerald),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Drag & Drop',
                    style: AppTypography.headingMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'or',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      JVButton(
                        text: 'Browse Files',
                        onPressed: () => _handleImagePick(context, ImageSource.gallery),
                        isFullWidth: false,
                        icon: Icons.folder_open,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      JVButton(
                        text: 'Take Photo',
                        variant: JVButtonVariant.secondary,
                        onPressed: () => _handleImagePick(context, ImageSource.camera),
                        isFullWidth: false,
                        icon: Icons.camera_alt,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Supported formats: PNG • JPG • WEBP\nMaximum size: 10 MB',
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Helpful Tips', style: AppTypography.headingSmall),
                  const SizedBox(height: AppSpacing.md),
                  _buildTip(Icons.check_circle, 'Upload one garment at a time'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTip(Icons.check_circle, 'Use a plain, contrasting background'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTip(Icons.check_circle, 'Ensure good, even lighting'),
                ],
              ),
            ),
            const Spacer(),
            JVButton(
              text: 'Continue',
              onPressed: null, // Disabled until image selection (handled by routing)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryEmerald),
        const SizedBox(width: AppSpacing.sm),
        Text(text, style: AppTypography.bodyMedium),
      ],
    );
  }
}
