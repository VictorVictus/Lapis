import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';
import 'package:to_do_app/models/subclasses/label.dart';
import 'package:to_do_app/models/subclasses/section.dart';
import 'package:to_do_app/models/subclasses/group.dart';
import 'package:to_do_app/services/voice_task_parser.dart';

final defaultCategories = [
  TaskCategory(id: 'cat_work', name: 'Work', color: 0xFF1E88E5),
  TaskCategory(id: 'cat_personal', name: 'Personal', color: 0xFF43A047),
];

final defaultLabels = [
  Label(id: 'lbl_urgent', name: 'Urgent', color: 0xFFFF0000, userId: 'u1'),
  Label(id: 'lbl_work', name: 'Work', color: 0xFF0000FF, userId: 'u1'),
];

final defaultSections = [
  Section(id: 'sec_backlog', name: 'Backlog', order: 0, userId: 'u1'),
];

final defaultGroups = [
  Group(id: 'grp_family', name: 'Family', createdBy: 'u1', createdAt: DateTime.now(),
      description: '', inviteCode: 'ABC', memberCount: 2),
];

void main() {
  test('simple title only', () {
    final results = parseVoiceCommand('buy milk',
        categories: defaultCategories, labels: [], sections: [], groups: []);
    expect(results.length, 1);
    expect(results[0].title, 'buy milk');
    expect(results[0].priority, TaskPriority.none);
    expect(results[0].scheduledAt, isNull);
  });

  test('compound: meeting at 9am tomorrow and submittal for work by 11pm today', () {
    final now = DateTime(2026, 6, 20, 10, 0);
    final results = parseVoiceCommand(
      'add a meeting at 9am tomorrow and a submittal for work by 11pm today tag urgent',
      categories: defaultCategories,
      labels: defaultLabels,
      sections: defaultSections,
      groups: defaultGroups,
      now: now,
    );
    expect(results.length, 2, reason: 'should split into 2 tasks');

    expect(results[0].title, 'meeting');
    expect(results[0].scheduledAt, DateTime(2026, 6, 21, 9, 0));
    expect(results[0].deadline, isNull);
    expect(results[0].category, isNull);

    expect(results[1].title, 'submittal');
    expect(results[1].scheduledAt, isNull);
    expect(results[1].deadline, DateTime(2026, 6, 20, 23, 0));
    expect(results[1].category?.name, 'Work');
    expect(results[1].priority, TaskPriority.high);
    expect(results[1].labels.map((l) => l.name), contains('Urgent'));
  });

  test('priority aliases: urgent, asap, critical', () {
    for (final word in ['urgent', 'asap', 'critical', 'important']) {
      final results = parseVoiceCommand('$word task',
          categories: defaultCategories, labels: [], sections: [], groups: []);
      expect(results[0].priority, TaskPriority.high, reason: '$word should map to high');
    }
    for (final word in ['whenever', 'no rush', 'not urgent']) {
      final results = parseVoiceCommand('do it $word',
          categories: defaultCategories, labels: [], sections: [], groups: []);
      expect(results[0].priority, TaskPriority.low, reason: '$word should map to low');
    }
  });

  test('recurrence patterns', () {
    for (final (phrase, expectedFreq) in [
      ('every day', 'daily'),
      ('daily', 'daily'),
      ('weekly', 'weekly'),
      ('monthly', 'monthly'),
      ('every 2 days', 'daily'),
    ]) {
      final results = parseVoiceCommand('task $phrase',
          categories: defaultCategories, labels: [], sections: [], groups: []);
      expect(results[0].recurrentConfig, isNotNull, reason: '$phrase should produce recurrent');
      expect(results[0].recurrentConfig!.frequency.name, expectedFreq,
          reason: '$phrase should be $expectedFreq');
    }
  });

  test('deadline: by friday', () {
    final now = DateTime(2026, 6, 20, 10, 0); // saturday
    final results = parseVoiceCommand('submittal by next monday',
        categories: defaultCategories, labels: [], sections: [], groups: [], now: now);
    expect(results[0].deadline, DateTime(2026, 6, 29, 23, 59));
  });

  test('pinned', () {
    final results = parseVoiceCommand('pin it task',
        categories: defaultCategories, labels: [], sections: [], groups: []);
    expect(results[0].pinned, isTrue);
    expect(results[0].title, 'task');
  });

  test('notes extraction', () {
    final results = parseVoiceCommand('task note: buy organic',
        categories: defaultCategories, labels: [], sections: [], groups: []);
    expect(results[0].title, 'task');
    expect(results[0].notes, 'buy organic');
  });

  test('fuzzy category match by prefix', () {
    final results = parseVoiceCommand('task for personal',
        categories: [
          TaskCategory(id: 'c1', name: 'Personal Development', color: 0xFF000000),
        ],
        labels: [], sections: [], groups: []);
    expect(results[0].category?.name, 'Personal Development');
  });

  test('empty title falls back to original', () {
    final results = parseVoiceCommand('add a',
        categories: defaultCategories, labels: [], sections: [], groups: []);
    expect(results[0].title, 'add a');
  });
}
