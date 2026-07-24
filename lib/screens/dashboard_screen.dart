import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../api_service.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────
//  DESIGN SYSTEM
// ─────────────────────────────────────────────

class JewelVaultColors {
  static const Color background = Color(0xFFF7F3EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primaryEmerald = Color(0xFF1B4332);
  static const Color darkEmerald = Color(0xFF012D1D);
  static const Color accentGold = Color(0xFFB8976A);
  static const Color accentGoldLight = Color(0xFFF5ECD9);
  static const Color border = Color(0xFFE5DDD0);
  static const Color borderLight = Color(0xFFF0EAE0);
  static const Color primaryText = Color(0xFF1A1815);
  static const Color secondaryText = Color(0xFF6B6258);
  static const Color mutedText = Color(0xFFAA9E94);
  static const Color tagGarment = Color(0xFFE8F4F0);
  static const Color tagJewelry = Color(0xFFF5ECD9);
  static const Color tagAccessory = Color(0xFFF0EBF5);
  static const Color tagBag = Color(0xFFEFF3FA);
}

class JewelVaultTypography {
  static TextStyle display = GoogleFonts.fraunces(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    color: JewelVaultColors.primaryText,
    height: 1.2,
  );
  static TextStyle headingLarge = GoogleFonts.fraunces(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    color: JewelVaultColors.primaryText,
    height: 1.4,
  );
  static TextStyle headingMedium = GoogleFonts.fraunces(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: JewelVaultColors.primaryText,
  );
  static TextStyle headingSmall = GoogleFonts.fraunces(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: JewelVaultColors.primaryText,
  );
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w300,
    color: JewelVaultColors.secondaryText,
    height: 1.6,
  );
  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: JewelVaultColors.secondaryText,
    height: 1.6,
  );
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: JewelVaultColors.primaryText,
  );
  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
    color: JewelVaultColors.mutedText,
  );
  static TextStyle mono = GoogleFonts.spaceMono(
    fontSize: 12,
    color: JewelVaultColors.secondaryText,
  );
}

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
    imageUrl: imageUrl,
  );

  /// Builds a ClosetItem from the JSON shape returned by the backend API.
  factory ClosetItem.fromJson(Map<String, dynamic> json) => ClosetItem(
    id: json['id'].toString(),
    title: json['title'] ?? '',
    category: json['category'] ?? 'Garment',
    brand: json['brand'] ?? 'Unknown',
    color: json['color'] ?? '—',
    season: json['season'] ?? 'All',
    wornCount: json['wornCount'] ?? 0,
    matchScore: (json['matchScore'] as num?)?.toDouble() ?? 80,
    isFavorite: json['isFavorite'] ?? false,
    icon: _iconFromKey(json['icon'] ?? 'checkroom_outlined'),
    imageUrl: json['imageUrl'] as String?,
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

String _iconToKey(IconData icon) {
  if (icon == Icons.diamond_outlined) return 'diamond_outlined';
  if (icon == Icons.shopping_bag_outlined) return 'shopping_bag_outlined';
  if (icon == Icons.face_retouching_natural_outlined) {
    return 'face_retouching_natural_outlined';
  }
  return 'checkroom_outlined';
}

// Renders an item's photo when available, falling back to its category
// icon (e.g. for the offline/seed items, or if the image fails to load).
Widget _itemImage(ClosetItem item, {double iconSize = 36}) {
  final url = item.imageUrl;
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
//  SEED DATA
// ─────────────────────────────────────────────

final List<ClosetItem> _seedItems = [
  ClosetItem(
    id: '1',
    title: 'Silk Slip Dress',
    category: 'Garment',
    brand: 'Reformation',
    color: 'Champagne',
    season: 'Summer',
    wornCount: 6,
    matchScore: 98,
    isFavorite: true,
    icon: Icons.checkroom_outlined,
  ),
  ClosetItem(
    id: '2',
    title: 'Emerald Pendant',
    category: 'Jewelry',
    brand: 'Mejuri',
    color: 'Green',
    season: 'All',
    wornCount: 12,
    matchScore: 98,
    isFavorite: true,
    icon: Icons.diamond_outlined,
  ),
  ClosetItem(
    id: '3',
    title: 'Velvet Blazer',
    category: 'Garment',
    brand: 'Zara',
    color: 'Midnight Blue',
    season: 'Winter',
    wornCount: 4,
    matchScore: 92,
    isFavorite: false,
    icon: Icons.checkroom_outlined,
  ),
  ClosetItem(
    id: '4',
    title: 'Diamond Stud Earrings',
    category: 'Jewelry',
    brand: 'Tiffany & Co.',
    color: 'Silver',
    season: 'All',
    wornCount: 20,
    matchScore: 95,
    isFavorite: true,
    icon: Icons.diamond_outlined,
  ),
  ClosetItem(
    id: '5',
    title: 'Cashmere Trench',
    category: 'Garment',
    brand: 'Max Mara',
    color: 'Camel',
    season: 'Autumn',
    wornCount: 8,
    matchScore: 91,
    isFavorite: false,
    icon: Icons.checkroom_outlined,
  ),
  ClosetItem(
    id: '6',
    title: 'Pearl Drop Necklace',
    category: 'Jewelry',
    brand: 'Mikimoto',
    color: 'White',
    season: 'All',
    wornCount: 5,
    matchScore: 89,
    isFavorite: false,
    icon: Icons.diamond_outlined,
  ),
  ClosetItem(
    id: '7',
    title: 'Linen Wide-Leg Trousers',
    category: 'Garment',
    brand: 'COS',
    color: 'Ecru',
    season: 'Summer',
    wornCount: 9,
    matchScore: 87,
    isFavorite: false,
    icon: Icons.checkroom_outlined,
  ),
  ClosetItem(
    id: '8',
    title: 'Gold Cuff Bracelet',
    category: 'Jewelry',
    brand: 'Monica Vinader',
    color: 'Gold',
    season: 'All',
    wornCount: 15,
    matchScore: 94,
    isFavorite: true,
    icon: Icons.diamond_outlined,
  ),
  ClosetItem(
    id: '9',
    title: 'Quilted Evening Bag',
    category: 'Bag',
    brand: 'Chanel',
    color: 'Black',
    season: 'All',
    wornCount: 7,
    matchScore: 96,
    isFavorite: true,
    icon: Icons.shopping_bag_outlined,
  ),
  ClosetItem(
    id: '10',
    title: 'Merino Turtleneck',
    category: 'Garment',
    brand: 'Uniqlo',
    color: 'Ivory',
    season: 'Winter',
    wornCount: 14,
    matchScore: 83,
    isFavorite: false,
    icon: Icons.checkroom_outlined,
  ),
  ClosetItem(
    id: '11',
    title: 'Tortoise Sunglasses',
    category: 'Accessory',
    brand: 'Celine',
    color: 'Tortoise',
    season: 'Summer',
    wornCount: 18,
    matchScore: 85,
    isFavorite: false,
    icon: Icons.wb_sunny_outlined,
  ),
  ClosetItem(
    id: '12',
    title: 'Sapphire Ring',
    category: 'Jewelry',
    brand: 'Catbird',
    color: 'Blue',
    season: 'All',
    wornCount: 3,
    matchScore: 90,
    isFavorite: false,
    icon: Icons.diamond_outlined,
  ),
  ClosetItem(
    id: '13',
    title: 'Satin Midi Skirt',
    category: 'Garment',
    brand: 'Rotate',
    color: 'Blush',
    season: 'Spring',
    wornCount: 5,
    matchScore: 88,
    isFavorite: false,
    icon: Icons.checkroom_outlined,
  ),
  ClosetItem(
    id: '14',
    title: 'Leather Tote',
    category: 'Bag',
    brand: 'A.P.C.',
    color: 'Tan',
    season: 'All',
    wornCount: 22,
    matchScore: 93,
    isFavorite: true,
    icon: Icons.shopping_bag_outlined,
  ),
  ClosetItem(
    id: '15',
    title: 'Crystal Hair Clip',
    category: 'Accessory',
    brand: 'Jennifer Behr',
    color: 'Crystal',
    season: 'All',
    wornCount: 10,
    matchScore: 82,
    isFavorite: false,
    icon: Icons.face_retouching_natural_outlined,
  ),
  ClosetItem(
    id: '16',
    title: 'Silk Scarf',
    category: 'Accessory',
    brand: 'Hermès',
    color: 'Multi',
    season: 'Spring',
    wornCount: 6,
    matchScore: 91,
    isFavorite: true,
    icon: Icons.wb_cloudy_outlined,
  ),
];

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

  // Server-resolved display name (backend falls back to the email prefix
  // if the user hasn't synced a name yet). 'there' is only shown for the
  // brief moment before the fetch below completes.
  String _displayName = 'there';

  @override
  void initState() {
    super.initState();
    _loadClosetItems();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final data = await ApiService.fetchDashboard();
      if (!mounted) return;
      setState(() {
        _displayName = (data['username'] as String?) ?? _displayName;
      });
    } catch (e) {
      // Backend not reachable, or /api/dashboard errored — keep the
      // 'there' fallback, but log so this is actually debuggable.
      debugPrint('fetchDashboard failed: $e');
    }
  }

  Future<void> _loadClosetItems() async {
    try {
      final data = await ApiService.fetchClosetItems();
      setState(() {
        _closetItems = data.map(ClosetItem.fromJson).toList();
        _isLoading = false;
      });
    } catch (e) {
      // Backend not reachable yet (e.g. server not running) — fall back to
      // sample data so the UI is still usable during development.
      setState(() {
        _closetItems = List.from(_seedItems);
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reach the server — showing sample data.'),
          ),
        );
      }
    }
  }

  final List<Map<String, dynamic>> _navItems = [
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
      'title': 'Statistics',
      'icon': Icons.bar_chart_outlined,
      'selectedIcon': Icons.bar_chart,
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
        backgroundColor: JewelVaultColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: JewelVaultColors.primaryEmerald,
          ),
        ),
      );
    }

    final List<Widget> views = [
      _DashboardView(
        items: _closetItems,
        displayName: _displayName,
        onNavigateToCloset: () => setState(() => _selectedIndex = 1),
        onNavigateToAdd: () => setState(() => _selectedIndex = 3),
        onNavigateToStats: () => setState(() => _selectedIndex = 4),
      ),
      _ClosetView(items: _closetItems, onToggleFavorite: _toggleFavorite),
      _OutfitsView(items: _closetItems),
      _AddItemView(onItemAdded: _addItem, existingCount: _closetItems.length),
      _StatisticsView(items: _closetItems),
    ];

    return Scaffold(
      backgroundColor: JewelVaultColors.background,
      drawer: !isDesktop
          ? Drawer(
              backgroundColor: JewelVaultColors.surface,
              child: _SidebarContent(
                selectedIndex: _selectedIndex,
                navItems: _navItems,
                displayName: _displayName,
                onSelected: (i) {
                  setState(() => _selectedIndex = i);
                  Navigator.pop(context);
                },
              ),
            )
          : null,
      appBar: !isDesktop
          ? AppBar(
              backgroundColor: JewelVaultColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: _LogoRow(),
              iconTheme: const IconThemeData(
                color: JewelVaultColors.primaryEmerald,
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
                    right: BorderSide(color: JewelVaultColors.border),
                  ),
                ),
                child: _SidebarContent(
                  selectedIndex: _selectedIndex,
                  navItems: _navItems,
                  displayName: _displayName,
                  onSelected: (i) => setState(() => _selectedIndex = i),
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
          color: JewelVaultColors.primaryEmerald,
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
        style: JewelVaultTypography.headingMedium.copyWith(letterSpacing: -0.5),
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

  const _SidebarContent({
    required this.selectedIndex,
    required this.navItems,
    required this.displayName,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: JewelVaultColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LogoRow(),
          const SizedBox(height: 44),
          Text(
            'MENU',
            style: JewelVaultTypography.labelSmall.copyWith(letterSpacing: 1.5),
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
                          ? JewelVaultColors.primaryEmerald
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? item['selectedIcon'] : item['icon'],
                          color: isSelected
                              ? Colors.white
                              : JewelVaultColors.secondaryText,
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          item['title'],
                          style: JewelVaultTypography.labelLarge.copyWith(
                            color: isSelected
                                ? Colors.white
                                : JewelVaultColors.primaryText,
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
          Container(height: 1, color: JewelVaultColors.border),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: JewelVaultColors.accentGoldLight,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: JewelVaultTypography.labelLarge.copyWith(
                  color: JewelVaultColors.accentGold,
                ),
              ),
            ),
            title: Text(
              displayName,
              style: JewelVaultTypography.labelLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Premium Member',
              style: JewelVaultTypography.bodyMedium.copyWith(fontSize: 11),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
              onPressed: () async {
                try {
                  await AuthService.instance.signOut();
                  // No need to manually navigate.
                  // AuthGate will detect the state change and show the LandingPage.
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to sign out. Please try again.'),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
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
    final firstName = displayName.split(' ')[0];
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              fontSize: 30,
                            ),
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
                                color: JewelVaultColors.tagGarment,
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
                                color: JewelVaultColors.tagJewelry,
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
                            color: JewelVaultColors.tagGarment,
                            onTap: onNavigateToCloset,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Jewelry',
                            value: '$jewelryCount',
                            icon: Icons.diamond_outlined,
                            color: JewelVaultColors.tagJewelry,
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
          Text('By Season', style: JewelVaultTypography.headingSmall),
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
        color: JewelVaultColors.primaryEmerald,
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
            style: JewelVaultTypography.labelLarge.copyWith(
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
    this.color = JewelVaultColors.surface,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
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
              color: color == JewelVaultColors.surface
                  ? JewelVaultColors.background
                  : color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: JewelVaultColors.primaryEmerald),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: JewelVaultTypography.display.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: JewelVaultTypography.bodyMedium),
        ],
      ),
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
      color: JewelVaultColors.surface,
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
            Text('Recently Added', style: JewelVaultTypography.headingSmall),
            GestureDetector(
              onTap: onViewAll,
              child: Text(
                'View All',
                style: JewelVaultTypography.labelSmall.copyWith(
                  color: JewelVaultColors.primaryEmerald,
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
                        style: JewelVaultTypography.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.brand,
                        style: JewelVaultTypography.bodyMedium.copyWith(
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
      color: JewelVaultColors.surface,
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
          child: Icon(icon, size: 20, color: JewelVaultColors.primaryEmerald),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: JewelVaultTypography.labelSmall.copyWith(
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: JewelVaultTypography.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                sub,
                style: JewelVaultTypography.bodyMedium.copyWith(fontSize: 11),
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
              color: JewelVaultColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: JewelVaultColors.border),
              boxShadow: JewelVaultEffects.card,
            ),
            child: Column(
              children: [
                Text(_seasonEmoji(s), style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                Text('$count', style: JewelVaultTypography.headingSmall),
                Text(
                  s,
                  style: JewelVaultTypography.bodyMedium.copyWith(fontSize: 11),
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
                    Text(
                      'My Vault Closet',
                      style: JewelVaultTypography.headingLarge,
                    ),
                    Text(
                      '${filtered.length} of ${widget.items.length} pieces',
                      style: JewelVaultTypography.bodyMedium,
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
                  color: JewelVaultColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: JewelVaultColors.border),
                ),
                child: DropdownButton<String>(
                  value: _sortBy,
                  isDense: true,
                  underline: const SizedBox(),
                  style: JewelVaultTypography.labelLarge,
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
              hintStyle: JewelVaultTypography.bodyMedium,
              prefixIcon: const Icon(
                Icons.search,
                color: JewelVaultColors.mutedText,
                size: 20,
              ),
              filled: true,
              fillColor: JewelVaultColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: JewelVaultColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: JewelVaultColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: JewelVaultColors.primaryEmerald,
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
                        color: JewelVaultColors.border,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No items found',
                        style: JewelVaultTypography.headingSmall.copyWith(
                          color: JewelVaultColors.mutedText,
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
      style: JewelVaultTypography.labelSmall.copyWith(
        fontSize: 9,
        color: JewelVaultColors.primaryEmerald,
        letterSpacing: 0.5,
      ),
    ),
  );
}

Color _categoryColor(String cat) {
  switch (cat) {
    case 'Jewelry':
      return JewelVaultColors.tagJewelry;
    case 'Bag':
      return JewelVaultColors.tagBag;
    case 'Accessory':
      return JewelVaultColors.tagAccessory;
    default:
      return JewelVaultColors.tagGarment;
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
                                      Text(
                                        item.category,
                                        style: JewelVaultTypography.labelLarge
                                            .copyWith(fontSize: 12),
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
  List<Map<String, dynamic>> _looks = [];
  bool _isLoadingLooks = true;

  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  Uint8List? _previewBytes;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLooks();
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
      // upload flow with an empty My Looks section.
      if (!mounted) return;
      setState(() => _isLoadingLooks = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedImage = file;
        _previewBytes = bytes;
        _error = null;
      });
    } catch (e) {
      setState(
        () => _error = "Couldn't open the camera/gallery. Please try again.",
      );
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

  // Discards the picked photo and returns to the empty upload state.
  void _unsend() {
    setState(() {
      _pickedImage = null;
      _previewBytes = null;
      _error = null;
    });
  }

  Future<void> _send() async {
    if (_pickedImage == null || _isSending) return;
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      final outfit = await ApiService.createOutfitFromPhoto(_pickedImage!);
      if (!mounted) return;
      setState(() {
        _looks = [outfit, ..._looks];
        _pickedImage = null;
        _previewBytes = null;
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Outfit sent to your lookbook.'),
          backgroundColor: JewelVaultColors.primaryEmerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _error =
            "Couldn't send that outfit — check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outfit Lookbook', style: JewelVaultTypography.headingLarge),
            Text(
              'Snap a look you\u2019ve put together and send it to your lookbook.',
              style: JewelVaultTypography.bodyMedium,
            ),
            const SizedBox(height: 28),

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
              Text('My Looks', style: JewelVaultTypography.headingSmall),
              const SizedBox(height: 16),
              _LooksGrid(looks: _looks, items: widget.items),
              const SizedBox(height: 32),
            ],

            Text('Add New Outfit', style: JewelVaultTypography.headingSmall),
            const SizedBox(height: 16),

            // Upload / preview area
            GestureDetector(
              onTap: _pickedImage == null ? _showSourcePicker : null,
              child: Container(
                width: double.infinity,
                height: 320,
                decoration: BoxDecoration(
                  color: JewelVaultColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: JewelVaultColors.border),
                  boxShadow: JewelVaultEffects.card,
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
                            'Tap to take a photo or choose one from your device',
                            style: JewelVaultTypography.bodyMedium.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : Image.memory(
                        _previewBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
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
                  ],
                ),
              ),
            ],

            // Send / Unsend — only shown once a photo has been picked
            if (_previewBytes != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSending ? null : _unsend,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Unsend'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: JewelVaultColors.secondaryText,
                        side: const BorderSide(color: JewelVaultColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: JewelVaultTypography.labelLarge,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _send,
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_isSending ? 'Sending…' : 'Send'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JewelVaultColors.primaryEmerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: JewelVaultTypography.labelLarge,
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Grid of previously saved looks. Each look is either a photo the wearer
// uploaded directly (has an imageUrl) or, for any legacy/composed looks,
// a set of closet item thumbnails resolved from itemIds.
class _LooksGrid extends StatelessWidget {
  final List<Map<String, dynamic>> looks;
  final List<ClosetItem> items;
  const _LooksGrid({required this.looks, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth > 700;
        final cards = looks.map((look) {
          final photoUrl = look['imageUrl'] as String?;
          if (photoUrl != null && photoUrl.isNotEmpty) {
            return _PhotoLookCard(imageUrl: photoUrl);
          }
          final ids = (look['itemIds'] as List?)?.cast<String>() ?? const [];
          final lookItems = ids
              .map((id) => items.where((e) => e.id == id))
              .where((matches) => matches.isNotEmpty)
              .map((matches) => matches.first)
              .toList();
          return _LookCard(items: lookItems);
        }).toList();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 2 : 1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 190,
          ),
          itemCount: cards.length,
          itemBuilder: (ctx, i) => cards[i],
        );
      },
    );
  }
}

// Same data-URI vs. real-URL handling as _itemImage — the outfit-photo
// upload route stores the image the same way closet items do.
Widget _photoLookImage(String url) {
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

// A saved outfit uploaded as a single photo, rather than composed from
// catalogued closet items.
class _PhotoLookCard extends StatelessWidget {
  final String imageUrl;
  const _PhotoLookCard({required this.imageUrl});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: JewelVaultColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: JewelVaultColors.border),
      boxShadow: JewelVaultEffects.card,
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      fit: StackFit.expand,
      children: [
        _photoLookImage(imageUrl),
        Positioned(
          left: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_camera_outlined,
                  size: 11,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'Uploaded look',
                  style: JewelVaultTypography.labelSmall.copyWith(
                    fontSize: 9,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _LookCard extends StatelessWidget {
  final List<ClosetItem> items;
  const _LookCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final avgMatch = items.isEmpty
        ? 0.0
        : items.map((e) => e.matchScore).reduce((a, b) => a + b) / items.length;
    final totalWorn = items.fold(0, (sum, e) => sum + e.wornCount);
    final categories = items.map((e) => e.category).toSet().toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JewelVaultColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JewelVaultColors.border),
        boxShadow: JewelVaultEffects.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              children: items.take(4).map((item) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: _categoryColor(item.category),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _itemImage(item, iconSize: 22),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: JewelVaultColors.borderLight),
          const SizedBox(height: 8),
          // Stats footer: piece count, category mix, worn total, avg match
          Row(
            children: [
              _MiniStat(
                icon: Icons.checkroom_outlined,
                value: '${items.length}',
                caption: 'PIECES',
              ),
              const SizedBox(width: 14),
              _MiniStat(
                icon: Icons.repeat,
                value: '$totalWorn',
                caption: 'WORN',
              ),
              const SizedBox(width: 4),
              Row(children: categories.map(_CategoryDot.new).toList()),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${avgMatch.toInt()}% match',
                    style: JewelVaultTypography.labelLarge.copyWith(
                      fontSize: 11,
                      color: avgMatch >= 90
                          ? JewelVaultColors.primaryEmerald
                          : JewelVaultColors.accentGold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _MatchMeter(score: avgMatch, width: 46),
                ],
              ),
            ],
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
          ? JewelVaultColors.primaryEmerald.withOpacity(0.1)
          : JewelVaultColors.accentGoldLight,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '${score.toInt()}% match',
      style: JewelVaultTypography.labelSmall.copyWith(
        color: score >= 90
            ? JewelVaultColors.primaryEmerald
            : JewelVaultColors.accentGold,
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
            Text('Catalog New Piece', style: JewelVaultTypography.headingLarge),
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
