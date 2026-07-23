import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/jv_app_shell.dart';
import '../../../core/widgets/jv_card.dart';
import '../../../core/widgets/jv_button.dart';
import '../../../core/widgets/jv_empty_state.dart';
import '../services/admin_service.dart';
import '../widgets/admin_bar_chart.dart';

// ── Tab enum ─────────────────────────────────────────────────────────────────

enum _AdminTab { stats, users, items, queue }

const _tabLabels = {
  _AdminTab.stats: 'Statistics',
  _AdminTab.users: 'Users',
  _AdminTab.items: 'Items',
  _AdminTab.queue: 'AI Queue',
};

const _tabIcons = {
  _AdminTab.stats: Icons.bar_chart_rounded,
  _AdminTab.users: Icons.people_alt_outlined,
  _AdminTab.items: Icons.diamond_outlined,
  _AdminTab.queue: Icons.loop_rounded,
};

// ── Root screen ───────────────────────────────────────────────────────────────

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  _AdminTab _tab = _AdminTab.stats;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 640;

    if (isWide) {
      // ── Wide layout: NavigationRail + content ────────────────────────────
      return JVAppShell(
        title: 'Admin',
        child: Row(
          children: [
            _AdminRail(
              selected: _tab,
              onSelected: (t) => setState(() => _tab = t),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
            Expanded(child: _tabBody(_tab)),
          ],
        ),
      );
    }

    // ── Narrow layout: pill tab bar on top ───────────────────────────────
    return JVAppShell(
      title: 'Admin',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminPillBar(
            selected: _tab,
            onSelected: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _tabBody(_tab)),
        ],
      ),
    );
  }

  Widget _tabBody(_AdminTab tab) => switch (tab) {
        _AdminTab.stats => const _StatsView(),
        _AdminTab.users => const _UsersView(),
        _AdminTab.items => const _ItemsView(),
        _AdminTab.queue => const _QueueView(),
      };
}

// ── Navigation Rail (wide) ────────────────────────────────────────────────────

class _AdminRail extends StatelessWidget {
  final _AdminTab selected;
  final ValueChanged<_AdminTab> onSelected;

  const _AdminRail({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      backgroundColor: AppColors.surface,
      selectedIndex: _AdminTab.values.indexOf(selected),
      onDestinationSelected: (i) => onSelected(_AdminTab.values[i]),
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: const IconThemeData(color: AppColors.primaryEmerald),
      selectedLabelTextStyle: AppTypography.labelLarge.copyWith(
        color: AppColors.primaryEmerald,
        fontSize: 12,
      ),
      unselectedIconTheme: const IconThemeData(color: AppColors.mutedText),
      unselectedLabelTextStyle: AppTypography.labelSmall.copyWith(fontSize: 12),
      destinations: _AdminTab.values.map((tab) {
        return NavigationRailDestination(
          icon: Icon(_tabIcons[tab]),
          selectedIcon: Icon(_tabIcons[tab]),
          label: Text(_tabLabels[tab]!),
        );
      }).toList(),
    );
  }
}

// ── Pill Tab Bar (narrow) ────────────────────────────────────────────────────

class _AdminPillBar extends StatelessWidget {
  final _AdminTab selected;
  final ValueChanged<_AdminTab> onSelected;

  const _AdminPillBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: _AdminTab.values.map((tab) {
          final isSelected = tab == selected;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => onSelected(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryEmerald : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryEmerald : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tabIcons[tab],
                      size: 14,
                      color: isSelected ? Colors.white : AppColors.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _tabLabels[tab]!,
                      style: AppTypography.labelLarge.copyWith(
                        color: isSelected ? Colors.white : AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Shared async scaffolding ─────────────────────────────────────────────────

class _AsyncSection<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback refresh) builder;

  const _AsyncSection({required this.load, required this.builder});

  @override
  State<_AsyncSection<T>> createState() => _AsyncSectionState<T>();
}

class _AsyncSectionState<T> extends State<_AsyncSection<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _refresh() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryEmerald),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.mutedText),
                  const SizedBox(height: AppSpacing.md),
                  Text('Could not load data.', style: AppTypography.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text('${snapshot.error}', style: AppTypography.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  JVButton(text: 'Retry', isFullWidth: false, onPressed: _refresh),
                ],
              ),
            ),
          );
        }
        return widget.builder(context, snapshot.data as T, _refresh);
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATS TAB
// ══════════════════════════════════════════════════════════════════════════════

