import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';

class JVMetadataEditTile extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final IconData? icon;

  const JVMetadataEditTile({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.primaryEmerald.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.primaryEmerald, size: 24),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(color: AppColors.primaryEmerald),
                ),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    isDense: true,
                    value: options.contains(value) ? value : null,
                    hint: Text(hint, style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText)),
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.secondaryText),
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.primaryText),
                    dropdownColor: AppColors.surface,
                    items: options.map((String option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
