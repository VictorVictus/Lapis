import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/services/auth_service.dart';
import 'package:to_do_app/widgets/legal_consent_section.dart';
import 'package:to_do_app/core/legal_config.dart';
import 'package:to_do_app/core/session_cleanup.dart';
import 'package:to_do_app/models/auth_result.dart';
import 'package:to_do_app/providers/theme_provider.dart';
import 'package:to_do_app/providers/accent_color_provider.dart';
import 'package:to_do_app/screens/profile_page.dart';
import 'package:to_do_app/widgets/group_list_screen.dart';
import 'package:intl/intl.dart';

class DashboardHeader extends ConsumerWidget {
  final User displayUser;

  const DashboardHeader({super.key, required this.displayUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        GestureDetector(
          onTap: () {
            unawaited(Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GroupListScreen(),
              ),
            ));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color.fromARGB(60, 243, 243, 243),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.group, color: Colors.white, size: 13),
                const SizedBox(width: 3),
                Text(
                  'My Groups',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            unawaited(Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilePage(user: displayUser),
              ),
            ));
          },
          child: Container(
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
        ),
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
}
