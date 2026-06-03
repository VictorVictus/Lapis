import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/providers/task_provider.dart';

const _weeklyKey = 'weekly_review_week';

int _weekOfYear(DateTime date) {
  final firstDayOfYear = DateTime(date.year, 1, 1);
  final days = date.difference(firstDayOfYear).inDays;
  return ((days + firstDayOfYear.weekday - 1) / 7).ceil();
}

Future<void> showWeeklyReviewIfNeeded(BuildContext context, WidgetRef ref, String userId) async {
  final now = DateTime.now();
  if (now.weekday != DateTime.sunday) return;

  final prefs = await SharedPreferences.getInstance();
  final currentWeek = now.year * 100 + _weekOfYear(now);
  if (prefs.getInt(_weeklyKey) == currentWeek) return;

  final counts = await ref.read(taskCountsProvider(userId).future);
  final completed = counts[TaskStatus.fulfilled] ?? 0;

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Weekly Review'),
      content: Text(
        'You completed $completed task${completed == 1 ? '' : 's'} this week.\n\n'
        'Keep up the good work!',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Thanks'),
        ),
      ],
    ),
  );

  final savedPrefs = await SharedPreferences.getInstance();
  unawaited(savedPrefs.setInt(_weeklyKey, currentWeek));
}
