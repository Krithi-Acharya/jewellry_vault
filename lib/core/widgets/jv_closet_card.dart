import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';
import 'jv_image_placeholder.dart';
import 'jv_skeleton.dart';

class JVClosetCard extends StatefulWidget {
  final String? imageUrl;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;

  const JVClosetCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
  });

  @override
  State<JVClosetCard> createState() => _JVClosetCardState();
}

class _JVClosetCardState extends State<JVClosetCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;

    switch (widget.status) {
      case 'Verified':
        statusColor = AppColors.primaryEmerald;
        statusIcon = Icons.check;
        break;
      case 'Needs Review':
        statusColor = AppColors.warning;
        statusIcon = Icons.priority_high;
        break;
      case 'Edited':
        statusColor = AppColors.info;
        statusIcon = Icons.edit;
        break;
      default:
        statusColor = AppColors.mutedText;
        statusIcon = Icons.hourglass_empty;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: _isHovered ? AppShadows.md : [],
          ),
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image Section
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: widget.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: widget.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const AspectRatio(
                          aspectRatio: 3 / 4,
                          child: JVSkeleton(width: double.infinity, height: double.infinity),
                        ),
                        errorWidget: (context, url, error) => const AspectRatio(
                          aspectRatio: 3 / 4,
                          child: JVImagePlaceholder(message: 'Image unavailable', showAction: false),
                        ),
                      )
                    : const AspectRatio(
                        aspectRatio: 3 / 4,
                        child: JVImagePlaceholder(message: 'Image unavailable', showAction: false),
                      ),
              ),
              
              // Metadata Section
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm, left: AppSpacing.xs, right: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: AppTypography.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          widget.status == 'Verified' ? 'AI Verified' : widget.status,
                          style: AppTypography.labelSmall.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
