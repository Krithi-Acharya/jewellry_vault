import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../api_service.dart';
import '../services/auth_service.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';

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
  });

  ClosetItem copyWith({bool? isFavorite}) => ClosetItem(
    id: id,
    title: title,
    category: category,
    brand: brand,
    color: color,
    season: season,
    wornCount: wornCount,
    matchScore: matchScore,
    isFavorite: isFavorite ?? this.isFavorite,
    icon: icon,
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
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _loadClosetItems();
    AuthService.instance.fetchProfile().then((profile) {
      if (mounted) {
        setState(() {
          _isAdmin = profile.isAdmin;
          _displayName = profile.displayName;
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
      case 'My Closet':
        Navigator.pushNamed(context, '/closet');
        break;
      case 'Add New Item':
        Navigator.pushNamed(context, '/upload');
        break;
      case 'Admin':
        Navigator.pushNamed(context, '/admin');
        break;
      default:
        setState(() => _selectedIndex = index);
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

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryEmerald,
          ),
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
                const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.mutedText),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
        onNavigateToOutfits: () => setState(() => _selectedIndex = 2),
        onNavigateToAdd: () => Navigator.pushNamed(context, '/upload'),
      ),
      _ClosetView(items: _closetItems, onToggleFavorite: _toggleFavorite),
      _OutfitsView(items: _closetItems),
      _AddItemView(onItemAdded: _addItem, existingCount: _closetItems.length),
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
              ),
            )
          : null,
      appBar: !isDesktop
          ? AppBar(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: _LogoRow(),
              iconTheme: const IconThemeData(
                color: AppColors.primaryEmerald,
              ),
            )
          : null,
      body: Row(
        children: [
          if (isDesktop)
            SizedBox(
              width: 260,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: AppColors.border),
                  ),
                ),
                child: _SidebarContent(
                  selectedIndex: _selectedIndex,
                  navItems: _navItems,
                  displayName: _displayName,
                  onSelected: (i) => _handleNavTap(_navItems[i], i),
                ),
              ),
            ),
          Expanded(
            child: SafeArea(
              child: AnimatedSwitcher(
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
                  key: ValueKey(_selectedIndex),
                  child: views[_selectedIndex],
                ),
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
  final String? displayName;
  final Function(int) onSelected;

  const _SidebarContent({
    required this.selectedIndex,
    required this.navItems,
    required this.onSelected,
    this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        // Prefer the name synced to our own backend - Firebase Auth's own
        // displayName is only set if something calls updateProfile() on the
        // Firebase user, which this app never does, so it's null even for
        // accounts that gave a name at signup.
        final resolvedName = displayName?.isNotEmpty == true
            ? displayName
            : user?.displayName;
        final greetingName =
            resolvedName ?? user?.email?.split('@')[0] ?? 'User';

        return Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LogoRow(),
              const SizedBox(height: 44),
              Text(
                'MENU',
                style: AppTypography.labelSmall.copyWith(
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: navItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = navItems[index];
                    final isSelected = selectedIndex == index;
                    return InkWell(
                      onTap: () => onSelected(index),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
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
                              size: 20,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              item['title'],
                              style: AppTypography.labelLarge.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primaryText,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
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
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.accentGoldLight,
                  child: Text(
                    greetingName.isNotEmpty ? greetingName[0].toUpperCase() : 'U',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.accentGold,
                    ),
                  ),
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
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  PAGE 1: DASHBOARD VIEW
// ─────────────────────────────────────────────

class _DashboardView extends StatelessWidget {
  final List<ClosetItem> items;
  final String? displayName;
  final VoidCallback onNavigateToCloset;
  final VoidCallback onNavigateToOutfits;
  final VoidCallback onNavigateToAdd;

  const _DashboardView({
    required this.items,
    required this.onNavigateToCloset,
    required this.onNavigateToOutfits,
    required this.onNavigateToAdd,
    this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Prefer the name synced to our own backend over Firebase Auth's own
    // displayName, which this app never sets via updateProfile().
    final resolvedName = displayName?.isNotEmpty == true ? displayName : user?.displayName;
    final greetingName = resolvedName ?? user?.email?.split('@')[0] ?? 'there';
    final firstName = greetingName.split(' ')[0];

    final garmentCount = items.where((e) => e.category == 'Garment').length;
    final jewelryCount = items.where((e) => e.category == 'Jewelry').length;
    final favoriteCount = items.where((e) => e.isFavorite).length;
    final totalWorn = items.fold(0, (sum, e) => sum + e.wornCount);

    // Best match pair
    final topItems = [...items]
      ..sort((a, b) => b.matchScore.compareTo(a.matchScore));
    final bestPairA = topItems.isNotEmpty ? topItems[0] : null;
    final bestPairB = topItems.length > 1 ? topItems[1] : null;

    // Recently added
    final recent = items.reversed.take(3).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HERO GREETING ──────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good morning, $firstName ✦',
                      style: AppTypography.display.copyWith(
                        fontSize: 30,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your collection is looking exceptional today.',
                      style: AppTypography.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _QuickActionButton(
                label: 'Add Item',
                icon: Icons.add,
                onTap: onNavigateToAdd,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── STAT CARDS ──────────────────────────────────────
          LayoutBuilder(
            builder: (ctx, constraints) {
              final w = (constraints.maxWidth - 48) / 4;
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

          // ── TWO-COLUMN ROW ───────────────────────────────────
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 750;
              final aiSuggestion = _AISuggestionCard(
                pairA: bestPairA,
                pairB: bestPairB,
                onTap: onNavigateToOutfits,
              );
              final recentCard = _RecentlyAddedCard(
                recent: recent,
                onViewAll: onNavigateToCloset,
              );

              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: aiSuggestion),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: recentCard),
                      ],
                    )
                  : Column(
                      children: [
                        aiSuggestion,
                        const SizedBox(height: 16),
                        recentCard,
                      ],
                    );
            },
          ),

          const SizedBox(height: 32),

          // ── WARDROBE INSIGHTS ────────────────────────────────
          Text('Wardrobe Insights', style: AppTypography.headingSmall),
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
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: Colors.white,
            ),
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
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color == AppColors.surface
                  ? AppColors.background
                  : color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryEmerald),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: AppTypography.display.copyWith(fontSize: 28),
          ),
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
              _PairChip(item: pairA!),
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
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _PairChip(item: pairB!),
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
        Text(
          item.title,
          style: AppTypography.labelLarge.copyWith(
            color: Colors.white,
            fontSize: 12,
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
      border: Border.all(color: AppColors.border),
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
                  decoration: BoxDecoration(
                    color: _categoryColor(item.category),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: AppColors.primaryEmerald,
                  ),
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
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 11,
                        ),
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
      border: Border.all(color: AppColors.border),
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
                style: AppTypography.labelSmall.copyWith(
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: AppTypography.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                sub,
                style: AppTypography.bodyMedium.copyWith(fontSize: 11),
              ),
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
    return Row(
      children: seasons.map((s) {
        final count = items.where((e) => e.season == s).length;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(_seasonEmoji(s), style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                Text('$count', style: AppTypography.headingSmall),
                Text(
                  s,
                  style: AppTypography.bodyMedium.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
                    Text(
                      'My Vault Closet',
                      style: AppTypography.headingLarge,
                    ),
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
                borderSide: const BorderSide(
                  color: AppColors.primaryEmerald,
                ),
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
                      Icon(
                        Icons.search_off,
                        color: AppColors.border,
                        size: 48,
                      ),
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
                    childAspectRatio: 0.72,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _ItemCard(
                      item: item,
                      onToggleFavorite: widget.onToggleFavorite,
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

  const _ItemCard({required this.item, required this.onToggleFavorite});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
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
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    item.icon,
                    size: 36,
                    color: AppColors.primaryEmerald.withOpacity(0.4),
                  ),
                ),
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
                      color: AppColors.primaryEmerald,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${item.matchScore.toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Favourite
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => onToggleFavorite(item.id),
                    child: Icon(
                      item.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: item.isFavorite
                          ? Colors.redAccent
                          : AppColors.mutedText,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Info
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: AppTypography.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                item.brand,
                style: AppTypography.bodyMedium.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _CategoryTag(item.category),
                  const Spacer(),
                  Icon(
                    Icons.repeat,
                    size: 11,
                    color: AppColors.mutedText,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${item.wornCount}×',
                    style: AppTypography.mono.copyWith(fontSize: 10),
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

// ─────────────────────────────────────────────
//  PAGE 3: OUTFITS VIEW
// ─────────────────────────────────────────────

class _OutfitsView extends StatelessWidget {
  final List<ClosetItem> items;
  const _OutfitsView({required this.items});

  List<List<ClosetItem>> get _outfits {
    final garments = items.where((e) => e.category == 'Garment').toList();
    final jewelry = items.where((e) => e.category == 'Jewelry').toList();
    final bags = items.where((e) => e.category == 'Bag').toList();
    final accessories = items.where((e) => e.category == 'Accessory').toList();

    final results = <List<ClosetItem>>[];
    for (int i = 0; i < garments.length && results.length < 6; i++) {
      final outfit = [garments[i]];
      if (jewelry.length > i % jewelry.length)
        outfit.add(jewelry[i % jewelry.length]);
      if (bags.isNotEmpty) outfit.add(bags[i % bags.length]);
      if (accessories.isNotEmpty && i % 2 == 0)
        outfit.add(accessories[i % accessories.length]);
      results.add(outfit);
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final outfits = _outfits;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Outfit Lookbook', style: AppTypography.headingLarge),
          Text(
            'Smart pairings curated from your closet.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 700;
              return isWide
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 180,
                          ),
                      itemCount: outfits.length,
                      itemBuilder: (ctx, i) =>
                          _OutfitCard(outfitIndex: i + 1, items: outfits[i]),
                    )
                  : Column(
                      children: outfits
                          .asMap()
                          .entries
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _OutfitCard(
                                outfitIndex: e.key + 1,
                                items: e.value,
                              ),
                            ),
                          )
                          .toList(),
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _OutfitCard extends StatelessWidget {
  final int outfitIndex;
  final List<ClosetItem> items;
  const _OutfitCard({required this.outfitIndex, required this.items});

  @override
  Widget build(BuildContext context) {
    final avgMatch = items.isEmpty
        ? 0.0
        : items.fold(0.0, (s, i) => s + i.matchScore) / items.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Outfit $outfitIndex',
                style: AppTypography.headingSmall,
              ),
              _MatchBadge(score: avgMatch),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: Row(
              children: items
                  .take(4)
                  .map(
                    (item) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _categoryColor(item.category),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              color: AppColors.primaryEmerald,
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                item.title,
                                style: AppTypography.labelSmall.copyWith(
                                  fontSize: 9,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
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
        color: score >= 90
            ? AppColors.primaryEmerald
            : AppColors.accentGold,
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
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _brand = '';
  String _color = '';
  String _category = 'Garment';
  String _season = 'All';

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final newItem = ClosetItem(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        title: _title,
        category: _category,
        brand: _brand.isEmpty ? 'Unknown' : _brand,
        color: _color.isEmpty ? '—' : _color,
        season: _season,
        wornCount: 0,
        matchScore: 80,
        isFavorite: false,
        icon: _category == 'Jewelry'
            ? Icons.diamond_outlined
            : _category == 'Bag'
            ? Icons.shopping_bag_outlined
            : _category == 'Accessory'
            ? Icons.face_retouching_natural_outlined
            : Icons.checkroom_outlined,
      );
      widget.onItemAdded(newItem);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$_title" has been added to your vault.'),
          backgroundColor: AppColors.primaryEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  InputDecoration _fieldDecoration(String label, {IconData? icon}) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.secondaryText),
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.mutedText, size: 20)
            : null,
        filled: true,
        fillColor: AppColors.surface,
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
          borderSide: const BorderSide(
            color: AppColors.primaryEmerald,
            width: 1.5,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catalog New Piece', style: AppTypography.headingLarge),
            Text(
              'Add a new item to your digital vault.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 28),

            // Upload area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.border,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.accentGoldLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      color: AppColors.accentGold,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Upload Photo', style: AppTypography.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Drag & drop or tap to browse  ·  PNG, JPG',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    decoration: _fieldDecoration(
                      'Item Name *',
                      icon: Icons.label_outline,
                    ),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primaryText,
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Please enter a name' : null,
                    onChanged: (v) => _title = v,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: _fieldDecoration(
                      'Brand (optional)',
                      icon: Icons.storefront_outlined,
                    ),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primaryText,
                    ),
                    onChanged: (v) => _brand = v,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: _fieldDecoration(
                      'Primary Color',
                      icon: Icons.palette_outlined,
                    ),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primaryText,
                    ),
                    onChanged: (v) => _color = v,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: _fieldDecoration('Category'),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primaryText,
                    ),
                    items: ['Garment', 'Jewelry', 'Bag', 'Accessory']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _category = v ?? 'Garment'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _season,
                    decoration: _fieldDecoration('Season'),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primaryText,
                    ),
                    items: ['All', 'Summer', 'Winter', 'Autumn', 'Spring']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _season = v ?? 'All'),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: AppTypography.labelLarge,
                      elevation: 0,
                    ),
                    child: const Text('Save to Vault'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
