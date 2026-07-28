import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

class JVImagePlaceholder extends StatelessWidget {
  final String message;
  final bool showAction;
  final VoidCallback? onAction;

  const JVImagePlaceholder({
    super.key,
    this.message = 'Image unavailable',
    this.showAction = true,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('◇', style: TextStyle(fontSize: 48, color: AppColors.primaryEmerald)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.labelLarge.copyWith(color: AppColors.secondaryText),
              textAlign: TextAlign.center,
            ),
            if (showAction) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: onAction,
                child: Text('Replace image', style: AppTypography.labelLarge.copyWith(color: AppColors.primaryEmerald)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
