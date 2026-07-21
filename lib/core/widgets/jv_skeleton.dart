import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

class JVSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const JVSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppRadius.card,
  });

  @override
  State<JVSkeleton> createState() => _JVSkeletonState();
}

class _JVSkeletonState extends State<JVSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _colorAnimation = ColorTween(
      begin: AppColors.surface,
      end: AppColors.border.withOpacity(0.5),
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class JVCardSkeleton extends StatelessWidget {
  const JVCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const JVSkeleton(width: double.infinity, height: 120);
  }
}

class JVImageSkeleton extends StatelessWidget {
  const JVImageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const JVSkeleton(width: double.infinity, height: 300);
  }
}

class JVMetadataSkeleton extends StatelessWidget {
  const JVMetadataSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JVSkeleton(width: 100, height: 16, borderRadius: AppRadius.sm),
        SizedBox(height: 8),
        JVSkeleton(width: double.infinity, height: 20, borderRadius: AppRadius.sm),
      ],
    );
  }
}

class JVClosetGridSkeleton extends StatelessWidget {
  const JVClosetGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const JVSkeleton(width: double.infinity, height: 200, borderRadius: AppRadius.card),
        const SizedBox(height: 8),
        const JVSkeleton(width: 120, height: 16, borderRadius: AppRadius.sm),
        const SizedBox(height: 4),
        const JVSkeleton(width: 80, height: 12, borderRadius: AppRadius.sm),
      ],
    );
  }
}
