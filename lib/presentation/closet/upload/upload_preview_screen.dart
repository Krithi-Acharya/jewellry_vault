import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/jv_app_shell.dart';
import '../../../core/widgets/jv_button.dart';
import 'upload_provider.dart';

class UploadPreviewScreen extends StatelessWidget {
  const UploadPreviewScreen({super.key});

  void _handleContinue(BuildContext context) async {
    final provider = context.read<UploadProvider>();
    final response = await provider.uploadImage();
    
    if (context.mounted) {
      if (response != null) {
        final jobId = response['job']['id'];
        final itemId = response['item']['id'];
        
        Navigator.pushReplacementNamed(context, '/processing', arguments: {
          'jobId': jobId,
          'itemId': itemId,
        });
      } else if (provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error!)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadProvider>(
      builder: (context, provider, _) {
        return JVAppShell(
          title: 'Preview Image',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: AppShadows.md,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: provider.imageBytes != null
                          ? Image.memory(
                              provider.imageBytes!,
                              fit: BoxFit.contain,
                            )
                          : const Center(child: Text('No image selected')),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  children: [
                    Expanded(
                      child: JVButton(
                        text: 'Replace',
                        variant: JVButtonVariant.secondary,
                        onPressed: provider.isUploading ? null : () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: JVButton(
                        text: 'Continue',
                        isLoading: provider.isUploading,
                        onPressed: provider.isUploading ? null : () => _handleContinue(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}
