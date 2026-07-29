import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_layout.dart';

class JVAppShell extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBackButton;
  final bool extendBodyBehindAppBar;

  const JVAppShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.showBackButton = true,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: AppBar(
        title: Text(title, style: AppTypography.headingMedium),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        // Landing on a route directly (a typed URL on web) leaves nothing to
        // pop, so fall back to the dashboard instead of dropping the control.
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/dashboard');
                  }
                },
              )
            : null,
        actions: actions != null
            ? [
                ...actions!,
                const SizedBox(width: AppSpacing.md),
              ]
            : null,
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: !extendBodyBehindAppBar,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.desktopMaxWidth,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
