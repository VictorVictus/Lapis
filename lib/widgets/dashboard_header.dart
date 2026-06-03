import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:to_do_app/models/user.dart';
import 'package:to_do_app/screens/schedule_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/sync_provider.dart';
import 'package:to_do_app/services/auth_service.dart';
import 'package:to_do_app/widgets/legal_consent_section.dart';
import 'package:to_do_app/core/legal_config.dart';
import 'package:to_do_app/core/session_cleanup.dart';
import 'package:to_do_app/models/auth_result.dart';
import 'package:to_do_app/providers/theme_provider.dart';
import 'package:to_do_app/providers/accent_color_provider.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';
import 'package:to_do_app/screens/stats_page.dart';
import 'package:to_do_app/screens/archive_page.dart';
import 'package:intl/intl.dart';

class DashboardHeader extends ConsumerWidget {
  final User displayUser;

  const DashboardHeader({super.key, required this.displayUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final showSuccess = ref.watch(showSuccessIndicatorProvider);
    final groupBy = ref.watch(dashboardProvider.select((s) => s.groupBy));
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today',
                style: TextStyle(color: Colors.white, fontSize: 40),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  DateFormat('dd MMM yyyy, EEEE').format(DateTime.now()),
                  style: const TextStyle(
                    color: Color.fromARGB(255, 199, 199, 199),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color.fromARGB(64, 243, 243, 243),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              displayUser.initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 24,
          height: 48,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: _buildSyncIndicatorContent(syncStatus, showSuccess),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            final next = switch (groupBy) {
              GroupBy.none => GroupBy.category,
              GroupBy.category => GroupBy.priority,
              GroupBy.priority => GroupBy.none,
            };
            ref.read(dashboardProvider.notifier).setGroupBy(next);
          },
          onLongPress: () {
            final currentSort = ref.read(dashboardProvider).sortBy;
            final sortOptions = SortBy.values;
            showCupertinoModalPopup(
              context: context,
              builder: (ctx) => CupertinoActionSheet(
                title: const Text('Sort by'),
                actions: [
                  for (final sort in sortOptions)
                    CupertinoActionSheetAction(
                      isDefaultAction: sort == currentSort,
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(dashboardProvider.notifier).setSortBy(sort);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _sortIcon(sort),
                            size: 18,
                            color: sort == currentSort
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(_sortLabel(sort)),
                        ],
                      ),
                    ),
                ],
                cancelButton: CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Icon(
                  groupBy == GroupBy.none ? Icons.view_list_outlined
                      : groupBy == GroupBy.category
                          ? Icons.category_outlined
                          : Icons.flag_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          label: 'Calendar',
          child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SchedulePage(user: displayUser),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.calendar,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(CupertinoIcons.ellipsis, color: Colors.white),
          tooltip: 'Account',
          onPressed: () => _showAccountMenu(context, ref),
        ),
      ],
    );
  }

  Future<void> _showAccountMenu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () => Navigator.pop(context, 'signOut'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete account'),
              subtitle: Text(
                'Permanently removes your ${LegalConfig.appName} account and profile.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.pop(context);
                LegalConsentSection.openUrl(LegalConfig.privacyPolicyUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('Statistics'),
              onTap: () => Navigator.pop(context, 'stats'),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              onTap: () => Navigator.pop(context, 'archive'),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Accent Color'),
              subtitle: Text(
                accentColorNames[presetAccentColors.indexOf(ref.read(accentColorProvider))],
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: () => Navigator.pop(context, 'accent'),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Theme'),
              subtitle: Text(
                ref.read(themeModeProvider) == ThemeMode.dark
                    ? 'Dark'
                    : ref.read(themeModeProvider) == ThemeMode.light
                        ? 'Light'
                        : 'System',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: () => Navigator.pop(context, 'theme'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    if (action == 'signOut') {
      invalidateSessionProviders(ref);
      await ref.read(authServiceProvider).signOut();
      return;
    }

    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This permanently deletes your account and profile data. '
            'Your tasks may remain until removed separately. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      var result = await ref.read(authServiceProvider).deleteAccount();

      if (!context.mounted) return;

      if (result.failureCode == AuthFailureCode.requiresRecentLogin) {
        final password = await _showReauthDialog(context);
        if (password == null || !context.mounted) return;

        final reauthed = await ref.read(authServiceProvider).reauthenticate(password);
        if (!reauthed) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Re-authentication failed. Try signing out and back in.'),
            ),
          );
          return;
        }

        result = await ref.read(authServiceProvider).deleteAccount();
        if (!context.mounted) return;
      }

      if (result.isSuccess) {
        invalidateSessionProviders(ref);
      } else if (!result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(result.message ?? 'Could not delete account.'),
          ),
        );
      }
    }

    if (action == 'stats') {
      unawaited(Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StatsPage(user: displayUser),
        ),
      ));
      return;
    }

    if (action == 'archive') {
      unawaited(Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArchivePage(user: displayUser),
        ),
      ));
      return;
    }

    if (action == 'accent') {
      final current = ref.read(accentColorProvider);
      final idx = presetAccentColors.indexOf(current);
      final picked = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Pick accent color'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(presetAccentColors.length, (i) {
                  final selected = i == idx;
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, i),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: presetAccentColors[i],
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: selected
                            ? [BoxShadow(color: presetAccentColors[i].withValues(alpha: 0.6), blurRadius: 8)]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      );
      if (picked != null) {
        await ref.read(accentColorProvider.notifier).persistAccent(presetAccentColors[picked]);
      }
      return;
    }

    if (action == 'theme') {
      final current = ref.read(themeModeProvider);
      final next = switch (current) {
        ThemeMode.system => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.light,
        ThemeMode.light => ThemeMode.system,
      };
      await ref.read(themeModeProvider.notifier).persistThemeMode(next);
      return;
    }
  }

  Future<String?> _showReauthDialog(BuildContext context) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Password'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password to continue',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  static IconData _sortIcon(SortBy sortBy) => switch (sortBy) {
        SortBy.order => Icons.drag_handle,
        SortBy.deadline => Icons.event,
        SortBy.priority => Icons.flag,
        SortBy.created => Icons.add_circle_outline,
      };

  static String _sortLabel(SortBy sortBy) => switch (sortBy) {
        SortBy.order => 'Manual',
        SortBy.deadline => 'Deadline',
        SortBy.priority => 'Priority',
        SortBy.created => 'Created',
      };

  Widget _buildSyncIndicatorContent(SyncStatus status, bool showSuccess) {
    if (status == SyncStatus.syncing) {
      return const _RotatingSyncIcon();
    }
    if (status == SyncStatus.error) {
      return const Icon(
        CupertinoIcons.exclamationmark_circle,
        color: Colors.redAccent,
        size: 20,
      );
    }
    if (showSuccess) {
      return const Icon(
        CupertinoIcons.check_mark_circled,
        color: Colors.greenAccent,
        size: 20,
      );
    }
    return const SizedBox.shrink();
  }
}

class _RotatingSyncIcon extends StatefulWidget {
  const _RotatingSyncIcon();

  @override
  State<_RotatingSyncIcon> createState() => _RotatingSyncIconState();
}

class _RotatingSyncIconState extends State<_RotatingSyncIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(
        CupertinoIcons.arrow_2_circlepath,
        color: Colors.white70,
        size: 20,
      ),
    );
  }
}
