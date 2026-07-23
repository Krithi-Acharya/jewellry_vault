import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/jv_app_shell.dart';
import '../../../core/widgets/jv_card.dart';
import '../../../core/widgets/jv_button.dart';
import '../../../core/widgets/jv_empty_state.dart';
import '../services/admin_service.dart';

enum _AdminTab { stats, users, items }

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  _AdminTab _tab = _AdminTab.stats;

  @override
  Widget build(BuildContext context) {
    return JVAppShell(
      title: 'Admin',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _TabSelector(
              selected: _tab,
              onSelected: (t) => setState(() => _tab = t),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: switch (_tab) {
              _AdminTab.stats => const _StatsView(),
              _AdminTab.users => const _UsersView(),
              _AdminTab.items => const _ItemsView(),
            },
          ),
        ],
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  final _AdminTab selected;
  final ValueChanged<_AdminTab> onSelected;

  const _TabSelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const labels = {
      _AdminTab.stats: 'Statistics',
      _AdminTab.users: 'Users',
      _AdminTab.items: 'Items',
    };

    return Row(
      children: _AdminTab.values.map((tab) {
        final isSelected = tab == selected;
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: GestureDetector(
            onTap: () => onSelected(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryEmerald : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(
                  color: isSelected ? AppColors.primaryEmerald : AppColors.border,
                ),
              ),
              child: Text(
                labels[tab]!,
                style: AppTypography.labelLarge.copyWith(
                  color: isSelected ? Colors.white : AppColors.secondaryText,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Shared load/error/retry scaffolding so each tab doesn't repeat it.
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

  void _refresh() {
    setState(() => _future = widget.load());
  }

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
                  Text('Could not load this data.', style: AppTypography.bodyMedium),
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

// ── Statistics ───────────────────────────────────────────────

class _StatsView extends StatelessWidget {
  const _StatsView();

  @override
  Widget build(BuildContext context) {
    return _AsyncSection<Map<String, dynamic>>(
      load: AdminService.instance.fetchStats,
      builder: (context, stats, refresh) {
        final categories = List<Map<String, dynamic>>.from(stats['itemsByCategory'] ?? []);

        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _StatTile(label: 'Total Users', value: '${stats['totalUsers'] ?? 0}'),
                  _StatTile(label: 'New Users (7d)', value: '${stats['newUsersLast7Days'] ?? 0}'),
                  _StatTile(label: 'Total Items', value: '${stats['totalItems'] ?? 0}'),
                  _StatTile(label: 'Active Items', value: '${stats['activeItems'] ?? 0}'),
                  _StatTile(label: 'Processing', value: '${stats['processingItems'] ?? 0}'),
                  _StatTile(label: 'Missing AI Tags', value: '${stats['itemsMissingAiTags'] ?? 0}'),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Items by Category', style: AppTypography.headingSmall),
              const SizedBox(height: AppSpacing.md),
              if (categories.isEmpty)
                Text('No items yet.', style: AppTypography.bodyMedium)
              else
                JVCard(
                  child: Column(
                    children: [
                      for (final row in categories)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${row['category']}', style: AppTypography.bodyMedium),
                              Text('${row['count']}', style: AppTypography.labelLarge),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: JVCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTypography.headingLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }
}

// ── Users ────────────────────────────────────────────────────

class _UsersView extends StatelessWidget {
  const _UsersView();

  Future<void> _toggleRole(BuildContext context, Map<String, dynamic> user, VoidCallback refresh) async {
    final bool makingAdmin = user['role'] != 'admin';
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(makingAdmin ? 'Grant admin access?' : 'Revoke admin access?', style: AppTypography.headingSmall),
        content: Text(
          '${user['email']} will ${makingAdmin ? 'gain' : 'lose'} access to the admin dashboard.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryEmerald),
            child: Text('Confirm', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await AdminService.instance.updateUserRole(user['id'] as int, makingAdmin ? 'admin' : 'user');
      refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update role: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AsyncSection<List<Map<String, dynamic>>>(
      load: AdminService.instance.fetchUsers,
      builder: (context, users, refresh) {
        if (users.isEmpty) {
          return const JVEmptyState(title: 'No users yet', message: 'Users will appear here once they sign up.');
        }

        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final user = users[index];
              final bool isAdmin = user['role'] == 'admin';

              return JVCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (user['displayName'] as String?)?.isNotEmpty == true
                                ? user['displayName'] as String
                                : (user['email'] ?? 'Unknown') as String,
                            style: AppTypography.labelLarge,
                          ),
                          const SizedBox(height: 2),
                          Text('${user['email']}', style: AppTypography.bodySmall),
                          const SizedBox(height: AppSpacing.xs),
                          Text('${user['itemCount']} item(s)', style: AppTypography.labelSmall),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAdmin ? AppColors.accentGoldLight : AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        isAdmin ? 'Admin' : 'User',
                        style: AppTypography.labelSmall.copyWith(
                          color: isAdmin ? AppColors.accentGold : AppColors.mutedText,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    JVButton(
                      text: isAdmin ? 'Revoke' : 'Make Admin',
                      variant: JVButtonVariant.outlined,
                      isFullWidth: false,
                      onPressed: () => _toggleRole(context, user, refresh),
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

// ── Items ────────────────────────────────────────────────────

class _ItemsView extends StatelessWidget {
  const _ItemsView();

  Future<void> _delete(BuildContext context, Map<String, dynamic> item, VoidCallback refresh) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove this item?', style: AppTypography.headingSmall),
        content: Text(
          '"${item['display_title']}" owned by ${item['ownerEmail']} will be removed. This cannot be undone.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Remove', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await AdminService.instance.deleteItem(item['id'] as int);
      refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AsyncSection<List<Map<String, dynamic>>>(
      load: AdminService.instance.fetchItems,
      builder: (context, items, refresh) {
        if (items.isEmpty) {
          return const JVEmptyState(title: 'No items yet', message: 'Uploaded items will appear here.');
        }

        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = items[index];

              return JVCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item['display_title'] ?? 'Unknown item'}', style: AppTypography.labelLarge),
                          const SizedBox(height: 2),
                          Text('${item['display_subtitle'] ?? ''}', style: AppTypography.bodySmall),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${item['status_label'] ?? item['status']} • owned by ${item['ownerEmail']}',
                            style: AppTypography.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      tooltip: 'Remove item',
                      onPressed: () => _delete(context, item, refresh),
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
