import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../services/auth_service.dart';

/// The same sidebar navigation available on the Dashboard, but self-contained
/// so any screen can drop it in as a Drawer. Dashboard keeps its own
/// StatefulWidget-driven `_SidebarContent` (it needs to switch embedded tabs
/// like Outfits/Statistics by index, not just push routes) — this is for
/// every other screen, which only ever needs to *navigate to* a route.
class JVNavDrawer extends StatefulWidget {
  const JVNavDrawer({super.key});

  @override
  State<JVNavDrawer> createState() => _JVNavDrawerState();
}

class _JVNavDrawerState extends State<JVNavDrawer> {
  bool _isAdmin = false;
  String _displayName = 'there';

  @override
  void initState() {
    super.initState();
    AuthService.instance.fetchProfile().then((profile) {
      if (mounted) {
        setState(() {
          _isAdmin = profile.isAdmin;
          _displayName = profile.displayName ?? _displayName;
        });
      }
    });
  }

  List<Map<String, dynamic>> get _navItems => [
    {
      'title': 'Dashboard',
      'icon': Icons.dashboard_outlined,
      'selectedIcon': Icons.dashboard,
      'route': '/dashboard',
    },
    {
      'title': 'My Closet',
      'icon': Icons.checkroom_outlined,
      'selectedIcon': Icons.checkroom,
      'route': '/closet',
    },
    {
      'title': 'Add New Item',
      'icon': Icons.add_circle_outline,
      'selectedIcon': Icons.add_circle,
      'route': '/upload',
    },
    {
      'title': 'Lookbooks',
      'icon': Icons.collections_bookmark_outlined,
      'selectedIcon': Icons.collections_bookmark,
      'route': '/lookbooks',
    },
    {
      'title': 'Ask JewelVault',
      'icon': Icons.auto_awesome_outlined,
      'selectedIcon': Icons.auto_awesome,
      'route': '/prompt',
    },
    if (_isAdmin)
      {
        'title': 'Admin',
        'icon': Icons.admin_panel_settings_outlined,
        'selectedIcon': Icons.admin_panel_settings,
        'route': '/admin',
      },
  ];

  void _handleNavTap(BuildContext context, String route) {
    Navigator.pop(context); // close the drawer first
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == route) return;

    if (route == '/dashboard') {
      Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
    } else {
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          final resolvedName =
              (_displayName.isNotEmpty && _displayName.toLowerCase() != 'there')
              ? _displayName
              : user?.displayName;
          final greetingName =
              (resolvedName != null && resolvedName.isNotEmpty)
              ? resolvedName
              : (user?.email != null && user!.email!.contains('@')
                    ? user.email!.split('@')[0]
                    : 'User');

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryEmerald,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.diamond_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'JewelVault',
                        style: AppTypography.headingMedium.copyWith(
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'MENU',
                    style: AppTypography.labelSmall.copyWith(letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _navItems.length,
                      padding: EdgeInsets.zero,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final item = _navItems[index];
                        final isSelected = currentRoute == item['route'];
                        return InkWell(
                          onTap: () => _handleNavTap(context, item['route']),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryEmerald
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? item['selectedIcon']
                                      : item['icon'],
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.secondaryText,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item['title'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.labelLarge.copyWith(
                                      fontSize: 13,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.primaryText,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(height: 1, color: AppColors.border),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/profile');
                      },
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accentGoldLight,
                        child: Text(
                          greetingName.isNotEmpty
                              ? greetingName[0].toUpperCase()
                              : 'U',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.accentGold,
                          ),
                        ),
                      ),
                      title: Text(
                        greetingName,
                        style: AppTypography.labelLarge.copyWith(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        onPressed: () async {
                          try {
                            await AuthService.instance.signOut();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to sign out. Please try again.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
