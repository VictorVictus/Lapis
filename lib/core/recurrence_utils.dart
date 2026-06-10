import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/recurrent_configuration.dart';

int _dayOfWeekIndex(DateTime d) => d.weekday;

DateTime computeNextRecurrence(Task task) {
  final cfg = task.recurrentConfig!;
  final from = task.scheduledAt ?? task.createdAt;

  switch (cfg.frequency) {
    case RecurrentFrequency.daily:
      return from.add(Duration(days: cfg.interval));
    case RecurrentFrequency.weekly:
      if (cfg.weekdays != null && cfg.weekdays!.isNotEmpty) {
        final weekdays = cfg.weekdays!;
        DateTime candidate = DateTime(from.year, from.month, from.day).add(const Duration(days: 1));
        for (int i = 0; i < 14; i++) {
          if (weekdays.contains(_dayOfWeekIndex(candidate))) {
            return candidate;
          }
          candidate = candidate.add(const Duration(days: 1));
        }
      }
      return from.add(Duration(days: cfg.interval * 7));
    case RecurrentFrequency.monthly:
      final targetMonth = from.month + cfg.interval;
      final year = from.year + (targetMonth - 1) ~/ 12;
      final month = ((targetMonth - 1) % 12) + 1;
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final day = from.day.clamp(1, daysInMonth);
      return DateTime(year, month, day);
    case RecurrentFrequency.custom:
      return from.add(Duration(days: cfg.interval));
  }
}
