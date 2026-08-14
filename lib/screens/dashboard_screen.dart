import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../api_service.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';
import 'prompt_screen.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

String? _resolveImageUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.isEmpty) return null;
  if (rawUrl.startsWith('/')) {
    return '${AppConfig.apiBaseUrl.replaceAll('/api/v1', '')}$rawUrl';
  }
  return rawUrl;
}

// Compatibility aliases: this screen was originally written against a
// local JewelVaultColors/JewelVaultTypography design system that has since
// been superseded by the shared AppColors/AppTypography classes in
// core/theme/. Rather than rewrite every call site, we alias the old names
// to the new classes so both naming schemes resolve to the same values.
typedef JewelVaultColors = AppColors;
typedef JewelVaultTypography = AppTypography;

class JewelVaultEffects {
  // A quiet, warm-tinted shadow (emerald, not grey) so elevated surfaces
  // still feel like they belong to this palette rather than a generic UI kit.
  static List<BoxShadow> card = [
    BoxShadow(
      color: JewelVaultColors.primaryEmerald.withValues(alpha: 0.05),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: JewelVaultColors.darkEmerald.withValues(alpha: 0.03),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> raised = [
    BoxShadow(
      color: JewelVaultColors.primaryEmerald.withValues(alpha: 0.10),
      blurRadius: 30,
      offset: const Offset(0, 14),
    ),
  ];
}

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────

class ClosetItem {
  final String id;
  final String title;
  final String category;
  final String brand;
  final String color;
  final String season;
  final int wornCount;
  final double matchScore;
  final bool isFavorite;
  final IconData icon;
  // URL of the item's photo as stored by the backend (e.g. cloud storage).
  // Null only for the offline/seed fallback items.
  final String? imageUrl;

  const ClosetItem({
    required this.id,
    required this.title,
    required this.category,
    required this.brand,
    required this.color,
    required this.season,
    required this.wornCount,
    required this.matchScore,
    required this.isFavorite,
    required this.icon,
    this.imageUrl,
  });

  ClosetItem copyWith({bool? isFavorite, int? wornCount}) => ClosetItem(
    id: id,
    title: title,
    category: category,
    brand: brand,
    color: color,
    season: season,
    wornCount: wornCount ?? this.wornCount,
    matchScore: matchScore,
    isFavorite: isFavorite ?? this.isFavorite,
    icon: icon,
    imageUrl: imageUrl,
  );

  /// Builds a ClosetItem from the JSON shape returned by the backend API.
  ///
  /// The real item DTO (see backend/src/controllers/itemController.js)
  /// uses display_title/categoryName rather than the title/category/brand/
  /// color/season/wornCount/matchScore fields this model was originally
  /// written against, and has no equivalent for most of them. Those fields
  /// fall back to honest defaults rather than being invented.
  factory ClosetItem.fromJson(Map<String, dynamic> json) => ClosetItem(
    id: json['id'].toString(),
    title: json['display_title'] ?? json['title'] ?? '',
    category: json['categoryName'] ?? json['category'] ?? 'Garment',
    brand: json['brand'] ?? 'Unknown',
    color: json['color'] ?? '—',
    season: json['season'] ?? 'All',
    wornCount: json['wornCount'] ?? 0,
    matchScore: (json['matchScore'] as num?)?.toDouble() ?? 80,
    isFavorite: json['isFavorite'] ?? false,
    icon: json['icon'] != null
        ? _iconFromKey(json['icon'])
        : _iconForCategory(json['categoryName'] ?? json['category']),
    imageUrl: _resolveImageUrl(
      (json['thumbnail_url'] ?? json['imageUrl'] ?? json['image']) as String?,
    ),
  );

  /// The subset of fields the backend needs to catalog a new item.
  Map<String, dynamic> toCreateJson() => {
    'title': title,
    'category': category,
    'brand': brand,
    'color': color,
    'season': season,
    'icon': _iconToKey(icon),
    'matchScore': matchScore,
    'imageUrl': imageUrl,
  };
}

// Icons aren't JSON-serializable, so we map them to/from simple string keys
// that mirror the icon names used when creating items in _AddItemView.
IconData _iconFromKey(String key) {
  switch (key) {
    case 'diamond_outlined':
      return Icons.diamond_outlined;
    case 'shopping_bag_outlined':
      return Icons.shopping_bag_outlined;
    case 'face_retouching_natural_outlined':
      return Icons.face_retouching_natural_outlined;
    case 'checkroom_outlined':
    default:
      return Icons.checkroom_outlined;
  }
}

/// Picks a reasonable icon straight from the item's real category name,
/// since the backend DTO doesn't carry an icon field of its own.
IconData _iconForCategory(String? categoryName) {
  switch (categoryName?.toLowerCase()) {
    case 'ring':
    case 'necklace':
    case 'earrings':
    case 'bracelet':
    case 'watch':
      return Icons.diamond_outlined;
    case 'bag':
      return Icons.shopping_bag_outlined;
    default:
      return Icons.checkroom_outlined;
  }
}

String _iconToKey(IconData icon) {
  if (icon == Icons.diamond_outlined) return 'diamond_outlined';
  if (icon == Icons.shopping_bag_outlined) return 'shopping_bag_outlined';
  if (icon == Icons.face_retouching_natural_outlined) {
    return 'face_retouching_natural_outlined';
  }
  return 'checkroom_outlined';
}

// Renders an item's photo when available, falling back to its category
// icon (e.g. if the image fails to load).
Widget _itemImage(ClosetItem item, {double iconSize = 36}) {
  final url = _resolveImageUrl(item.imageUrl);
  if (url == null || url.isEmpty) {
    return Center(
      child: Icon(
        item.icon,
        size: iconSize,
        color: JewelVaultColors.primaryEmerald.withOpacity(0.4),
      ),
    );
  }

  // The backend currently stores the photo itself in the DB and hands it
  // back as a base64 data URI (data:image/jpeg;base64,...) rather than a
  // real hosted URL. Image.network() can't load that — it only does HTTP
  // requests — so decode it locally with Image.memory() instead. If the
  // backend later switches to real cloud storage, imageUrl will start
  // looking like https://... and fall through to the Image.network path
  // below unchanged.
  if (url.startsWith('data:')) {
    try {
      final base64Part = url.substring(url.indexOf(',') + 1);
      final bytes = base64Decode(base64Part);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stack) => Center(
          child: Icon(
            item.icon,
            size: iconSize,
            color: JewelVaultColors.primaryEmerald.withOpacity(0.4),
          ),
        ),
      );
    } catch (e) {
      return Center(
        child: Icon(
          item.icon,
          size: iconSize,
          color: JewelVaultColors.primaryEmerald.withOpacity(0.4),
        ),
      );
    }
  }

