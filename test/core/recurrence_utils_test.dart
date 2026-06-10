import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/recurrent_configuration.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';
import 'package:to_do_app/core/recurrence_utils.dart';

Task _task({
  required DateTime scheduledAt,
  required RecurrentConfig config,
}) {
  return Task(
    id: 'test',
    userId: 'u1',
    title: 'test',
    category: TaskCategory(id: 'c1', name: 'General', color: 0xFF9E9E9E),
    createdAt: DateTime(2026, 1, 1),
    scheduledAt: scheduledAt,
    recurrentConfig: config,
    type: TaskType.recurrent,
  );
}

void main() {
  group('computeNextRecurrence', () {
    group('daily', () {
      test('adds interval days', () {
        final task = _task(
          scheduledAt: DateTime(2026, 6, 10),
          config: RecurrentConfig(frequency: RecurrentFrequency.daily, interval: 1),
        );
        expect(computeNextRecurrence(task), DateTime(2026, 6, 11));
      });

      test('respects custom interval', () {
        final task = _task(
          scheduledAt: DateTime(2026, 6, 10),
          config: RecurrentConfig(frequency: RecurrentFrequency.daily, interval: 3),
        );
        expect(computeNextRecurrence(task), DateTime(2026, 6, 13));
      });
    });

    group('weekly', () {
      test('finds next weekday from Saturday', () {
        final task = _task(
          scheduledAt: DateTime(2026, 6, 6), // Saturday
          config: RecurrentConfig(
            frequency: RecurrentFrequency.weekly,
            weekdays: [1, 3, 5], // Mon, Wed, Fri
          ),
        );
        // Saturday June 6 → next Mon June 8
        expect(computeNextRecurrence(task), DateTime(2026, 6, 8));
      });

      test('finds next weekday from Monday', () {
        final task = _task(
          scheduledAt: DateTime(2026, 6, 1), // Monday
          config: RecurrentConfig(
            frequency: RecurrentFrequency.weekly,
            weekdays: [1, 3, 5], // Mon, Wed, Fri
          ),
        );
        // Monday June 1 → next Wed June 3
        expect(computeNextRecurrence(task), DateTime(2026, 6, 3));
      });

      test('finds next weekday from Sunday', () {
        final task = _task(
          scheduledAt: DateTime(2026, 6, 7), // Sunday
          config: RecurrentConfig(
            frequency: RecurrentFrequency.weekly,
            weekdays: [1, 2, 3, 4, 5], // Mon–Fri
          ),
        );
        // Sunday June 7 → next Mon June 8
        expect(computeNextRecurrence(task), DateTime(2026, 6, 8));
      });

      test('falls back to interval*7 when no weekdays set', () {
        final task = _task(
          scheduledAt: DateTime(2026, 6, 10),
          config: RecurrentConfig(frequency: RecurrentFrequency.weekly, interval: 2),
        );
        expect(computeNextRecurrence(task), DateTime(2026, 6, 24));
      });
    });

    group('monthly', () {
      test('basic monthly adds interval months', () {
        final task = _task(
          scheduledAt: DateTime(2026, 3, 15),
          config: RecurrentConfig(frequency: RecurrentFrequency.monthly, interval: 1),
        );
        expect(computeNextRecurrence(task), DateTime(2026, 4, 15));
      });

      test('clamps day to 28 for Feb from Jan 31', () {
        final task = _task(
          scheduledAt: DateTime(2026, 1, 31),
          config: RecurrentConfig(frequency: RecurrentFrequency.monthly, interval: 1),
        );
        // Jan 31 → Feb 28 (not March 3)
        expect(computeNextRecurrence(task), DateTime(2026, 2, 28));
      });

      test('clamps day to 30 for Apr from Mar 31', () {
        final task = _task(
          scheduledAt: DateTime(2026, 3, 31),
          config: RecurrentConfig(frequency: RecurrentFrequency.monthly, interval: 1),
        );
        // Mar 31 → Apr 30 (not May 1)
        expect(computeNextRecurrence(task), DateTime(2026, 4, 30));
      });

      test('handles year rollover with large interval', () {
        final task = _task(
          scheduledAt: DateTime(2026, 12, 15),
          config: RecurrentConfig(frequency: RecurrentFrequency.monthly, interval: 2),
        );
        // Dec 2026 + 2 months = Feb 2027
        expect(computeNextRecurrence(task), DateTime(2027, 2, 15));
      });

      test('clamps Dec 31 + 1 month to Jan 31', () {
        final task = _task(
          scheduledAt: DateTime(2026, 12, 31),
          config: RecurrentConfig(frequency: RecurrentFrequency.monthly, interval: 1),
        );
        expect(computeNextRecurrence(task), DateTime(2027, 1, 31));
      });
    });

    group('custom', () {
      test('adds custom interval days', () {
        final task = _task(
          scheduledAt: DateTime(2026, 6, 10),
          config: RecurrentConfig(frequency: RecurrentFrequency.custom, interval: 7),
        );
        expect(computeNextRecurrence(task), DateTime(2026, 6, 17));
      });
    });

    test('uses scheduledAt when available', () {
      final task = _task(
        scheduledAt: DateTime(2026, 7, 4),
        config: RecurrentConfig(frequency: RecurrentFrequency.daily),
      );
      expect(computeNextRecurrence(task), DateTime(2026, 7, 5));
    });

    test('falls back to createdAt when scheduledAt is null', () {
      final task = Task(
        id: 'test',
        userId: 'u1',
        title: 'test',
        category: TaskCategory(id: 'c1', name: 'General', color: 0xFF9E9E9E),
        createdAt: DateTime(2026, 8, 1),
        recurrentConfig: RecurrentConfig(frequency: RecurrentFrequency.daily),
        type: TaskType.recurrent,
      );
      expect(computeNextRecurrence(task), DateTime(2026, 8, 2));
    });
  });
}
