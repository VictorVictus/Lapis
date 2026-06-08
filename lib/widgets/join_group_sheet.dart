import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/services/group_service.dart';
import 'package:to_do_app/theme/app_theme.dart';

class JoinGroupSheet extends ConsumerStatefulWidget {
  final String userId;
  final String username;

  const JoinGroupSheet({super.key, required this.userId, required this.username});

  @override
  ConsumerState<JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends ConsumerState<JoinGroupSheet> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = AppTheme.gradientColors(context);

    return Container(
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientColors.primary, gradientColors.secondary],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Join Group',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: _codeController,
              placeholder: 'Enter invite code (e.g. G7K2-M9P3)',
              autofocus: true,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: CupertinoButton.filled(
                child: _loading
                    ? const CupertinoActivityIndicator()
                    : const Text('Join'),
                onPressed: _loading ? null : _joinGroup,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinGroup() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _loading = true);
    try {
      final groupId = await ref.read(groupServiceProvider).joinByCode(
        code,
        widget.userId,
        widget.username,
      );

      setState(() => _loading = false);

      if (!mounted) return;

      if (groupId != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined group successfully!')),
        );
      } else {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Invalid Code'),
            content: const Text('No group found with that invite code.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to join: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    }
  }
}
