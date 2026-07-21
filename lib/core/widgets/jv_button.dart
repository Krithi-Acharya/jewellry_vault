import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';

enum JVButtonVariant { primary, secondary, outlined }

class JVButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final JVButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const JVButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = JVButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget buttonContent = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == JVButtonVariant.primary ? Colors.white : AppColors.primaryEmerald,
              ),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(text, style: AppTypography.labelLarge.copyWith(fontSize: 15)),
        ],
      ],
    );

    final style = _getButtonStyle();

    return isFullWidth
        ? SizedBox(
            width: double.infinity,
            height: 52,
            child: _buildButton(style, buttonContent),
          )
        : SizedBox(
            height: 52,
            child: _buildButton(style, buttonContent),
          );
  }

  Widget _buildButton(ButtonStyle style, Widget child) {
    if (variant == JVButtonVariant.outlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: child,
      );
    }
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: child,
    );
  }

  ButtonStyle _getButtonStyle() {
    switch (variant) {
      case JVButtonVariant.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryEmerald,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryEmerald.withOpacity(0.5),
          disabledForegroundColor: Colors.white.withOpacity(0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        );
      case JVButtonVariant.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primaryText,
          disabledBackgroundColor: AppColors.surface.withOpacity(0.5),
          disabledForegroundColor: AppColors.primaryText.withOpacity(0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        );
      case JVButtonVariant.outlined:
        return OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryText,
          disabledForegroundColor: AppColors.primaryText.withOpacity(0.5),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        );
    }
  }
}
