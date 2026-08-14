import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_layout.dart';
import 'jv_nav_drawer.dart';

class JVAppShell extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBackButton;
  final bool extendBodyBehindAppBar;
  final bool showDrawer;

  const JVAppShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.showBackButton = true,
    this.extendBodyBehindAppBar = false,
    this.showDrawer = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      drawer: showDrawer ? const JVNavDrawer() : null,
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
        actions: [
          // The back arrow above already occupies `leading`, which is what
          // Scaffold would otherwise auto-fill with a drawer toggle — so
          // without this, a screen reached by pushing (i.e. almost all of
          // them) would have a Drawer nobody can open except by an edge
          // swipe. Only needed when both a back button AND a drawer exist;
          // Dashboard has no back button, so it gets the automatic one.
          if (showDrawer && showBackButton)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: AppColors.primaryText),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          if (actions != null) ...actions!,
          const SizedBox(width: AppSpacing.md),
        ],
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