  return Image.network(
    url,
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: JewelVaultColors.primaryEmerald,
          ),
        ),
      );
    },
    errorBuilder: (context, error, stack) => Center(
      child: Icon(
        item.icon,
        size: iconSize,
        color: JewelVaultColors.primaryEmerald.withOpacity(0.4),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
//  MAIN DASHBOARD SHELL
// ─────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  List<ClosetItem> _closetItems = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isAdmin = false;

  // Server-resolved display name (falls back to email prefix or 'Annika')
  String _displayName = 'Annika';

  @override
  void initState() {
    super.initState();
    _loadClosetItems();
    AuthService.instance.fetchProfile().then((profile) {
      if (mounted) {
        setState(() {
          _isAdmin = profile.isAdmin;
          if (profile.displayName != null &&
              profile.displayName!.isNotEmpty &&
              profile.displayName!.toLowerCase() != 'there') {
            _displayName = profile.displayName!;
          }
        });
      }
    });
  }

  Future<void> _loadClosetItems() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final data = await ApiService.fetchClosetItems();
      if (!mounted) return;
      setState(() {
        _closetItems = data.map(ClosetItem.fromJson).toList();
        _isLoading = false;
      });
    } catch (e) {
      // Showing invented items here would misrepresent the user's closet, so
      // surface the failure and let them retry instead.
      if (!mounted) return;
      setState(() {
        _closetItems = [];
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _navItems => [
    {
      'title': 'Dashboard',
      'icon': Icons.dashboard_outlined,
      'selectedIcon': Icons.dashboard,
    },
    {
      'title': 'My Closet',
      'icon': Icons.checkroom_outlined,
      'selectedIcon': Icons.checkroom,
    },
    {
      'title': 'Outfits',
      'icon': Icons.style_outlined,
      'selectedIcon': Icons.style,
    },
    {
      'title': 'Add New Item',
      'icon': Icons.add_circle_outline,
      'selectedIcon': Icons.add_circle,
    },
    {
      'title': 'Lookbooks',
      'icon': Icons.collections_bookmark_outlined,
      'selectedIcon': Icons.collections_bookmark,
    },
    {
      'title': 'Statistics',
      'icon': Icons.bar_chart_outlined,
      'selectedIcon': Icons.bar_chart,
    },
    if (_isAdmin)
      {
        'title': 'Admin',
        'icon': Icons.admin_panel_settings_outlined,
        'selectedIcon': Icons.admin_panel_settings,
      },
  ];

  Future<void> _addItem(ClosetItem item) async {
    try {
      final saved = await ApiService.addClosetItem(item.toCreateJson());
      setState(() {
        _closetItems.add(ClosetItem.fromJson(saved));
        _selectedIndex = 1;
      });
    } catch (e) {
      // Server unreachable — keep the item locally so the user's work isn't lost.
      setState(() {
        _closetItems.add(item);
        _selectedIndex = 1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally — could not reach the server.'),
          ),
        );
      }
    }
  }

  /// Handles a sidebar tap. Some entries push a dedicated route instead of
  /// switching the inline view; matching by title (rather than a raw index)
  /// keeps this correct even though the Admin entry only exists conditionally,
  /// which would otherwise shift every index after it.
  void _handleNavTap(Map<String, dynamic> item, int index) {
    switch (item['title']) {
      case 'Dashboard':
        setState(() => _selectedIndex = 0);
        break;
      case 'My Closet':
        Navigator.pushNamed(context, '/closet').then((_) {
          if (mounted) _loadClosetItems();
        });
        break;
      case 'Outfits':
        setState(() => _selectedIndex = 2);
        break;
      case 'Add New Item':
        Navigator.pushNamed(context, '/upload').then((_) {
          if (mounted) _loadClosetItems();
        });
        break;
      case 'Lookbooks':
        Navigator.pushNamed(context, '/lookbooks').then((_) {
          if (mounted) _loadClosetItems();
        });
        break;
      case 'Admin':
        Navigator.pushNamed(context, '/admin');
        break;
      case 'Statistics':
        setState(() => _selectedIndex = 4);
        break;
      default:
        if (index >= 0 && index < 5) {
          setState(() => _selectedIndex = index);
        } else {
          setState(() => _selectedIndex = 0);
        }
    }
  }

  Future<void> _markWorn(String id) async {
    final idx = _closetItems.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final previousCount = _closetItems[idx].wornCount;

    // Optimistic update so the UI feels instant.
    setState(() {
      _closetItems[idx] = _closetItems[idx].copyWith(
        wornCount: previousCount + 1,
      );
    });

    try {
      await ApiService.markItemWorn(id);
    } catch (e) {
      // Roll back if the server didn't accept it.
      setState(() {
        _closetItems[idx] = _closetItems[idx].copyWith(
          wornCount: previousCount,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't mark item as worn.")),
        );
      }
    }
  }

  Future<void> _toggleFavorite(String id) async {
    final idx = _closetItems.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final newValue = !_closetItems[idx].isFavorite;

    // Optimistic update so the UI feels instant.
    setState(() {
      _closetItems[idx] = _closetItems[idx].copyWith(isFavorite: newValue);
    });

    try {
      await ApiService.updateClosetItem(id, {'isFavorite': newValue});
    } catch (e) {
      // Roll back if the server didn't accept the change.
      setState(() {
        _closetItems[idx] = _closetItems[idx].copyWith(isFavorite: !newValue);
      });
    }
  }

  // ── FIX: Profile changes (photo removal, name edits) weren't showing up
  // back on the dashboard. The sidebar's avatar used a StreamBuilder on
  // FirebaseAuth.instance.userChanges(), which was assumed to fire after
  // ProfileScreen called updatePhotoURL()/updateDisplayName() + reload().
  // In practice that stream doesn't reliably re-emit on every platform, so
  // the sidebar (and the dashboard greeting, which reads
  // FirebaseAuth.instance.currentUser directly) kept showing stale data.
  //
  // Fix: navigate to Profile with an *awaited* push. When we come back,
  // explicitly reload the current user and call setState so both the
  // sidebar avatar and the dashboard greeting re-read fresh data instead
  // of depending solely on the stream.
  Future<void> _openProfile() async {
    await Navigator.pushNamed(context, '/profile');
    await FirebaseAuth.instance.currentUser?.reload();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryEmerald),
        ),
      );
    }

    if (_loadFailed) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: AppColors.mutedText,
                ),
                const SizedBox(height: 24),
                Text(
                  "Couldn't load your closet",
                  style: AppTypography.headingSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We could not reach the server. Check your connection and try again.',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _loadClosetItems,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryEmerald,
                    side: const BorderSide(color: AppColors.primaryEmerald),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final List<Widget> views = [
      _DashboardView(
        items: _closetItems,
        displayName: _displayName,
        onNavigateToCloset: () => Navigator.pushNamed(context, '/closet'),
        onNavigateToAdd: () => Navigator.pushNamed(context, '/upload'),
        onNavigateToStats: () => setState(() => _selectedIndex = 4),
      ),
      _ClosetView(items: _closetItems, onToggleFavorite: _toggleFavorite),
      _OutfitsView(items: _closetItems),
      _AddItemView(onItemAdded: _addItem, existingCount: _closetItems.length),
      _StatisticsView(items: _closetItems),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: !isDesktop
          ? Drawer(
              backgroundColor: AppColors.surface,
              child: _SidebarContent(
                selectedIndex: _selectedIndex,
                navItems: _navItems,
                displayName: _displayName,
                onSelected: (i) {
                  Navigator.pop(context);
                  _handleNavTap(_navItems[i], i);
                },
                onProfileTap: () {
                  Navigator.pop(context); // close the drawer first
                  _openProfile();
                },
              ),
            )
          : null,
      appBar: !isDesktop
          ? AppBar(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: _LogoRow(),
              iconTheme: const IconThemeData(color: AppColors.primaryEmerald),
              // The drawer toggle sits on the right on every other screen
              // (JVAppShell puts it there since a back arrow already owns
              // `leading`) — matching that here instead of Flutter's default
              // auto-placed left-side hamburger keeps it in the same spot
              // everywhere.
              automaticallyImplyLeading: false,
              actions: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: 'Menu',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            )
          : null,
      body: Row(
        children: [
          if (isDesktop)
            SizedBox(
              width: 260,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: _SidebarContent(
                  selectedIndex: _selectedIndex,
                  navItems: _navItems,
                  displayName: _displayName,
                  onSelected: (i) {
                    _handleNavTap(_navItems[i], i);
                  },
                  onProfileTap: _openProfile,
                ),
              ),
            ),
          Expanded(
            child: SafeArea(
              child: Builder(
                builder: (context) {
                  final safeIndex =
                      (_selectedIndex >= 0 && _selectedIndex < views.length)
                      ? _selectedIndex
                      : 0;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(safeIndex),
                      child: views[safeIndex],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  LOGO ROW
// ─────────────────────────────────────────────

class _LogoRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.primaryEmerald,
          borderRadius: BorderRadius.circular(9),
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
        style: AppTypography.headingMedium.copyWith(letterSpacing: -0.5),
      ),
    ],
  );
}

// ─────────────────────────────────────────────
//  SIDEBAR
// ─────────────────────────────────────────────

class _SidebarContent extends StatelessWidget {
  final int selectedIndex;
  final List<Map<String, dynamic>> navItems;
  final String displayName;
  final Function(int) onSelected;
  final VoidCallback onProfileTap;

  const _SidebarContent({
    required this.selectedIndex,
    required this.navItems,
    required this.displayName,
    required this.onSelected,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final resolvedName =
            (displayName.isNotEmpty && displayName.toLowerCase() != 'there')
            ? displayName
            : user?.displayName;
        final String greetingName =
            (resolvedName != null &&
                resolvedName.isNotEmpty &&
                resolvedName.toLowerCase() != 'there')
            ? resolvedName
            : (user?.email != null &&
                      user!.email!.contains('@') &&
                      user.email!.split('@')[0].isNotEmpty
                  ? (user.email!.split('@')[0][0].toUpperCase() +
                        user.email!.split('@')[0].substring(1))
                  : 'Annika');

        return Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LogoRow(),
              const SizedBox(height: 16),
              Text(
                'MENU',
                style: AppTypography.labelSmall.copyWith(letterSpacing: 1.5),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: navItems.length,
                  padding: EdgeInsets.zero,
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final item = navItems[index];
                    final isSelected = selectedIndex == index;
                    return InkWell(
                      onTap: () => onSelected(index),
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
                              isSelected ? item['selectedIcon'] : item['icon'],
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

              // "Ask AI Stylist" entry point.
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/prompt'),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGoldLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: AppColors.accentGold,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Ask AI Stylist',
                        style: AppTypography.labelLarge.copyWith(
                          fontSize: 13,
                          color: AppColors.accentGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.accentGoldLight,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Text(
                            greetingName.isNotEmpty
                                ? greetingName[0].toUpperCase()
                                : 'U',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.accentGold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    greetingName,
                    style: AppTypography.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Premium Member',
                    style: AppTypography.bodyMedium.copyWith(fontSize: 11),
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
                        // No need to manually navigate.
                        // AuthGate will detect the state change and show the LandingPage.
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
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  TIME-OF-DAY GREETING
// ─────────────────────────────────────────────

class _Greeting {
  final String title;
  final String subtitle;
  final IconData icon;
  const _Greeting(this.title, this.subtitle, this.icon);
}

// Synced with the device's local clock — recalculated every time the
// dashboard builds, so it naturally rolls over as time passes (e.g. if
// someone leaves the app open across a boundary like 5pm).
_Greeting _greetingForTime(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) {
    return const _Greeting(
      'Good morning',
      'Your collection is looking exceptional today.',
      Icons.wb_sunny_outlined,
    );
  } else if (hour >= 12 && hour < 17) {
    return const _Greeting(
      'Good afternoon',
      'Your collection is looking exceptional today.',
      Icons.wb_cloudy_outlined,
    );
  } else if (hour >= 17 && hour < 21) {
    return const _Greeting(
      'Good evening',
      'Time to plan tomorrow\'s look.',
      Icons.wb_twilight,
    );
  } else {
    return const _Greeting(
      'Good night',
      'Resting easy — your vault is safe and sound.',
      Icons.nightlight_round,
    );
  }
}

// ─────────────────────────────────────────────
//  PAGE 1: DASHBOARD VIEW
// ─────────────────────────────────────────────

class _DashboardView extends StatelessWidget {
  final List<ClosetItem> items;
  final String displayName;
  final VoidCallback onNavigateToCloset;
  final VoidCallback onNavigateToAdd;
  final VoidCallback onNavigateToStats;

  const _DashboardView({
    required this.items,
    required this.displayName,
    required this.onNavigateToCloset,
    required this.onNavigateToAdd,
    required this.onNavigateToStats,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final resolvedName =
        (displayName.isNotEmpty && displayName.toLowerCase() != 'there')
        ? displayName
        : user?.displayName;
    final String greetingName =
        (resolvedName != null &&
            resolvedName.isNotEmpty &&
            resolvedName.toLowerCase() != 'there')
        ? resolvedName
        : (user?.email != null &&
                  user!.email!.contains('@') &&
                  user.email!.split('@')[0].isNotEmpty
              ? (user.email!.split('@')[0][0].toUpperCase() +
                    user.email!.split('@')[0].substring(1))
              : 'Annika');
    final firstName = greetingName.split(' ')[0];
    final greeting = _greetingForTime(DateTime.now());

    final garmentCount = items.where((e) => e.category == 'Garment').length;
    final jewelryCount = items.where((e) => e.category == 'Jewelry').length;
    final favoriteCount = items.where((e) => e.isFavorite).length;
    final totalWorn = items.fold(0, (sum, e) => sum + e.wornCount);

    // Recently added
    final recent = items.reversed.take(3).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HERO GREETING ──────────────────────────────────
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isNarrow = constraints.maxWidth < 420;

              final greetingColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        greeting.icon,
                        size: 22,
                        color: JewelVaultColors.accentGold,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${greeting.title}, $firstName',
                          style: JewelVaultTypography.display.copyWith(
                            fontSize: isNarrow ? 24 : 30,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    greeting.subtitle,
                    style: JewelVaultTypography.bodyLarge,
                  ),
                ],
              );

              final addButton = _QuickActionButton(
                label: 'Add Item',
                icon: Icons.add,
                onTap: onNavigateToAdd,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    greetingColumn,
                    const SizedBox(height: 16),
                    Align(alignment: Alignment.centerLeft, child: addButton),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: greetingColumn),
                  const SizedBox(width: 16),
                  addButton,
                ],
              );
            },
          ),

          const SizedBox(height: 32),

          // ── STAT CARDS ──────────────────────────────────────
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isNarrow = constraints.maxWidth < 700;

              return isNarrow
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Total Pieces',
                                value: '${items.length}',
                                icon: Icons.inventory_2_outlined,
                                onTap: onNavigateToCloset,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Garments',
                                value: '$garmentCount',
                                icon: Icons.checkroom_outlined,
                                color: AppColors.tagGarment,
                                onTap: onNavigateToCloset,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Jewelry',
                                value: '$jewelryCount',
                                icon: Icons.diamond_outlined,
                                color: AppColors.tagJewelry,
                                onTap: onNavigateToCloset,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Times Worn',
                                value: '$totalWorn',
                                icon: Icons.repeat_outlined,
                                onTap: onNavigateToCloset,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Total Pieces',
                            value: '${items.length}',
                            icon: Icons.inventory_2_outlined,
                            onTap: onNavigateToCloset,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Garments',
                            value: '$garmentCount',
                            icon: Icons.checkroom_outlined,
                            color: AppColors.tagGarment,
                            onTap: onNavigateToCloset,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Jewelry',
                            value: '$jewelryCount',
                            icon: Icons.diamond_outlined,
                            color: AppColors.tagJewelry,
                            onTap: onNavigateToCloset,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Favourites',
                            value: '$favoriteCount',
                            icon: Icons.favorite_border,
                            color: const Color(0xFFFEF0F0),
                            onTap: onNavigateToCloset,
                          ),
                        ),
                      ],
                    );
            },
          ),

          const SizedBox(height: 32),

          // ── RECENTLY ADDED ────────────────────────────────────
          _RecentlyAddedCard(recent: recent, onViewAll: onNavigateToCloset),

          const SizedBox(height: 32),

          // ── WARDROBE INSIGHTS ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wardrobe Insights',
                style: JewelVaultTypography.headingSmall,
              ),
              GestureDetector(
                onTap: onNavigateToStats,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Full Stats',
                      style: JewelVaultTypography.labelSmall.copyWith(
                        color: JewelVaultColors.primaryEmerald,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: JewelVaultColors.primaryEmerald,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _WardrobeInsightsRow(items: items),

          const SizedBox(height: 32),

          // ── SEASON BREAKDOWN ─────────────────────────────────
          Text('By Season', style: AppTypography.headingSmall),
          const SizedBox(height: 16),
          _SeasonBreakdown(items: items),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryEmerald,
        borderRadius: BorderRadius.circular(12),
        boxShadow: JewelVaultEffects.raised,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.labelLarge.copyWith(color: Colors.white),
          ),
        ],
      ),
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.surface,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JewelVaultColors.border),
        boxShadow: JewelVaultEffects.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color == AppColors.surface ? AppColors.background : color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryEmerald),
          ),
          const SizedBox(height: 16),
          Text(value, style: AppTypography.display.copyWith(fontSize: 28)),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.bodyMedium),
        ],
      ),
    ),
  );
}

