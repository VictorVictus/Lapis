import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_app/services/focus_mode_service.dart';

const _prefsKey = 'screen_pinning_dialog_shown';

Future<void> showScreenPinningDialogIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_prefsKey) == true) return;
  if (!context.mounted) return;

  await showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Focus Mode'),
      content: const Text(
        'Focus Mode can lock Lapis to your screen so you can\'t '
        'open other apps until the timer ends.\n\n'
        'To enable this, go to:\n'
        'Settings → Security → Screen pinning\n\n'
        'Toggle it on, then the next time you start a Focus session '
        'the app will pin itself.',
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          child: const Text('Open Settings'),
          onPressed: () async {
            Navigator.pop(ctx);
            await FocusModeService().openSecuritySettings();
          },
        ),
        CupertinoDialogAction(
          child: const Text('Got it'),
          onPressed: () async {
            Navigator.pop(ctx);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_prefsKey, true);
          },
        ),
      ],
    ),
  );
}