class _StatsView extends StatelessWidget {
  const _StatsView();

  @override
  Widget build(BuildContext context) {
    return _AsyncSection<Map<String, dynamic>>(
      load: AdminService.instance.fetchStats,
      builder: (context, stats, refresh) {
        final categories =
            List<Map<String, dynamic>>.from(stats['itemsByCategory'] ?? []);
        final totalItems = (stats['totalItems'] as int?) ?? 0;
        final activeItems = (stats['activeItems'] as int?) ?? 0;
        final processingItems = (stats['processingItems'] as int?) ?? 0;
        final missingAi = (stats['itemsMissingAiTags'] as int?) ?? 0;
        final healthPct = totalItems > 0 ? activeItems / totalItems : 0.0;

        return RefreshIndicator(
          onRefresh: () async => refresh(),
          color: AppColors.primaryEmerald,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // ── Metric grid ──────────────────────────────────────────────
              _MetricGrid(stats: stats),
              const SizedBox(height: AppSpacing.lg),

              // ── Platform health bar ──────────────────────────────────────
              JVCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Platform Health', style: AppTypography.headingSmall),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        _HealthBadge(
                          label: '$processingItems in queue',
                          color: AppColors.warning,
                          icon: Icons.loop_rounded,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _HealthBadge(
                          label: '$missingAi missing AI tags',
                          color: AppColors.error,
                          icon: Icons.warning_amber_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: healthPct,
                              minHeight: 8,
                              backgroundColor: AppColors.borderLight,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primaryEmerald,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${(healthPct * 100).toStringAsFixed(0)}% active',
                          style: AppTypography.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Category bar chart ────────────────────────────────────────
              if (categories.isNotEmpty) ...[
                Text('Items by Category', style: AppTypography.headingSmall),
                const SizedBox(height: AppSpacing.md),
                JVCard(
                  child: AdminBarChart(data: categories),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── Recent activity feed ─────────────────────────────────────
              Text('Recent Activity', style: AppTypography.headingSmall),
              const SizedBox(height: AppSpacing.md),
              _ActivityFeed(),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        );
      },
    );
  }
}

// ── Metric grid ───────────────────────────────────────────────────────────────

class _MetricGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _MetricGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricDef(
        label: 'Total Users',
        value: '${stats['totalUsers'] ?? 0}',
        icon: Icons.people_alt_outlined,
        accent: AppColors.info,
      ),
      _MetricDef(
        label: 'New (7d)',
        value: '${stats['newUsersLast7Days'] ?? 0}',
        icon: Icons.person_add_alt_1_outlined,
        accent: AppColors.primaryEmerald,
      ),
      _MetricDef(
        label: 'Total Items',
        value: '${stats['totalItems'] ?? 0}',
        icon: Icons.diamond_outlined,
        accent: AppColors.accentGold,
      ),
      _MetricDef(
        label: 'Active Items',
        value: '${stats['activeItems'] ?? 0}',
        icon: Icons.check_circle_outline,
        accent: AppColors.primaryEmerald,
      ),
      _MetricDef(
        label: 'Processing',
        value: '${stats['processingItems'] ?? 0}',
        icon: Icons.loop_rounded,
        accent: AppColors.warning,
      ),
      _MetricDef(
        label: 'Missing AI Tags',
        value: '${stats['itemsMissingAiTags'] ?? 0}',
        icon: Icons.warning_amber_rounded,
        accent: AppColors.error,
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: metrics.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.5,
        ),
        itemBuilder: (context, i) => _MetricCard(def: metrics[i]),
      );
    });
  }
}