class _AISuggestionCard extends StatelessWidget {
  final ClosetItem? pairA;
  final ClosetItem? pairB;
  final VoidCallback onTap;

  const _AISuggestionCard({this.pairA, this.pairB, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'AI PAIR OF THE DAY',
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white70,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (pairA != null && pairB != null) ...[
          Row(
            children: [
              Expanded(child: _PairChip(item: pairA!)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+',
                  style: AppTypography.labelLarge.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _PairChip(item: pairB!)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '"${pairA!.title}" pairs beautifully with "${pairB!.title}" — a ${pairA!.matchScore.toInt()}% aesthetic match for a refined, effortless look.',
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.8),
              height: 1.6,
            ),
          ),
        ],
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Text(
                'See all outfit ideas',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.accentGold,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward,
                color: AppColors.accentGold,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PairChip extends StatelessWidget {
  final ClosetItem item;
  const _PairChip({required this.item});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            item.title,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: AppTypography.labelLarge.copyWith(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RecentlyAddedCard extends StatelessWidget {
  final List<ClosetItem> recent;
  final VoidCallback onViewAll;

  const _RecentlyAddedCard({required this.recent, required this.onViewAll});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: JewelVaultColors.border),
      boxShadow: JewelVaultEffects.card,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recently Added', style: AppTypography.headingSmall),
            GestureDetector(
              onTap: onViewAll,
              child: Text(
                'View All',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primaryEmerald,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...recent.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _categoryColor(item.category),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _itemImage(item, iconSize: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTypography.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.brand,
                        style: AppTypography.bodyMedium.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                _MatchBadge(score: item.matchScore),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _WardrobeInsightsRow extends StatelessWidget {
  final List<ClosetItem> items;
  const _WardrobeInsightsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final topWorn = [...items]
      ..sort((a, b) => b.wornCount.compareTo(a.wornCount));
    final leastWorn = [...items]
      ..sort((a, b) => a.wornCount.compareTo(b.wornCount));

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth > 700;
        final cards = [
          _InsightTile(
            icon: Icons.trending_up,
            label: 'Most Worn',
            value: topWorn.isNotEmpty ? topWorn[0].title : '—',
            sub: topWorn.isNotEmpty ? '${topWorn[0].wornCount}× worn' : '',
            color: const Color(0xFFE8F5E9),
          ),
          _InsightTile(
            icon: Icons.inventory_outlined,
            label: 'Least Worn',
            value: leastWorn.isNotEmpty ? leastWorn[0].title : '—',
            sub: leastWorn.isNotEmpty ? '${leastWorn[0].wornCount}× worn' : '',
            color: const Color(0xFFFFF8E1),
          ),
          _InsightTile(
            icon: Icons.favorite,
            label: 'Top Favourite',
            value: items.where((e) => e.isFavorite).isNotEmpty
                ? items.where((e) => e.isFavorite).first.title
                : '—',
            sub: 'Marked as favourite',
            color: const Color(0xFFFCE4EC),
          ),
        ];

        return isWide
            ? Row(
                children:
                    cards
                        .expand(
                          (c) => [
                            Expanded(child: c),
                            const SizedBox(width: 12),
                          ],
                        )
                        .toList()
                      ..removeLast(),
              )
            : Column(
                children:
                    cards
                        .expand((c) => [c, const SizedBox(height: 12)])
                        .toList()
                      ..removeLast(),
              );
      },
    );
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _InsightTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: JewelVaultColors.border),
      boxShadow: JewelVaultEffects.card,
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColors.primaryEmerald),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(letterSpacing: 0.8),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: AppTypography.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(sub, style: AppTypography.bodyMedium.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SeasonBreakdown extends StatelessWidget {
  final List<ClosetItem> items;
  const _SeasonBreakdown({required this.items});

  @override
  Widget build(BuildContext context) {
    final seasons = ['All', 'Summer', 'Winter', 'Autumn', 'Spring'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: seasons.map((s) {
          final count = items.where((e) => e.season == s).length;
          return Container(
            width: 84,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: JewelVaultColors.border),
              boxShadow: JewelVaultEffects.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_seasonEmoji(s), style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 6),
                Text('$count', style: AppTypography.headingSmall),
                Text(
                  s,
                  style: AppTypography.bodyMedium.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _seasonEmoji(String s) {
    switch (s) {
      case 'Summer':
        return '☀️';
      case 'Winter':
        return '❄️';
      case 'Autumn':
        return '🍂';
      case 'Spring':
        return '🌸';
      default:
        return '✦';
    }
  }
}

// ─────────────────────────────────────────────
//  PAGE: STATISTICS VIEW — vault-wide usage stats
// ─────────────────────────────────────────────

class _StatisticsView extends StatefulWidget {
  final List<ClosetItem> items;
  const _StatisticsView({required this.items});

  @override
  State<_StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<_StatisticsView> {
  String _sortBy = 'Most Worn';
  String _categoryFilter = 'All';

  List<String> get _categories => [
    'All',
    'Garment',
    'Jewelry',
    'Bag',
    'Accessory',
  ];

  List<ClosetItem> get _filteredSorted {
    final list = widget.items
        .where((e) => _categoryFilter == 'All' || e.category == _categoryFilter)
        .toList();
    switch (_sortBy) {
      case 'Most Worn':
        list.sort((a, b) => b.wornCount.compareTo(a.wornCount));
        break;
      case 'Least Worn':
        list.sort((a, b) => a.wornCount.compareTo(b.wornCount));
        break;
      case 'Name':
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'Match Score':
        list.sort((a, b) => b.matchScore.compareTo(a.matchScore));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final totalItems = items.length;
    final totalWears = items.fold(0, (sum, e) => sum + e.wornCount);
    final avgWears = totalItems == 0 ? 0.0 : totalWears / totalItems;
    final neverWorn = items.where((e) => e.wornCount == 0).length;
    final maxWorn = items.isEmpty
        ? 0
        : items.map((e) => e.wornCount).reduce((a, b) => a > b ? a : b);
    final filtered = _filteredSorted;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Usage Statistics', style: JewelVaultTypography.headingLarge),
          const SizedBox(height: 6),
          Text(
            'How often you actually wear what\u2019s in your vault',
            style: JewelVaultTypography.bodyLarge,
          ),
          const SizedBox(height: 28),

          // ── SUMMARY ─────────────────────────────────────────
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              final blocks = [
                _StatBlock(
                  icon: Icons.inventory_2_outlined,
                  label: 'Total Pieces',
                  value: '$totalItems',
                ),
                _StatBlock(
                  icon: Icons.repeat,
                  label: 'Total Wears Logged',
                  value: '$totalWears',
                ),
                _StatBlock(
                  icon: Icons.bar_chart,
                  label: 'Avg Wears / Piece',
                  value: avgWears.toStringAsFixed(1),
                ),
                _StatBlock(
                  icon: Icons.inventory_outlined,
                  label: 'Never Worn',
                  value: '$neverWorn',
                  accent: neverWorn > 0 ? const Color(0xFFFEF0F0) : null,
                ),
              ];
              return isNarrow
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: blocks[0]),
                            const SizedBox(width: 12),
                            Expanded(child: blocks[1]),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: blocks[2]),
                            const SizedBox(width: 12),
                            Expanded(child: blocks[3]),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children:
                          blocks
                              .expand(
                                (b) => [
                                  Expanded(child: b),
                                  const SizedBox(width: 12),
                                ],
                              )
                              .toList()
                            ..removeLast(),
                    );
            },
          ),

          const SizedBox(height: 32),

          // ── DISTRIBUTION ────────────────────────────────────
          Text('Usage Distribution', style: JewelVaultTypography.headingSmall),
          const SizedBox(height: 4),
          Text(
            'How your pieces split by how often they\u2019re worn',
            style: JewelVaultTypography.bodyMedium,
          ),
          const SizedBox(height: 16),
          _UsageDistributionChart(items: items),

          const SizedBox(height: 32),

          // ── BY CATEGORY ──────────────────────────────────────
          Text('By Category', style: JewelVaultTypography.headingSmall),
          const SizedBox(height: 16),
          _CategoryUsageBreakdown(items: items),

          const SizedBox(height: 32),

          // ── EVERY ITEM ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  'Every Item',
                  style: JewelVaultTypography.headingSmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: JewelVaultColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: JewelVaultColors.border),
                ),
                child: DropdownButton<String>(
                  value: _sortBy,
                  isDense: true,
                  underline: const SizedBox(),
                  style: JewelVaultTypography.labelLarge,
                  items: ['Most Worn', 'Least Worn', 'Name', 'Match Score']
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s, child: Text('Sort: $s')),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _sortBy = v ?? 'Most Worn'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _categoryFilter == cat;
                return GestureDetector(
                  onTap: () => setState(() => _categoryFilter = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? JewelVaultColors.primaryEmerald
                          : JewelVaultColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? JewelVaultColors.primaryEmerald
                            : JewelVaultColors.border,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: JewelVaultTypography.labelLarge.copyWith(
                        color: isSelected
                            ? Colors.white
                            : JewelVaultColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.bar_chart,
                      color: JewelVaultColors.border,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No items in this category yet',
                      style: JewelVaultTypography.headingSmall.copyWith(
                        color: JewelVaultColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map(
              (item) => _UsageListTile(
                item: item,
                maxWorn: maxWorn == 0 ? 1 : maxWorn,
              ),
            ),
        ],
      ),
    );
  }
}

// A single summary stat block for the statistics page (icon, big value,
// caption) — deliberately without an onTap, since the page it lives on
// already IS the destination.
class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  const _StatBlock({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: JewelVaultColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: JewelVaultColors.border),
      boxShadow: JewelVaultEffects.card,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent ?? JewelVaultColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: JewelVaultColors.primaryEmerald),
        ),
        const SizedBox(height: 16),
        Text(value, style: JewelVaultTypography.display.copyWith(fontSize: 26)),
        const SizedBox(height: 4),
        Text(label, style: JewelVaultTypography.bodyMedium),
      ],
    ),
  );
}

// Horizontal bar chart bucketing every item by how often it's worn —
// answers "am I actually using what I own" at a glance.
class _UsageDistributionChart extends StatelessWidget {
  final List<ClosetItem> items;
  const _UsageDistributionChart({required this.items});

  @override
  Widget build(BuildContext context) {
    final buckets = <String, int>{
      'Never worn': items.where((e) => e.wornCount == 0).length,
      'Rarely (1\u20133\u00d7)': items
          .where((e) => e.wornCount >= 1 && e.wornCount <= 3)
          .length,
      'Sometimes (4\u20139\u00d7)': items
          .where((e) => e.wornCount >= 4 && e.wornCount <= 9)
          .length,
      'Often (10\u00d7+)': items.where((e) => e.wornCount >= 10).length,
    };
    final barColors = [
      Colors.redAccent,
      JewelVaultColors.accentGold,
      JewelVaultColors.primaryEmerald.withValues(alpha: 0.55),
      JewelVaultColors.primaryEmerald,
    ];
    final maxCount = buckets.values.isEmpty
        ? 1
        : buckets.values.reduce((a, b) => a > b ? a : b);
    final total = items.isEmpty ? 1 : items.length;
    final entries = buckets.entries.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: JewelVaultColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JewelVaultColors.border),
        boxShadow: JewelVaultEffects.card,
      ),
      child: Column(
        children: List.generate(entries.length, (i) {
          final entry = entries[i];
          final fraction = maxCount == 0 ? 0.0 : entry.value / maxCount;
          final pct = (entry.value / total * 100).round();
          return Padding(
            padding: EdgeInsets.only(bottom: i == entries.length - 1 ? 0 : 16),
            child: Row(
              children: [
                SizedBox(
                  width: 128,
                  child: Text(
                    entry.key,
                    style: JewelVaultTypography.bodyMedium.copyWith(
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 20,
                      child: Stack(
                        children: [
                          Container(color: JewelVaultColors.background),
                          FractionallySizedBox(
                            widthFactor: fraction.clamp(0.0, 1.0),
                            child: Container(color: barColors[i]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${entry.value} ($pct%)',
                    textAlign: TextAlign.right,
                    style: JewelVaultTypography.mono.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// Per-category rollup: how many pieces, total wears, and average wears —
// e.g. lets someone see their jewelry sits mostly untouched vs garments.
class _CategoryUsageBreakdown extends StatelessWidget {
  final List<ClosetItem> items;
  const _CategoryUsageBreakdown({required this.items});

  @override
  Widget build(BuildContext context) {
    const categories = ['Garment', 'Jewelry', 'Bag', 'Accessory'];
    return Container(
      decoration: BoxDecoration(
        color: JewelVaultColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JewelVaultColors.border),
        boxShadow: JewelVaultEffects.card,
      ),
      child: Column(
        children: [
          for (int i = 0; i < categories.length; i++) ...[
            Builder(
              builder: (context) {
                final cat = categories[i];
                final catItems = items.where((e) => e.category == cat).toList();
                final wears = catItems.fold(0, (sum, e) => sum + e.wornCount);
                final avg = catItems.isEmpty ? 0.0 : wears / catItems.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: JewelVaultColors.primaryEmerald.withValues(
                            alpha: 0.55,
                          ),
                          border: Border.all(
                            color: _categoryColor(cat),
                            width: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          cat,
                          style: JewelVaultTypography.labelLarge,
                        ),
                      ),
                      Text(
                        '${catItems.length} pieces',
                        style: JewelVaultTypography.bodyMedium.copyWith(
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 90,
                        child: Text(
                          '${avg.toStringAsFixed(1)} avg wears',
                          textAlign: TextAlign.right,
                          style: JewelVaultTypography.mono.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (i != categories.length - 1)
              const Divider(height: 1, color: JewelVaultColors.borderLight),
          ],
        ],
      ),
    );
  }
}

// One row in the full "every item" usage list: thumbnail, name, a usage
// bar relative to the vault's most-worn piece, and the raw wear count.
class _UsageListTile extends StatelessWidget {
  final ClosetItem item;
  final int maxWorn;
  const _UsageListTile({required this.item, required this.maxWorn});

  @override
  Widget build(BuildContext context) {
    final fraction = maxWorn == 0 ? 0.0 : item.wornCount / maxWorn;
    final neverWorn = item.wornCount == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JewelVaultColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JewelVaultColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _categoryColor(item.category),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _itemImage(item, iconSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: JewelVaultTypography.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.brand} \u00b7 ${item.category}',
                  style: JewelVaultTypography.bodyMedium.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: Stack(
                        children: [
                          Container(color: JewelVaultColors.borderLight),
                          FractionallySizedBox(
                            widthFactor: fraction.clamp(0.0, 1.0),
                            child: Container(
                              color: neverWorn
                                  ? Colors.redAccent.withValues(alpha: 0.5)
                                  : JewelVaultColors.primaryEmerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  child: Text(
                    neverWorn ? 'Never' : '${item.wornCount}\u00d7',
                    textAlign: TextAlign.right,
                    style: JewelVaultTypography.labelLarge.copyWith(
                      fontSize: 11,
                      color: neverWorn
                          ? Colors.redAccent
                          : JewelVaultColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            item.isFavorite ? Icons.favorite : Icons.favorite_border,
            size: 14,
            color: item.isFavorite
                ? Colors.redAccent
                : JewelVaultColors.mutedText,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PAGE 2: CLOSET VIEW
// ─────────────────────────────────────────────

class _ClosetView extends StatefulWidget {
  final List<ClosetItem> items;
  final Function(String) onToggleFavorite;
  const _ClosetView({required this.items, required this.onToggleFavorite});
  @override
  State<_ClosetView> createState() => _ClosetViewState();
}

class _ClosetViewState extends State<_ClosetView> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _sortBy = 'Match';

  List<String> get _categories => [
    'All',
    'Garment',
    'Jewelry',
    'Bag',
    'Accessory',
  ];

  List<ClosetItem> get _filtered {
    var list = widget.items.where((item) {
      final matchesCat =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch =
          _searchQuery.isEmpty ||
          item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.brand.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    switch (_sortBy) {
      case 'Match':
        list.sort((a, b) => b.matchScore.compareTo(a.matchScore));
        break;
      case 'Worn':
        list.sort((a, b) => b.wornCount.compareTo(a.wornCount));
        break;
      case 'Name':
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final double width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width > 1100 ? 4 : (width > 700 ? 3 : 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Vault Closet', style: AppTypography.headingLarge),
                    Text(
                      '${filtered.length} of ${widget.items.length} pieces',
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
              // Sort dropdown
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButton<String>(
                  value: _sortBy,
                  isDense: true,
                  underline: const SizedBox(),
                  style: AppTypography.labelLarge,
                  items: ['Match', 'Worn', 'Name']
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s, child: Text('Sort: $s')),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _sortBy = v ?? 'Match'),
                ),
              ),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by name or brand…',
              hintStyle: AppTypography.bodyMedium,
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.mutedText,
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryEmerald),
              ),
            ),
          ),
        ),

        // Category filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryEmerald
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryEmerald
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: AppTypography.labelLarge.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Grid
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, color: AppColors.border, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'No items found',
                        style: AppTypography.headingSmall.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.64,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _ItemCard(
                      item: item,
                      onToggleFavorite: widget.onToggleFavorite,
                      onCategoryTap: (cat) =>
                          setState(() => _selectedCategory = cat),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  final ClosetItem item;
  final Function(String) onToggleFavorite;
  final ValueChanged<String>? onCategoryTap;

  const _ItemCard({
    required this.item,
    required this.onToggleFavorite,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showItemDetailCard(
      context: context,
      item: item,
      onToggleFavorite: onToggleFavorite,
      onCategoryTap: onCategoryTap,
    ),
    child: Container(
      decoration: BoxDecoration(
        color: JewelVaultColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: JewelVaultColors.border),
        boxShadow: JewelVaultEffects.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _categoryColor(item.category),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(child: _itemImage(item)),
                  // Match badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: JewelVaultColors.primaryEmerald,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 9,
                            color: JewelVaultColors.accentGold,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${item.matchScore.toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Worn-count pill, bottom-left, over the image
                  if (item.wornCount > 0)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.repeat,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${item.wornCount}× worn',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Favourite
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => onToggleFavorite(item.id),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: item.isFavorite
                              ? Colors.redAccent
                              : JewelVaultColors.mutedText,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Info + stats
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: JewelVaultTypography.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.brand,
                  style: JewelVaultTypography.bodyMedium.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: JewelVaultColors.borderLight),
                const SizedBox(height: 8),
                // Stats row: category, worn count, style match
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryTag(item.category),
                    const Spacer(),
                    _MiniStat(
                      icon: _seasonIcon(item.season),
                      value: _seasonAbbrev(item.season),
                      caption: 'SEASON',
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.matchScore.toInt()}%',
                          style: JewelVaultTypography.labelLarge.copyWith(
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        _MatchMeter(score: item.matchScore, width: 34),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryTag extends StatelessWidget {
  final String category;
  const _CategoryTag(this.category);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _categoryColor(category),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      category,
      style: AppTypography.labelSmall.copyWith(
        fontSize: 9,
        color: AppColors.primaryEmerald,
        letterSpacing: 0.5,
      ),
    ),
  );
}

Color _categoryColor(String cat) {
  switch (cat) {
    case 'Jewelry':
      return AppColors.tagJewelry;
    case 'Bag':
      return AppColors.tagBag;
    case 'Accessory':
      return AppColors.tagAccessory;
    default:
      return AppColors.tagGarment;
  }
}

IconData _seasonIcon(String season) {
  switch (season) {
    case 'Summer':
      return Icons.wb_sunny_outlined;
    case 'Winter':
      return Icons.ac_unit;
    case 'Autumn':
      return Icons.eco_outlined;
    case 'Spring':
      return Icons.local_florist_outlined;
    default:
      return Icons.all_inclusive;
  }
}

String _seasonAbbrev(String season) {
  if (season.length <= 4) return season;
  return season.substring(0, 3);
}

// A compact icon + value + caption stat, used inside item and look cards.
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String caption;
  final Color? iconColor;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.caption,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor ?? JewelVaultColors.accentGold),
          const SizedBox(width: 3),
          Text(
            value,
            style: JewelVaultTypography.labelLarge.copyWith(fontSize: 12),
          ),
        ],
      ),
      Text(
        caption,
        style: JewelVaultTypography.labelSmall.copyWith(fontSize: 8.5),
      ),
    ],
  );
}

// A slim horizontal bar showing how strongly an item/look matches the
// wearer's style profile — gives the match percentage a visual weight
// beyond just a number.
class _MatchMeter extends StatelessWidget {
  final double score; // 0-100
  final double width;

  const _MatchMeter({required this.score, this.width = 44});

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 100) / 100;
    final color = score >= 90
        ? JewelVaultColors.primaryEmerald
        : JewelVaultColors.accentGold;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: width,
        height: 4,
        child: Stack(
          children: [
            Container(color: JewelVaultColors.borderLight),
            FractionallySizedBox(
              widthFactor: clamped.toDouble(),
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// Tiny colored dot representing a category, used to summarise the item mix
// inside a look/outfit card without repeating full text tags.
class _CategoryDot extends StatelessWidget {
  final String category;
  const _CategoryDot(this.category);

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    margin: const EdgeInsets.only(right: 4),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: JewelVaultColors.primaryEmerald.withValues(alpha: 0.55),
      border: Border.all(color: _categoryColor(category), width: 1.5),
    ),
  );
}

// ─────────────────────────────────────────────
//  ITEM DETAIL SCREEN
// ─────────────────────────────────────────────

// Small outlined pill used for the category / match tags on the vault card
// (e.g. "GARMENT", "80% MATCH") — bordered rather than filled, to sit quietly
// against the white card instead of competing with the photo above it.
class _OutlinedPill extends StatelessWidget {
  final String label;
  final Color? color;
  const _OutlinedPill(this.label, {this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: (color ?? JewelVaultColors.primaryEmerald).withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: (color ?? JewelVaultColors.border).withOpacity(0.5),
      ),
    ),
    child: Text(
      label,
      style: JewelVaultTypography.labelSmall.copyWith(
        fontSize: 10,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
        color: color ?? JewelVaultColors.primaryText,
      ),
    ),
  );
}

// One cell of the 2x2 "vault info" grid (Vault Location, Item Number,
// Archive Date, Verified Status).
class _VaultInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _VaultInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              JewelVaultColors.accentGoldLight,
              JewelVaultColors.background,
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: JewelVaultColors.border.withOpacity(0.6)),
        ),
        child: Icon(icon, size: 15, color: JewelVaultColors.primaryEmerald),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: JewelVaultTypography.labelSmall.copyWith(fontSize: 9),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: JewelVaultTypography.labelLarge.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );
}

// Generates a short curator-style blurb from the item's own fields, since
// the backend doesn't (yet) store a description. Purely presentational —
// swap for `item.description` once that field exists server-side.
String _generateDescription(ClosetItem item) {
  final colorPart = item.color.isNotEmpty && item.color != '—'
      ? '${item.color.toLowerCase()} '
      : '';
  final brandPart = item.brand.isNotEmpty && item.brand != 'Unknown'
      ? 'by ${item.brand}, '
      : '';
  return 'A timeless wardrobe essential: $colorPart${item.category.toLowerCase()} '
      '${brandPart}meticulously curated from your vault. Features a refined '
      'silhouette and durable, well-kept craftsmanship.';
}

// Deterministic placeholder vault fields (location / item number / verified
// status) derived from the item's id, so every item gets a stable-looking
// value without needing new backend columns yet.
String _vaultLocationFor(ClosetItem item) {
  const closets = ['Closet A', 'Closet B', 'Closet C', 'Closet D'];
  return closets[item.id.hashCode.abs() % closets.length];
}

String _itemNumberFor(ClosetItem item) {
  final n = item.id.hashCode.abs() % 999;
  return 'GPV-${n.toString().padLeft(3, '0')}';
}

// Opens the item's vault card as a centered, floating overlay: the closet
// grid stays visible but dims and blurs behind it, rather than navigating
// to a separate full page. Tapping outside the card (or its close button)
// dismisses it.
Future<void> showItemDetailCard({
  required BuildContext context,
  required ClosetItem item,
  required Function(String) onToggleFavorite,
  ValueChanged<String>? onCategoryTap,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Item details',
    barrierColor: JewelVaultColors.background.withOpacity(0.72),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, anim, secAnim) => Center(
      child: _ItemDetailCard(
        item: item,
        onToggleFavorite: onToggleFavorite,
        onCategoryTap: onCategoryTap,
      ),
    ),
    transitionBuilder: (dialogContext, anim, secAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 6 * curved.value,
          sigmaY: 6 * curved.value,
        ),
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

// A small frosted-glass circular button — real backdrop blur plus a
// translucent fill and a soft edge highlight, the way iOS renders controls
// floating over photos/media (Control Center, lock-screen buttons, etc.),
// rather than a flat, fully-opaque white circle.
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.28),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 18,
            color: iconColor ?? JewelVaultColors.primaryText,
          ),
        ),
      ),
    ),
  );
}

class _ItemDetailCard extends StatelessWidget {
  final ClosetItem item;
  final Function(String) onToggleFavorite;
  final ValueChanged<String>? onCategoryTap;

  const _ItemDetailCard({
    required this.item,
    required this.onToggleFavorite,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = size.width < 448 ? size.width - 48 : 400.0;
    // Fixed overall card height (rather than just a max-height constraint)
    // so the Stack below — image layer + scrolling panel layer — has a
    // bounded box to lay its Positioned.fill children out against.
    final cardHeight = size.height * 0.78;
    // How tall the photo's own frame is. Sized from a portrait aspect
    // ratio (rather than a fraction of the card) so the crop always shows
    // the full outfit — head to shoe — instead of zooming in too far.
    // Capped at 62% of the card so short screens still leave room below
    // for the summary panel.
    final imageHeight = (cardWidth / 0.88)
        .clamp(0.0, cardHeight * 0.62)
        .toDouble();
    const panelOverlap = 48.0;
    // Inset of the photo frame from the card's outer edge — this is the
    // gap between the blue (card) and black (photo) outlines in the
    // markup: the photo now sits inside its own rounded frame instead of
    // bleeding to the card's edges. Sized to match the grid card's photo
    // frame (margin 8, radius 14) so the two views feel consistent.
    const imageInset = 8.0;
    const imageRadius = 14.0;

    return GestureDetector(
      // Swallow taps on the card itself so they don't bubble up and hit
      // the barrier behind it (which would close the card).
      onTap: () {},
      child: Container(
        width: cardWidth,
        height: cardHeight,
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: JewelVaultColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: JewelVaultColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: JewelVaultColors.darkEmerald.withOpacity(0.18),
              blurRadius: 56,
              offset: const Offset(0, 26),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        // Parallax layout: the photo is a Positioned layer pinned to the
        // top of the card — it never scrolls. The details panel is a
        // separate scrollable layer stacked on top of it, starting with
        // a transparent spacer the height of the photo. As the person
        // scrolls, only the panel moves, sliding up and over the photo,
        // which stays put underneath.
        child: Stack(
          children: [
            // ── Fixed photo layer ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: imageHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  imageInset,
                  imageInset,
                  imageInset,
                  0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(imageRadius),
                  child: Container(
                    color: _categoryColor(item.category),
                    child: _itemImage(item, iconSize: 72),
                  ),
                ),
              ),
            ),
            // ── Scrolling details layer ── (placed before the controls so
            // it doesn't sit on top of them in the hit-test order — a
            // SingleChildScrollView is hit-test opaque even where its
            // content is blank, so if it were painted last it would
            // silently swallow taps meant for the close/favorite buttons.)
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Transparent spacer so the panel starts near the
                    // bottom of the photo, overlapping it by [panelOverlap].
                    SizedBox(height: imageHeight - panelOverlap),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: cardHeight - (imageHeight - panelOverlap),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(26),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                            decoration: BoxDecoration(
                              color: JewelVaultColors.surface.withOpacity(0.78),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(26),
                              ),
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: JewelVaultTypography.headingSmall
                                      .copyWith(fontSize: 19),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.brand,
                                  style: JewelVaultTypography.bodyMedium,
                                ),
                                const SizedBox(height: 14),
                                const Divider(
                                  height: 1,
                                  color: JewelVaultColors.borderLight,
                                ),
                                const SizedBox(height: 12),
                                // Compact summary row — same tag, season
                                // stat, and match meter as the grid card,
                                // so the two views read as one design.
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _CategoryTag(item.category),
                                    const Spacer(),
                                    _MiniStat(
                                      icon: _seasonIcon(item.season),
                                      value: _seasonAbbrev(item.season),
                                      caption: 'SEASON',
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${item.matchScore.toInt()}%',
                                          style: JewelVaultTypography.labelLarge
                                              .copyWith(fontSize: 12),
                                        ),
                                        const SizedBox(height: 3),
                                        _MatchMeter(
                                          score: item.matchScore,
                                          width: 40,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                // Everything below here is what scrolling
                                // reveals — the photo above stays fixed
                                // while this content slides up over it.
                                const SizedBox(height: 20),
                                const Divider(
                                  height: 1,
                                  color: JewelVaultColors.borderLight,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _generateDescription(item),
                                  style: JewelVaultTypography.bodyMedium
                                      .copyWith(height: 1.6),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _VaultInfoTile(
                                        icon: Icons.inventory_2_outlined,
                                        label: 'Vault Location',
                                        value: _vaultLocationFor(item),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _VaultInfoTile(
                                        icon: Icons.badge_outlined,
                                        label: 'Item Number',
                                        value: _itemNumberFor(item),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _VaultInfoTile(
                                        icon: Icons.repeat,
                                        label: 'Times Worn',
                                        value: '${item.wornCount}',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _VaultInfoTile(
                                        icon: Icons.verified_outlined,
                                        label: 'Verified Status',
                                        value: 'Curated',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                const Divider(
                                  height: 1,
                                  color: JewelVaultColors.borderLight,
                                ),
                                const SizedBox(height: 14),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    onCategoryTap?.call(item.category);
                                  },
                                  child: Row(
                                    children: [
                                      Text(
                                        'Category',
                                        style: JewelVaultTypography.bodyMedium
                                            .copyWith(fontSize: 12),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '|',
                                        style: JewelVaultTypography.bodyMedium
                                            .copyWith(fontSize: 12),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          item.category,
                                          style: JewelVaultTypography.labelLarge
                                              .copyWith(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.arrow_forward,
                                        size: 14,
                                        color: JewelVaultColors.primaryEmerald,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Fixed controls, floating over everything — placed last so
            // they sit on top of the scroll layer for both painting and
            // hit-testing, or taps land on the (invisible) scroll area
            // instead of the button underneath it. Same badge/button
            // styling as the grid card so the two views match. ──
            // Close button, top-left.
            Positioned(
              top: imageInset + 6,
              left: imageInset + 6,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: JewelVaultColors.primaryText,
                    size: 16,
                  ),
                ),
              ),
            ),
            // Match-percentage badge, just under the close button — same
            // emerald pill + sparkle icon as the grid card's badge.
            Positioned(
              top: imageInset + 44,
              left: imageInset + 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: JewelVaultColors.primaryEmerald,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 10,
                      color: JewelVaultColors.accentGold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.matchScore.toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Favorite button, top-right.
            Positioned(
              top: imageInset + 6,
              right: imageInset + 6,
              child: GestureDetector(
                onTap: () => onToggleFavorite(item.id),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: item.isFavorite
                        ? Colors.redAccent
                        : JewelVaultColors.mutedText,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PAGE 3: OUTFITS VIEW
// ─────────────────────────────────────────────

class _OutfitsView extends StatefulWidget {
  final List<ClosetItem> items;
  const _OutfitsView({required this.items});
  @override
  State<_OutfitsView> createState() => _OutfitsViewState();
}

class _OutfitsViewState extends State<_OutfitsView> {
  // ── Saved lookbook ──
  List<Map<String, dynamic>> _looks = [];
  bool _isLoadingLooks = true;

  // ── Builder state ──
  bool _isBuilding = false;
  final TextEditingController _nameController = TextEditingController();
  String _season = 'All';
  String _occasion = 'Casual';
  final Set<String> _tags = {};
  List<_CanvasPiece> _pieces = [];
  int? _selectedIndex;
  bool _isSaving = false;
  bool _isFavoriteDraft = false;
  String? _saveError;
  final GlobalKey _canvasKey = GlobalKey();

  // ── Wardrobe search / filter ──
  String _search = '';
  String _group = 'All';
  bool _favoritesOnly = false;

  // Fixed logical size the outfit board is laid out against. The board is
  // rendered inside a FittedBox so it scales down gracefully on narrow
  // screens without any of the placement math below needing to change.
  static const Size _canvasSize = Size(520, 650);

  @override
  void initState() {
    super.initState();
    _loadLooks();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadLooks() async {
    try {
      final data = await ApiService.fetchOutfits();
      if (!mounted) return;
      setState(() {
        _looks = data;
        _isLoadingLooks = false;
      });
    } catch (e) {
      // Backend not reachable, or no looks endpoint yet — just show the
      // builder with an empty saved lookbook.
      if (!mounted) return;
      setState(() => _isLoadingLooks = false);
    }
  }

  // ── Wardrobe filtering ──

  List<ClosetItem> get _filteredWardrobe {
    return widget.items.where((item) {
      final q = _search.toLowerCase();
      final matchesSearch =
          _search.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.brand.toLowerCase().contains(q) ||
          item.color.toLowerCase().contains(q);
      final matchesGroup = _group == 'All' || _wardrobeGroup(item) == _group;
      final matchesFav = !_favoritesOnly || item.isFavorite;
      return matchesSearch && matchesGroup && matchesFav;
    }).toList();
  }

  bool _isItemInCanvas(String id) => _pieces.any((p) => p.item.id == id);

  // ── Builder lifecycle ──

  void _startBuilding() => setState(() => _isBuilding = true);

  void _cancelBuilding() {
    setState(() {
      _isBuilding = false;
      _pieces = [];
      _selectedIndex = null;
      _saveError = null;
      _isFavoriteDraft = false;
      _nameController.clear();
      _season = 'All';
      _occasion = 'Casual';
      _tags.clear();
    });
  }

  // Recomputes every piece's slot position from scratch, but preserves any
  // manual scale/rotation tweaks for items that were already on the board —
  // so adding or removing a piece re-balances the layout without discarding
  // the user's styling adjustments.
  void _syncPiecesWithSelection(List<ClosetItem> selectedItems) {
    final recomputed = _autoArrangePieces(selectedItems, _canvasSize);
    for (final piece in recomputed) {
      final prevMatches = _pieces.where((p) => p.item.id == piece.item.id);
      if (prevMatches.isNotEmpty) {
        piece.scale = prevMatches.first.scale;
        piece.rotation = prevMatches.first.rotation;
      }
    }
    _pieces = recomputed;
  }

  void _toggleItemInCanvas(ClosetItem item) {
    setState(() {
      final currentItems = _pieces.map((p) => p.item).toList();
      final idx = currentItems.indexWhere((i) => i.id == item.id);
      if (idx >= 0) {
        currentItems.removeAt(idx);
      } else {
        currentItems.add(item);
      }
      _syncPiecesWithSelection(currentItems);
      _selectedIndex = null;
    });
  }

  void _removePiece(int index) {
    setState(() {
      final currentItems = _pieces.map((p) => p.item).toList()..removeAt(index);
      _syncPiecesWithSelection(currentItems);
      _selectedIndex = null;
    });
  }

  void _duplicatePiece(int index) {
    setState(() {
      final src = _pieces[index];
      final copy = _CanvasPiece(
        item: src.item,
        position: src.position + const Offset(16, 16),
        scale: src.scale,
        rotation: src.rotation,
        widthFrac: src.widthFrac,
        heightFrac: src.heightFrac,
      );
      _pieces.add(copy);
      _selectedIndex = _pieces.length - 1;
    });
  }

  void _bringForward(int index) {
    if (index >= _pieces.length - 1) return;
    setState(() {
      final p = _pieces.removeAt(index);
      _pieces.insert(index + 1, p);
      _selectedIndex = index + 1;
    });
  }

  void _sendBackward(int index) {
    if (index <= 0) return;
    setState(() {
      final p = _pieces.removeAt(index);
      _pieces.insert(index - 1, p);
      _selectedIndex = index - 1;
    });
  }

  void _adjustSelected({double scaleDelta = 0, double rotationDelta = 0}) {
    if (_selectedIndex == null) return;
    setState(() {
      final p = _pieces[_selectedIndex!];
      p.scale = (p.scale + scaleDelta).clamp(0.4, 2.5);
      p.rotation += rotationDelta;
    });
  }

  void _resetSelected() {
    if (_selectedIndex == null) return;
    setState(() {
      final piece = _pieces[_selectedIndex!];
      final slot = _slotForItem(piece.item);
      final anchor = _slotAnchorFrac[slot] ?? const Offset(0.5, 0.5);
      piece.position = Offset(
        anchor.dx * _canvasSize.width,
        anchor.dy * _canvasSize.height,
      );
      piece.scale = 1.0;
      piece.rotation = 0.0;
    });
  }

  void _autoArrangeAll() {
    setState(() {
      _pieces = _autoArrangePieces(
        _pieces.map((p) => p.item).toList(),
        _canvasSize,
      );
      _selectedIndex = null;
    });
  }

  Future<void> _shareOutfit() async {
    final name = _nameController.text.trim().isEmpty
        ? 'Untitled Look'
        : _nameController.text.trim();
    final pieceNames = _pieces.map((p) => p.item.title).join(', ');
    await Clipboard.setData(ClipboardData(text: '$name — $pieceNames'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Outfit summary copied — paste it anywhere to share.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Renders the current board to a PNG and sends it through the existing
  // single-photo outfit endpoint, so the backend contract stays untouched
  // while the person still gets to compose the look piece by piece.
  Future<void> _saveOutfit() async {
    if (_pieces.isEmpty) {
      setState(
        () => _saveError = 'Add at least one item to your outfit first.',
      );
      return;
    }
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final boundary =
          _canvasKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final rendered = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await rendered.toByteData(format: ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final xfile = XFile.fromData(
        bytes,
        name: 'outfit-${DateTime.now().millisecondsSinceEpoch}.png',
        mimeType: 'image/png',
      );
      final outfit = await ApiService.createOutfitFromPhoto(
        xfile,
        name: _nameController.text.trim().isEmpty
            ? 'Untitled Look'
            : _nameController.text.trim(),
        season: _season,
        occasion: _occasion,
        tags: _tags.toList(),
        itemIds: _pieces.map((p) => p.item.id).toList(),
        isFavorite: _isFavoriteDraft,
      );
      if (!mounted) return;
      setState(() {
        _looks = [outfit, ..._looks];
        _isSaving = false;
      });
      _cancelBuilding();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Outfit saved to your lookbook.'),
          backgroundColor: JewelVaultColors.primaryEmerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError =
            "Couldn't save that outfit — check your connection and try again.";
      });
    }
  }

  // ── Saved-look actions (local only — no update/delete endpoint exists
  // yet, so these affect this session's view of the lookbook) ──

  void _toggleFavoriteLook(int index) {
    setState(() {
      final look = Map<String, dynamic>.from(_looks[index]);
      look['isFavorite'] = !(look['isFavorite'] == true);
      _looks[index] = look;
    });
  }

  void _confirmDeleteLook(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JewelVaultColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete outfit?', style: JewelVaultTypography.headingSmall),
        content: Text(
          'This removes it from your lookbook.',
          style: JewelVaultTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _looks.removeAt(index));
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _editLook(Map<String, dynamic> look) {
    final ids = (look['itemIds'] as List?)?.cast<String>() ?? const [];
    final matchedItems = ids
        .map((id) => widget.items.where((e) => e.id == id))
        .where((matches) => matches.isNotEmpty)
        .map((matches) => matches.first)
        .toList();
    if (matchedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This look doesn't have editable pieces."),
        ),
      );
      return;
    }
    setState(() {
      _isBuilding = true;
      _nameController.text = (look['name'] as String?) ?? '';
      _season = (look['season'] as String?) ?? 'All';
      _occasion = (look['occasion'] as String?) ?? 'Casual';
      _isFavoriteDraft = look['isFavorite'] == true;
      _tags
        ..clear()
        ..addAll(((look['tags'] as List?)?.cast<String>()) ?? const []);
      _syncPiecesWithSelection(matchedItems);
      _selectedIndex = null;
    });
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _isBuilding ? 1180 : 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Outfit Lookbook', style: JewelVaultTypography.headingLarge),
              const SizedBox(height: 4),
              Text(
                _isBuilding
                    ? 'Build your look, piece by piece.'
                    : 'Curate outfits from your wardrobe, like a digital moodboard.',
                style: JewelVaultTypography.bodyMedium,
              ),
              const SizedBox(height: 28),

              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _isBuilding ? _buildBuilder(context) : _buildCreateCta(),
              ),
              const SizedBox(height: 36),

              if (_isLoadingLooks)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: JewelVaultColors.primaryEmerald,
                    ),
                  ),
                )
              else if (_looks.isNotEmpty) ...[
                Text(
                  'Saved Lookbook',
                  style: JewelVaultTypography.headingSmall,
                ),
                const SizedBox(height: 16),
                _LooksGrid(
                  looks: _looks,
                  items: widget.items,
                  onFavorite: _toggleFavoriteLook,
                  onDelete: _confirmDeleteLook,
                  onEdit: _editLook,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateCta() {
    return Container(
      key: const ValueKey('cta'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: JewelVaultColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: JewelVaultColors.border),
        boxShadow: JewelVaultEffects.card,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: JewelVaultColors.accentGoldLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.checkroom_outlined,
              color: JewelVaultColors.accentGold,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text('Design a new look', style: JewelVaultTypography.headingSmall),
          const SizedBox(height: 6),
          Text(
            'Pick pieces from your wardrobe and arrange them on a styling board.',
            textAlign: TextAlign.center,
            style: JewelVaultTypography.bodyMedium.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: _startBuilding,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Outfit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: JewelVaultColors.primaryEmerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: JewelVaultTypography.labelLarge,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuilder(BuildContext context) {
    return Column(
      key: const ValueKey('builder'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOutfitMeta(),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final wide = constraints.maxWidth > 860;
            final wardrobe = _buildWardrobePanel();
            final canvas = _buildCanvasPanel();
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 340, child: wardrobe),
                  const SizedBox(width: 24),
                  Expanded(child: canvas),
                ],
              );
            }
            return Column(
              children: [wardrobe, const SizedBox(height: 24), canvas],
            );
          },
        ),
        const SizedBox(height: 20),
        _buildToolbar(),
        if (_saveError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF0F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _saveError!,
                    style: JewelVaultTypography.bodyMedium.copyWith(
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _isSaving ? null : _cancelBuilding,
            child: Text(
              'Cancel',
              style: JewelVaultTypography.labelLarge.copyWith(
                color: JewelVaultColors.mutedText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutfitMeta() {
    const seasons = ['All', 'Spring', 'Summer', 'Autumn', 'Winter'];
    const occasions = [
      'Casual',
      'Office',
      'Party',
      'Wedding',
      'Traditional',
      'Vacation',
    ];
    const tagOptions = [
      'Casual',
      'Wedding',
      'Party',
      'Office',
      'Traditional',
      'Vacation',
      'Date Night',
      'Weekend',
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: JewelVaultColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: JewelVaultColors.border),
        boxShadow: JewelVaultEffects.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            style: JewelVaultTypography.headingSmall,
            decoration: InputDecoration(
              hintText: 'Outfit name…',
              hintStyle: JewelVaultTypography.bodyMedium,
              border: InputBorder.none,
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: JewelVaultColors.borderLight),
          const SizedBox(height: 16),
          Text(
            'SEASON',
            style: JewelVaultTypography.labelSmall.copyWith(letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: seasons
                .map(
                  (s) => _chip(
                    label: s,
                    selected: _season == s,
                    onTap: () => setState(() => _season = s),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'OCCASION',
            style: JewelVaultTypography.labelSmall.copyWith(letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: occasions
                .map(
                  (o) => _chip(
                    label: o,
                    selected: _occasion == o,
                    onTap: () => setState(() => _occasion = o),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'TAGS',
            style: JewelVaultTypography.labelSmall.copyWith(letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tagOptions.map((t) {
              final sel = _tags.contains(t);
              return _chip(
                label: t,
                selected: sel,
                onTap: () =>
                    setState(() => sel ? _tags.remove(t) : _tags.add(t)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? JewelVaultColors.primaryEmerald
              : const Color(0xFFF6F1EA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? JewelVaultColors.primaryEmerald
                : JewelVaultColors.border,
          ),
        ),
        child: Text(
          label,
          style: JewelVaultTypography.labelLarge.copyWith(
            fontSize: 12,
            color: selected ? Colors.white : JewelVaultColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildWardrobePanel() {
    final filtered = _filteredWardrobe;
    const groups = [
      'All',
      'Tops',
      'Bottoms',
      'Shoes',
      'Jewelry',
      'Bags',
      'Accessories',
    ];
    return Container(
      height: 560,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JewelVaultColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: JewelVaultColors.border),
        boxShadow: JewelVaultEffects.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Wardrobe', style: JewelVaultTypography.headingSmall),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _favoritesOnly = !_favoritesOnly),
                child: Icon(
                  _favoritesOnly ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: _favoritesOnly
                      ? Colors.redAccent
                      : JewelVaultColors.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search pieces…',
              hintStyle: JewelVaultTypography.bodyMedium,
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: JewelVaultColors.mutedText,
              ),
              filled: true,
              fillColor: const Color(0xFFF6F1EA),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: groups
                  .map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _chip(
                        label: g,
                        selected: _group == g,
                        onTap: () => setState(() => _group = g),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No pieces match',
                      style: JewelVaultTypography.bodyMedium.copyWith(
                        color: JewelVaultColors.mutedText,
                      ),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.68,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      return _WardrobeItemCard(
                        item: item,
                        isAdded: _isItemInCanvas(item.id),
                        onAdd: () => _toggleItemInCanvas(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Outfit Canvas', style: JewelVaultTypography.headingSmall),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _canvasSize.width),
            child: AspectRatio(
              aspectRatio: _canvasSize.width / _canvasSize.height,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _canvasSize.width,
                  height: _canvasSize.height,
                  child: _buildCanvas(),
                ),
              ),
            ),
          ),
        ),
        if (_selectedIndex != null) ...[
          const SizedBox(height: 14),
          _buildSelectedPieceToolbar(),
        ],
      ],
    );
  }

  Widget _buildCanvas() {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = null),
      child: RepaintBoundary(
        key: _canvasKey,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F2),
            borderRadius: BorderRadius.circular(28),
            boxShadow: JewelVaultEffects.raised,
          ),
          clipBehavior: Clip.antiAlias,
          child: _pieces.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.checkroom_outlined,
                        size: 40,
                        color: JewelVaultColors.border,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Add pieces from your wardrobe\nto start styling',
                        textAlign: TextAlign.center,
                        style: JewelVaultTypography.bodyMedium.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    for (int i = 0; i < _pieces.length; i++)
                      _CanvasPieceWidget(
                        key: ValueKey('${_pieces[i].item.id}_$i'),
                        piece: _pieces[i],
                        canvasSize: _canvasSize,
                        selected: _selectedIndex == i,
                        onTap: () => setState(() => _selectedIndex = i),
                        onChanged: (updated) =>
                            setState(() => _pieces[i] = updated),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSelectedPieceToolbar() {
    final piece = _pieces[_selectedIndex!];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: JewelVaultColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JewelVaultColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              piece.item.title,
              style: JewelVaultTypography.labelLarge.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _iconAction(
                  Icons.rotate_left,
                  () => _adjustSelected(rotationDelta: -0.13),
                ),
                _iconAction(
                  Icons.rotate_right,
                  () => _adjustSelected(rotationDelta: 0.13),
                ),
                _iconAction(
                  Icons.remove_circle_outline,
                  () => _adjustSelected(scaleDelta: -0.1),
                ),
                _iconAction(
                  Icons.add_circle_outline,
                  () => _adjustSelected(scaleDelta: 0.1),
                ),
                _iconAction(
                  Icons.flip_to_front,
                  () => _bringForward(_selectedIndex!),
                ),
                _iconAction(
                  Icons.flip_to_back,
                  () => _sendBackward(_selectedIndex!),
                ),
                _iconAction(
                  Icons.content_copy,
                  () => _duplicatePiece(_selectedIndex!),
                ),
                _iconAction(Icons.restart_alt, _resetSelected),
                _iconAction(
                  Icons.delete_outline,
                  () => _removePiece(_selectedIndex!),
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction(IconData icon, VoidCallback onTap, {Color? color}) {
    return IconButton(
      icon: Icon(
        icon,
        size: 18,
        color: color ?? JewelVaultColors.secondaryText,
      ),
      onPressed: onTap,
      splashRadius: 18,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _toolbarButton(
                  icon: Icons.auto_awesome_mosaic_outlined,
                  label: 'Auto Arrange',
                  onTap: _pieces.isEmpty ? null : _autoArrangeAll,
                ),
                const SizedBox(width: 10),
                _toolbarButton(
                  icon: Icons.remove_circle_outline,
                  label: 'Remove Item',
                  onTap: _selectedIndex == null
                      ? null
                      : () => _removePiece(_selectedIndex!),
                ),
                const SizedBox(width: 10),
                _toolbarButton(
                  icon: Icons.ios_share,
                  label: 'Share',
                  onTap: _pieces.isEmpty ? null : _shareOutfit,
                ),
                const SizedBox(width: 10),
                _toolbarButton(
                  icon: _isFavoriteDraft
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: 'Favorite',
                  active: _isFavoriteDraft,
                  onTap: () =>
                      setState(() => _isFavoriteDraft = !_isFavoriteDraft),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _isSaving || _pieces.isEmpty ? null : _saveOutfit,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 18),
          label: Text(_isSaving ? 'Saving…' : 'Save Outfit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: JewelVaultColors.primaryEmerald,
            foregroundColor: Colors.white,
            disabledBackgroundColor: JewelVaultColors.border,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: JewelVaultTypography.labelLarge,
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool active = false,
  }) {
    final enabled = onTap != null;
    final color = !enabled
        ? JewelVaultColors.border
        : (active
              ? JewelVaultColors.primaryEmerald
              : JewelVaultColors.secondaryText);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? JewelVaultColors.primaryEmerald.withOpacity(0.1)
              : JewelVaultColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? JewelVaultColors.primaryEmerald
                : JewelVaultColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: JewelVaultTypography.labelLarge.copyWith(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  OUTFIT LAYOUT ONTOLOGY
// ─────────────────────────────────────────────

// The catalogue only stores a broad `category` (Garment / Jewelry / Bag /
// Accessory) per JewelVault's existing model, so slot placement is inferred
// from category + a keyword scan of the title. This keeps the board fully
// automatic without requiring any backend or model changes.
enum OutfitSlot {
  hat,
  glasses,
  earrings,
  necklace,
  top,
  outerwear,
  watch,
  bracelet,
  ring,
  belt,
  bottom,
  shoes,
  bag,
  other,
}

OutfitSlot _slotForItem(ClosetItem item) {
  final t = item.title.toLowerCase();
  bool has(List<String> words) => words.any((w) => t.contains(w));

  if (item.category == 'Jewelry') {
    if (has(['necklace', 'pendant'])) return OutfitSlot.necklace;
    if (has(['bracelet', 'cuff', 'bangle'])) return OutfitSlot.bracelet;
    if (has(['ring'])) return OutfitSlot.ring;
    if (has(['earring', 'stud', 'hoop'])) return OutfitSlot.earrings;
    if (has(['watch'])) return OutfitSlot.watch;
    return OutfitSlot.necklace;
  }
  if (item.category == 'Bag') return OutfitSlot.bag;
  if (item.category == 'Accessory') {
    if (has(['sunglass', 'glasses', 'shade'])) return OutfitSlot.glasses;
    if (has(['hat', 'cap', 'beanie'])) return OutfitSlot.hat;
    if (has(['belt'])) return OutfitSlot.belt;
    if (has(['watch'])) return OutfitSlot.watch;
    if (has(['scarf'])) return OutfitSlot.necklace;
    if (has(['hair', 'clip', 'headband'])) return OutfitSlot.hat;
    return OutfitSlot.other;
  }
  // Garment
  if (has(['coat', 'trench', 'blazer', 'jacket', 'cardigan', 'parka'])) {
    return OutfitSlot.outerwear;
  }
  if (has(['trouser', 'pant', 'jean', 'skirt', 'short'])) {
    return OutfitSlot.bottom;
  }
  if (has(['shoe', 'boot', 'sneaker', 'heel', 'sandal'])) {
    return OutfitSlot.shoes;
  }
  return OutfitSlot.top;
}

String _wardrobeGroup(ClosetItem item) {
  switch (_slotForItem(item)) {
    case OutfitSlot.top:
    case OutfitSlot.outerwear:
      return 'Tops';
    case OutfitSlot.bottom:
      return 'Bottoms';
    case OutfitSlot.shoes:
      return 'Shoes';
    case OutfitSlot.bag:
      return 'Bags';
    case OutfitSlot.necklace:
    case OutfitSlot.ring:
    case OutfitSlot.bracelet:
    case OutfitSlot.watch:
    case OutfitSlot.earrings:
      return 'Jewelry';
    default:
      return 'Accessories';
  }
}

// Fractional anchor (of canvas width/height) each slot naturally sits at —
// head to toe — so the board always reads like a coherent silhouette.
const Map<OutfitSlot, Offset> _slotAnchorFrac = {
  OutfitSlot.hat: Offset(0.5, 0.07),
  OutfitSlot.glasses: Offset(0.5, 0.15),
  OutfitSlot.earrings: Offset(0.64, 0.19),
  OutfitSlot.necklace: Offset(0.5, 0.24),
  OutfitSlot.top: Offset(0.5, 0.40),
  OutfitSlot.outerwear: Offset(0.5, 0.40),
  OutfitSlot.watch: Offset(0.20, 0.52),
  OutfitSlot.bracelet: Offset(0.80, 0.50),
  OutfitSlot.ring: Offset(0.80, 0.60),
  OutfitSlot.belt: Offset(0.5, 0.55),
  OutfitSlot.bottom: Offset(0.5, 0.67),
  OutfitSlot.shoes: Offset(0.5, 0.90),
  OutfitSlot.bag: Offset(0.86, 0.75),
  OutfitSlot.other: Offset(0.14, 0.90),
};

// Default piece footprint, as a fraction of canvas width/height.
const Map<OutfitSlot, Size> _slotSizeFrac = {
  OutfitSlot.hat: Size(0.20, 0.10),
  OutfitSlot.glasses: Size(0.22, 0.08),
  OutfitSlot.earrings: Size(0.12, 0.08),
  OutfitSlot.necklace: Size(0.22, 0.12),
  OutfitSlot.top: Size(0.42, 0.26),
  OutfitSlot.outerwear: Size(0.46, 0.28),
  OutfitSlot.watch: Size(0.16, 0.10),
  OutfitSlot.bracelet: Size(0.16, 0.10),
  OutfitSlot.ring: Size(0.10, 0.08),
  OutfitSlot.belt: Size(0.30, 0.06),
  OutfitSlot.bottom: Size(0.40, 0.28),
  OutfitSlot.shoes: Size(0.30, 0.14),
  OutfitSlot.bag: Size(0.22, 0.18),
  OutfitSlot.other: Size(0.18, 0.12),
};

// A single item placed on the outfit board. Position is stored in canvas
// -local pixels (against `_canvasSize`); scale/rotation are user-adjustable
// on top of the auto-computed base footprint.
class _CanvasPiece {
  final ClosetItem item;
  Offset position;
  double scale;
  double rotation;
  final double widthFrac;
  final double heightFrac;

  _CanvasPiece({
    required this.item,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    required this.widthFrac,
    required this.heightFrac,
  });

  _CanvasPiece copyWith({Offset? position, double? scale, double? rotation}) {
    return _CanvasPiece(
      item: item,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      widthFrac: widthFrac,
      heightFrac: heightFrac,
    );
  }
}

// Groups the given items by slot and lays each group out centred on its
// anchor, spreading siblings sideways so nothing overlaps.
List<_CanvasPiece> _autoArrangePieces(List<ClosetItem> items, Size canvas) {
  final bySlot = <OutfitSlot, List<ClosetItem>>{};
  for (final it in items) {
    bySlot.putIfAbsent(_slotForItem(it), () => []).add(it);
  }
  final pieces = <_CanvasPiece>[];
  bySlot.forEach((slot, group) {
    final anchor = _slotAnchorFrac[slot] ?? const Offset(0.5, 0.5);
    final size = _slotSizeFrac[slot] ?? const Size(0.2, 0.14);
    final n = group.length;
    for (var i = 0; i < n; i++) {
      final offsetIndex = i - (n - 1) / 2;
      final halfW = size.width * canvas.width / 2;
      final rawDx =
          (anchor.dx * canvas.width) +
          offsetIndex * (size.width * canvas.width * 0.92);
      final dx = rawDx.clamp(halfW + 6, canvas.width - halfW - 6);
      final dy = anchor.dy * canvas.height;
      pieces.add(
        _CanvasPiece(
          item: group[i],
          position: Offset(dx, dy),
          widthFrac: size.width,
          heightFrac: size.height,
        ),
      );
    }
  });
  return pieces;
}

// ─────────────────────────────────────────────
//  WARDROBE ITEM CARD
// ─────────────────────────────────────────────

class _WardrobeItemCard extends StatelessWidget {
  final ClosetItem item;
  final bool isAdded;
  final VoidCallback onAdd;
  const _WardrobeItemCard({
    required this.item,
    required this.isAdded,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1EA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JewelVaultColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _itemImage(item, iconSize: 26)),
                if (item.isFavorite)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.favorite,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CategoryTag(item.category),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: JewelVaultTypography.labelLarge.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.brand} · ${item.color}',
                  style: JewelVaultTypography.bodyMedium.copyWith(
                    fontSize: 9.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isAdded
                          ? JewelVaultColors.primaryEmerald.withOpacity(0.1)
                          : JewelVaultColors.primaryEmerald,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAdded ? Icons.check : Icons.add,
                          size: 13,
                          color: isAdded
                              ? JewelVaultColors.primaryEmerald
                              : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAdded ? 'Added' : 'Add',
                          style: JewelVaultTypography.labelSmall.copyWith(
                            fontSize: 10,
                            color: isAdded
                                ? JewelVaultColors.primaryEmerald
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
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

// ─────────────────────────────────────────────
//  CANVAS PIECE — drag, pinch-scale, rotate
// ─────────────────────────────────────────────

class _CanvasPieceWidget extends StatefulWidget {
  final _CanvasPiece piece;
  final Size canvasSize;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<_CanvasPiece> onChanged;

  const _CanvasPieceWidget({
    super.key,
    required this.piece,
    required this.canvasSize,
    required this.selected,
    required this.onTap,
    required this.onChanged,
  });

  @override
  State<_CanvasPieceWidget> createState() => _CanvasPieceWidgetState();
}

class _CanvasPieceWidgetState extends State<_CanvasPieceWidget> {
  Offset _startFocal = Offset.zero;
  Offset _startPos = Offset.zero;
  double _startScale = 1;
  double _startRotation = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.piece;
    final w = p.widthFrac * widget.canvasSize.width * p.scale;
    final h = p.heightFrac * widget.canvasSize.height * p.scale;
    return Positioned(
      left: p.position.dx - w / 2,
      top: p.position.dy - h / 2,
      width: w,
      height: h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onScaleStart: (details) {
          _startFocal = details.focalPoint;
          _startPos = p.position;
          _startScale = p.scale;
          _startRotation = p.rotation;
        },
        onScaleUpdate: (details) {
          final newPos = _startPos + (details.focalPoint - _startFocal);
          final newScale = (_startScale * details.scale).clamp(0.4, 2.5);
          final newRotation = _startRotation + details.rotation;
          widget.onChanged(
            p.copyWith(
              position: newPos,
              scale: newScale,
              rotation: newRotation,
            ),
          );
        },
        child: Transform.rotate(
          angle: p.rotation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.selected
                    ? JewelVaultColors.primaryEmerald
                    : Colors.white,
                width: widget.selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _itemImage(p.item, iconSize: 22),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SAVED LOOKBOOK
// ─────────────────────────────────────────────

class _LooksGrid extends StatelessWidget {
  final List<Map<String, dynamic>> looks;
  final List<ClosetItem> items;
  final ValueChanged<int> onFavorite;
  final ValueChanged<int> onDelete;
  final ValueChanged<Map<String, dynamic>> onEdit;

  const _LooksGrid({
    required this.looks,
    required this.items,
    required this.onFavorite,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 3
            : (constraints.maxWidth > 560 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 250,
          ),
          itemCount: looks.length,
          itemBuilder: (ctx, i) {
            final look = looks[i];
            final ids = (look['itemIds'] as List?)?.cast<String>() ?? const [];
            final lookItems = ids
                .map((id) => items.where((e) => e.id == id))
                .where((matches) => matches.isNotEmpty)
                .map((matches) => matches.first)
                .toList();
            return _SavedOutfitCard(
              look: look,
              items: lookItems,
              onFavorite: () => onFavorite(i),
              onDelete: () => onDelete(i),
              onEdit: () => onEdit(look),
            );
          },
        );
      },
    );
  }
}

// Same data-URI vs. real-URL handling as _itemImage — the outfit-photo
// upload route stores the image the same way closet items do.
Widget _photoLookImage(String rawUrl) {
  final url = _resolveImageUrl(rawUrl) ?? '';
  Widget fallback() => Container(
    color: JewelVaultColors.tagGarment,
    child: const Icon(
      Icons.style_outlined,
      color: JewelVaultColors.primaryEmerald,
      size: 32,
    ),
  );

  if (url.startsWith('data:')) {
    try {
      final bytes = base64Decode(url.substring(url.indexOf(',') + 1));
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      );
    } catch (e) {
      return fallback();
    }
  }

  return Image.network(
    url,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => fallback(),
  );
}

// Fallback preview for looks that don't carry a rendered photo — a small
// mosaic of the pieces that make up the outfit.
class _LookMosaic extends StatelessWidget {
  final List<ClosetItem> items;
  const _LookMosaic({required this.items});

  @override
  Widget build(BuildContext context) {
    final display = items.take(4).toList();
    return Container(
      color: const Color(0xFFF6F1EA),
      padding: const EdgeInsets.all(6),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: display.length > 1 ? 2 : 1,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: display.length,
        itemBuilder: (ctx, i) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: _categoryColor(display[i].category),
            child: _itemImage(display[i], iconSize: 18),
          ),
        ),
      ),
    );
  }
}

class _SavedOutfitCard extends StatelessWidget {
  final Map<String, dynamic> look;
  final List<ClosetItem> items;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _SavedOutfitCard({
    required this.look,
    required this.items,
    required this.onFavorite,
    required this.onDelete,
    required this.onEdit,
  });

  static String _formatDate(String? iso) {
    if (iso == null) return 'Saved look';
    try {
      final d = DateTime.parse(iso);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}';
    } catch (_) {
      return 'Saved look';
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = look['imageUrl'] as String?;
    final name = (look['name'] as String?) ?? 'Untitled Look';
    final dateLabel = _formatDate(look['createdAt'] as String?);
    final count = items.isNotEmpty
        ? items.length
        : ((look['itemIds'] as List?)?.length ?? 0);
    final isFav = look['isFavorite'] == true;

    return Container(
      decoration: BoxDecoration(
        color: JewelVaultColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: JewelVaultColors.border),
        boxShadow: JewelVaultEffects.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photoUrl != null && photoUrl.isNotEmpty)
                  _photoLookImage(photoUrl)
                else if (items.isNotEmpty)
                  _LookMosaic(items: items)
                else
                  Container(
                    color: const Color(0xFFF6F1EA),
                    child: const Icon(
                      Icons.style_outlined,
                      color: JewelVaultColors.primaryEmerald,
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        size: 14,
                        color: isFav
                            ? Colors.redAccent
                            : JewelVaultColors.mutedText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: JewelVaultTypography.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateLabel · $count piece${count == 1 ? '' : 's'}',
                  style: JewelVaultTypography.bodyMedium.copyWith(
                    fontSize: 10.5,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      onPressed: onEdit,
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: JewelVaultColors.secondaryText,
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      onPressed: onDelete,
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: JewelVaultColors.secondaryText,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  final double score;
  const _MatchBadge({required this.score});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: score >= 90
          ? AppColors.primaryEmerald.withOpacity(0.1)
          : AppColors.accentGoldLight,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '${score.toInt()}% match',
      style: AppTypography.labelSmall.copyWith(
        color: score >= 90 ? AppColors.primaryEmerald : AppColors.accentGold,
        letterSpacing: 0.3,
      ),
    ),
  );
}

// ─────────────────────────────────────────────
//  PAGE 4: ADD ITEM VIEW
// ─────────────────────────────────────────────

class _AddItemView extends StatefulWidget {
  final Function(ClosetItem) onItemAdded;
  final int existingCount;
  const _AddItemView({required this.onItemAdded, required this.existingCount});
  @override
  State<_AddItemView> createState() => _AddItemViewState();
}

class _AddItemViewState extends State<_AddItemView> {
  final ImagePicker _picker = ImagePicker();

  XFile? _pickedImage;
  Uint8List? _previewBytes;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  String? _error;

  // Populated once the AI has looked at the photo.
  Map<String, dynamic>? _extracted;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedImage = file;
        _previewBytes = bytes;
        _extracted = null;
        _error = null;
      });
      _analyze();
    } catch (e) {
      setState(
        () => _error = "Couldn't open the camera/gallery. Please try again.",
      );
    }
  }

  Future<void> _analyze() async {
    if (_pickedImage == null) return;
    setState(() {
      _isAnalyzing = true;
      _error = null;
    });
    try {
      final result = await ApiService.analyzeItemImage(_pickedImage!);
      if (!mounted) return;
      setState(() {
        _extracted = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _error =
            "Couldn't analyze that photo — check your connection and try again.";
      });
    }
  }

  Future<void> _save() async {
    if (_extracted == null || _isSaving) return;
    setState(() => _isSaving = true);

    final category = (_extracted!['category'] as String?) ?? 'Garment';
    final title = (_extracted!['title'] as String?)?.trim();

    final newItem = ClosetItem(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      title: (title == null || title.isEmpty) ? 'Untitled Piece' : title,
      category: category,
      brand: (_extracted!['brand'] as String?) ?? 'Unknown',
      color: (_extracted!['color'] as String?) ?? '—',
      season: (_extracted!['season'] as String?) ?? 'All',
      wornCount: 0,
      matchScore: (_extracted!['matchScore'] as num?)?.toDouble() ?? 80,
      isFavorite: false,
      icon: _iconForCategory(category),
      imageUrl: _extracted!['imageUrl'] as String?,
    );

    widget.onItemAdded(newItem);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _pickedImage = null;
      _previewBytes = null;
      _extracted = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${newItem.title}" has been added to your vault.'),
        backgroundColor: JewelVaultColors.primaryEmerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _reset() {
    setState(() {
      _pickedImage = null;
      _previewBytes = null;
      _extracted = null;
      _error = null;
      _isAnalyzing = false;
    });
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Jewelry':
        return Icons.diamond_outlined;
      case 'Bag':
        return Icons.shopping_bag_outlined;
      case 'Accessory':
        return Icons.face_retouching_natural_outlined;
      default:
        return Icons.checkroom_outlined;
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: JewelVaultColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: JewelVaultColors.primaryEmerald,
                ),
                title: Text(
                  'Take Photo',
                  style: JewelVaultTypography.labelLarge,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: JewelVaultColors.primaryEmerald,
                ),
                title: Text(
                  'Choose from Device',
                  style: JewelVaultTypography.labelLarge,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: JewelVaultTypography.labelSmall),
        ),
        Expanded(
          child: Text(
            value,
            style: JewelVaultTypography.bodyMedium.copyWith(
              color: JewelVaultColors.primaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catalog New Piece', style: AppTypography.headingLarge),
            Text(
              'Snap or upload a photo — the AI fills in the rest.',
              style: JewelVaultTypography.bodyMedium,
            ),
            const SizedBox(height: 28),

            // Photo area
            GestureDetector(
              onTap: _pickedImage == null ? _showSourcePicker : null,
              child: Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  color: JewelVaultColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: JewelVaultColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: _previewBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: JewelVaultColors.accentGoldLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_upload_outlined,
                              color: JewelVaultColors.accentGold,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Upload Photo',
                            style: JewelVaultTypography.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to take a photo or choose from your device',
                            style: JewelVaultTypography.bodyMedium.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_previewBytes!, fit: BoxFit.cover),
                          if (_isAnalyzing)
                            Container(
                              color: Colors.black.withOpacity(0.45),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Analyzing with AI…',
                                    style: JewelVaultTypography.labelLarge
                                        .copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: _isAnalyzing ? null : _reset,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF0F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: JewelVaultTypography.bodyMedium.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(onPressed: _analyze, child: const Text('Retry')),
                  ],
                ),
              ),
            ],

            // AI-extracted details (read-only — no manual entry)
            if (_extracted != null) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: JewelVaultColors.accentGold,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Detected Details',
                    style: JewelVaultTypography.headingSmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: JewelVaultColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: JewelVaultColors.border),
                ),
                child: Column(
                  children: [
                    _detailRow(
                      'Name',
                      (_extracted!['title'] as String?) ?? '—',
                    ),
                    const Divider(
                      height: 1,
                      color: JewelVaultColors.borderLight,
                    ),
                    _detailRow(
                      'Brand',
                      (_extracted!['brand'] as String?) ?? 'Unknown',
                    ),
                    const Divider(
                      height: 1,
                      color: JewelVaultColors.borderLight,
                    ),
                    _detailRow(
                      'Color',
                      (_extracted!['color'] as String?) ?? '—',
                    ),
                    const Divider(
                      height: 1,
                      color: JewelVaultColors.borderLight,
                    ),
                    _detailRow(
                      'Category',
                      (_extracted!['category'] as String?) ?? 'Garment',
                    ),
                    const Divider(
                      height: 1,
                      color: JewelVaultColors.borderLight,
                    ),
                    _detailRow(
                      'Season',
                      (_extracted!['season'] as String?) ?? 'All',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _showSourcePicker,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retake Photo'),
                style: TextButton.styleFrom(
                  foregroundColor: JewelVaultColors.secondaryText,
                ),
              ),
            ],

            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _extracted == null || _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: JewelVaultColors.primaryEmerald,
                foregroundColor: Colors.white,
                disabledBackgroundColor: JewelVaultColors.border,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: JewelVaultTypography.labelLarge,
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save to Vault'),
            ),
          ],
        ),
      ),
    );
  }
}
