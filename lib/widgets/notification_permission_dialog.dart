import 'package:flutter/material.dart';
import 'package:to_do_app/services/notification_service.dart';

/// Play Store–aligned rationale for exact alarms and notification permissions.
Future<void> showNotificationPermissionRationale(BuildContext context) async {
  if (NotificationService.hasShownPermissionRationale) return;

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Task reminders'),
      content: const Text(
        'Lapis schedules local reminders for your tasks. On Android, this may '
        'require notification and exact alarm permissions so reminders fire on time, '
        'even when the app is closed.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  NotificationService.markPermissionRationaleShown();
}