class _MetricDef {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  const _MetricDef({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricDef def;
  const _MetricCard({required this.def});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          // Accent stripe
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: def.accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.card),
                  bottomLeft: Radius.circular(AppRadius.card),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(def.icon, size: 20, color: def.accent),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(def.value, style: AppTypography.headingLarge),
                    Text(def.label, style: AppTypography.labelSmall),
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

// ── Health badge ──────────────────────────────────────────────────────────────

class _HealthBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _HealthBadge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.labelSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ── Activity feed ────────────────────────────────────────────────────────────

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed();

  String _timeAgo(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AsyncSection<List<Map<String, dynamic>>>(
      load: AdminService.instance.fetchActivity,
      builder: (context, events, refresh) {
        if (events.isEmpty) {
          return Text('No recent activity.', style: AppTypography.bodyMedium);
        }
        return JVCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: events.asMap().entries.map((entry) {
              final i = entry.key;
              final event = entry.value;
              final type = event['type'] as String? ?? '';
              final isLast = i == events.length - 1;

              final icon = type == 'user_joined'
                  ? Icons.person_add_alt_1_outlined
                  : Icons.delete_outline;
              final iconColor =
                  type == 'user_joined' ? AppColors.info : AppColors.error;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 16, color: iconColor),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event['description'] as String? ?? '',
                                style: AppTypography.bodySmall,
                              ),
                              Text(
                                _timeAgo(event['timestamp'] as String?),
                                style: AppTypography.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      color: AppColors.borderLight,
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                    ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// USERS TAB
// ══════════════════════════════════════════════════════════════════════════════

class _UsersView extends StatefulWidget {
  const _UsersView();

  @override
  State<_UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<_UsersView> {
  final _searchCtrl = TextEditingController();
  String _roleFilter = 'all'; // all | admin | user
  int _page = 1;
  int _totalPages = 1;
  List<Map<String, dynamic>> _allUsers = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _page = 1;
        _allUsers = [];
      });
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await AdminService.instance.fetchUsers(page: _page);
      setState(() {
        _allUsers = [..._allUsers, ...result.users];
        _totalPages = result.totalPages;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _searchCtrl.text.toLowerCase();
    return _allUsers.where((u) {
      final name = (u['displayName'] as String? ?? '').toLowerCase();
      final email = (u['email'] as String? ?? '').toLowerCase();
      final role = (u['role'] as String? ?? '');
      final matchesSearch = query.isEmpty || name.contains(query) || email.contains(query);
      final matchesRole = _roleFilter == 'all' || role == _roleFilter;
      return matchesSearch && matchesRole;
    }).toList();
  }

  Future<void> _toggleRole(Map<String, dynamic> user) async {
    final makingAdmin = user['role'] != 'admin';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          makingAdmin ? 'Grant admin access?' : 'Revoke admin access?',
          style: AppTypography.headingSmall,
        ),
        content: Text(
          '${user['email']} will ${makingAdmin ? 'gain' : 'lose'} admin access.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryEmerald),
            child: Text('Confirm', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AdminService.instance.updateUserRole(
        user['id'] as int,
        makingAdmin ? 'admin' : 'user',
      );
      _load(reset: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update role: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      children: [
        // ── Search + filter ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md,
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by name or email…',
                  hintStyle: AppTypography.bodyMedium,
                  prefixIcon: const Icon(Icons.search, color: AppColors.mutedText),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    borderSide: const BorderSide(color: AppColors.primaryEmerald, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: ['all', 'admin', 'user'].map((role) {
                  final sel = _roleFilter == role;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(
                        role == 'all' ? 'All' : role[0].toUpperCase() + role.substring(1),
                        style: AppTypography.labelSmall.copyWith(
                          color: sel ? Colors.white : AppColors.secondaryText,
                        ),
                      ),
                      selected: sel,
                      selectedColor: AppColors.primaryEmerald,
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: sel ? AppColors.primaryEmerald : AppColors.border,
                      ),
                      onSelected: (_) => setState(() => _roleFilter = role),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // ── List ──────────────────────────────────────────────────────────
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text('Error: $_error', style: AppTypography.bodyMedium),
          )
        else if (filtered.isEmpty && !_loading)
          const Expanded(
            child: JVEmptyState(title: 'No users found', message: 'Try adjusting your search.'),
          )
        else
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notif) {
                if (!_loading &&
                    _page < _totalPages &&
                    notif.metrics.pixels >= notif.metrics.maxScrollExtent - 200) {
                  _page++;
                  _load();
                }
                return false;
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl,
                ),
                itemCount: filtered.length + (_loading ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  if (i == filtered.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: CircularProgressIndicator(
                          color: AppColors.primaryEmerald,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  return _UserCard(user: filtered[i], onToggleRole: () => _toggleRole(filtered[i]));
                },
              ),
            ),
          ),
      ],
    );
  }
}

// ── User card ─────────────────────────────────────────────────────────────────

class _UserCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onToggleRole;

  const _UserCard({required this.user, required this.onToggleRole});

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _expanded = false;

  String _initials(Map<String, dynamic> u) {
    final name = (u['displayName'] as String?)?.trim() ?? '';
    final email = (u['email'] as String?) ?? '';
    if (name.isNotEmpty) {
      final parts = name.split(' ');
      return parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : name[0].toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isAdmin = user['role'] == 'admin';

    return JVCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    isAdmin ? AppColors.accentGoldLight : AppColors.borderLight,
                child: Text(
                  _initials(user),
                  style: AppTypography.labelLarge.copyWith(
                    color: isAdmin ? AppColors.accentGold : AppColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Name + email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user['displayName'] as String?)?.isNotEmpty == true
                          ? user['displayName'] as String
                          : (user['email'] ?? 'Unknown') as String,
                      style: AppTypography.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${user['email']}',
                      style: AppTypography.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: isAdmin ? AppColors.accentGoldLight : AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: isAdmin ? AppColors.accentGold : AppColors.border,
                  ),
                ),
                child: Text(
                  isAdmin ? 'Admin' : 'User',
                  style: AppTypography.labelSmall.copyWith(
                    color: isAdmin ? AppColors.accentGold : AppColors.mutedText,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: AppColors.mutedText,
                size: 18,
              ),
            ],
          ),

          // ── Expanded detail ──────────────────────────────────────────────
          if (_expanded) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _Detail(icon: Icons.diamond_outlined, label: '${user['itemCount']} items'),
                const SizedBox(width: AppSpacing.lg),
                _Detail(
                  icon: Icons.calendar_today_outlined,
                  label: 'Joined ${_formatDate(user['createdAt'] as String?)}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onToggleRole,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isAdmin ? AppColors.error : AppColors.primaryEmerald,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),
                child: Text(
                  isAdmin ? 'Revoke Admin Access' : 'Grant Admin Access',
                  style: AppTypography.labelLarge.copyWith(
                    color: isAdmin ? AppColors.error : AppColors.primaryEmerald,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Detail({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.mutedText),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.labelSmall),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ITEMS TAB
// ══════════════════════════════════════════════════════════════════════════════

class _ItemsView extends StatefulWidget {
  const _ItemsView();

  @override
  State<_ItemsView> createState() => _ItemsViewState();
}

class _ItemsViewState extends State<_ItemsView> {
  String _statusFilter = 'all';
  int _page = 1;
  int _totalPages = 1;
  List<Map<String, dynamic>> _allItems = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) setState(() { _page = 1; _allItems = []; });
    setState(() { _loading = true; _error = null; });
    try {
      final result = await AdminService.instance.fetchItems(page: _page);
      setState(() {
        _allItems = [..._allItems, ...result.items];
        _totalPages = result.totalPages;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_statusFilter == 'all') return _allItems;
    return _allItems.where((item) {
      final status = (item['status'] as String? ?? '').toLowerCase();
      return status == _statusFilter.toLowerCase();
    }).toList();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove this item?', style: AppTypography.headingSmall),
        content: Text(
          '"${item['display_title']}" by ${item['ownerEmail']} will be removed permanently.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Remove', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AdminService.instance.deleteItem(item['id'] as int);
      _load(reset: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final statusOptions = ['all', 'ACTIVE', 'AI_PROCESSING', 'PENDING'];

    return Column(
      children: [
        // ── Status filter chips ────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md,
          ),
          child: Row(
            children: statusOptions.map((s) {
              final sel = _statusFilter == s;
              final chipColor = _statusChipColor(s);
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  label: Text(
                    s == 'all' ? 'All' : s,
                    style: AppTypography.labelSmall.copyWith(
                      color: sel ? Colors.white : AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                  selected: sel,
                  selectedColor: chipColor,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: sel ? chipColor : AppColors.border),
                  onSelected: (_) => setState(() => _statusFilter = s),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            }).toList(),
          ),
        ),

        // ── List ──────────────────────────────────────────────────────────
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text('Error: $_error', style: AppTypography.bodyMedium),
          )
        else if (filtered.isEmpty && !_loading)
          const Expanded(
            child: JVEmptyState(title: 'No items found', message: 'Try a different filter.'),
          )
        else
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notif) {
                if (!_loading &&
                    _page < _totalPages &&
                    notif.metrics.pixels >= notif.metrics.maxScrollExtent - 200) {
                  _page++;
                  _load();
                }
                return false;
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl,
                ),
                itemCount: filtered.length + (_loading ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  if (i == filtered.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: CircularProgressIndicator(
                          color: AppColors.primaryEmerald,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  final item = filtered[i];
                  return Dismissible(
                    key: ValueKey(item['id']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      await _delete(item);
                      return false; // We handle reload ourselves
                    },
                    child: _ItemCard(item: item, onDelete: () => _delete(item)),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Color _statusChipColor(String status) {
    switch (status) {
      case 'ACTIVE': return AppColors.primaryEmerald;
      case 'AI_PROCESSING': return AppColors.warning;
      case 'PENDING': return AppColors.info;
      default: return AppColors.secondaryText;
    }
  }
}

// ── Item card ─────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;
  const _ItemCard({required this.item, required this.onDelete});

  Color _statusColor(String? status) {
    switch (status) {
      case 'ACTIVE': return AppColors.primaryEmerald;
      case 'AI_PROCESSING': return AppColors.warning;
      case 'PENDING': return AppColors.info;
      default: return AppColors.mutedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = item['thumbnail_url'] as String?;

    final status = item['status'] as String?;

    return JVCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: 60,
              height: 60,
              child: thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: AppColors.borderLight),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.borderLight,
                        child: const Icon(Icons.broken_image_outlined,
                            size: 20, color: AppColors.mutedText),
                      ),
                    )
                  : Container(
                      color: AppColors.borderLight,
                      child: const Icon(Icons.diamond_outlined,
                          size: 20, color: AppColors.mutedText),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['display_title'] ?? 'Unknown'}',
                  style: AppTypography.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item['ownerEmail'] ?? ''}',
                  style: AppTypography.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    status ?? 'Unknown',
                    style: AppTypography.labelSmall.copyWith(
                      color: _statusColor(status),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
            tooltip: 'Remove item',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// QUEUE TAB
// ══════════════════════════════════════════════════════════════════════════════

class _QueueView extends StatelessWidget {
  const _QueueView();

  String _elapsed(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return '';
    }
  }

  Future<void> _retry(BuildContext context, Map<String, dynamic> item) async {
    try {
      await AdminService.instance.retryItem(item['id'] as int);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item queued for retry')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not retry: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AsyncSection<List<Map<String, dynamic>>>(
      load: AdminService.instance.fetchQueue,
      builder: (context, items, refresh) {
        if (items.isEmpty) {
          return const JVEmptyState(
            title: 'Queue is clear',
            message: 'No items stuck in AI processing.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => refresh(),
          color: AppColors.primaryEmerald,
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final item = items[i];
              final status = item['status'] as String? ?? '';
              final elapsed = _elapsed(item['createdAt'] as String?);
              final retryCount =
                  (item['latestJob']?['iuj_retry_count'] as int?) ?? 0;
              final lastError =
                  item['latestJob']?['iuj_last_error'] as String?;
              final thumbnailUrl = item['thumbnailUrl'] as String?;

              return JVCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: thumbnailUrl != null
                            ? CachedNetworkImage(
                                imageUrl: thumbnailUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) =>
                                    Container(color: AppColors.borderLight),
                                errorWidget: (_, _, _) => Container(
                                  color: AppColors.borderLight,
                                  child: const Icon(Icons.broken_image_outlined,
                                      size: 16, color: AppColors.mutedText),
                                ),
                              )
                            : Container(
                                color: AppColors.borderLight,
                                child: const Icon(Icons.diamond_outlined,
                                    size: 20, color: AppColors.mutedText),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['displayTitle']}',
                            style: AppTypography.labelLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item['ownerEmail'] ?? ''}',
                            style: AppTypography.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: 6,
                            children: [
                              _QueueBadge(
                                label: status,
                                color: status == 'AI_PROCESSING'
                                    ? AppColors.warning
                                    : AppColors.info,
                              ),
                              _QueueBadge(
                                label: 'in queue $elapsed',
                                color: AppColors.secondaryText,
                              ),
                              if (retryCount > 0)
                                _QueueBadge(
                                  label: '$retryCount retries',
                                  color: AppColors.error,
                                ),
                            ],
                          ),
                          if (lastError != null && lastError.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              lastError,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.error,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Retry button
                    IconButton(
                      icon: const Icon(
                        Icons.replay_rounded,
                        color: AppColors.primaryEmerald,
                      ),
                      tooltip: 'Force retry',
                      onPressed: () => _retry(context, item),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _QueueBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _QueueBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}
