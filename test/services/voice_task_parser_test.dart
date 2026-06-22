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
    expect(results[0].title, 'Buy Milk');
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

    expect(results[0].title, 'Meeting');
    expect(results[0].scheduledAt, DateTime(2026, 6, 21, 9, 0));
    expect(results[0].deadline, isNull);
    expect(results[0].category, isNull);

    expect(results[1].title, 'Submittal');
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
    expect(results[0].title, 'Task');
  });

  test('notes extraction', () {
    final results = parseVoiceCommand('task note: buy organic',
        categories: defaultCategories, labels: [], sections: [], groups: []);
    expect(results[0].title, 'Task');
    expect(results[0].notes, 'buy organic');
  });

  test('fuzzy category match by prefix', () {
    final results = parseVoiceCommand('task for personal',
        categories: [
          TaskCategory(id: 'c1', name: 'Personal Development', color: 0xFF000000),
        ],
        labels: [], sections: [], groups: []);
    expect(results[0].category?.name, 'Personal Development');
    expect(results[0].title, 'Task');
  });

  test('empty title falls back to original', () {
    final results = parseVoiceCommand('add a',
        categories: defaultCategories, labels: [], sections: [], groups: []);
    expect(results[0].title, 'add a');
  });

  group('bug fixes', () {
    test('p1 maps to high priority', () {
      final results = parseVoiceCommand('fix bug p1',
          categories: defaultCategories, labels: [], sections: [], groups: []);
      expect(results[0].priority, TaskPriority.high,
          reason: 'p1 should be highest priority');
      expect(results[0].title, 'Fix Bug');
    });

    test('p2 maps to medium priority', () {
      final results = parseVoiceCommand('fix bug p2',
          categories: defaultCategories, labels: [], sections: [], groups: []);
      expect(results[0].priority, TaskPriority.medium,
          reason: 'p2 should be medium priority');
    });

    test('p3 maps to low priority', () {
      final results = parseVoiceCommand('fix bug p3',
          categories: defaultCategories, labels: [], sections: [], groups: []);
      expect(results[0].priority, TaskPriority.low,
          reason: 'p3 should be lowest priority');
    });

    test('priority + category together', () {
      final now = DateTime(2026, 6, 22, 10, 0);
      final results = parseVoiceCommand('fix bug p1 for Work',
          categories: defaultCategories,
          labels: [],
          sections: [],
          groups: [],
          now: now);
      expect(results[0].priority, TaskPriority.high,
          reason: 'p1 should map to high');
      expect(results[0].category?.name, 'Work',
          reason: 'category should be Work');
      expect(results[0].title, 'Fix Bug',
          reason: 'title should clean up nicely');
    });

    test('deadline by friday sets deadline and cleans title', () {
      final now = DateTime(2026, 6, 22, 10, 0); // Monday
      final results = parseVoiceCommand('submit report by friday',
          categories: defaultCategories,
          labels: [],
          sections: [],
          groups: [],
          now: now);
      expect(results[0].deadline, isNotNull,
          reason: 'should set deadline');
      expect(results[0].deadline!.weekday, 5,
          reason: 'deadline should be friday');
      expect(results[0].title, 'Submit Report',
          reason: 'title should not contain deadline words');
    });

    test('time 930am without colon', () {
      final now = DateTime(2026, 6, 22, 10, 0); // Monday
      final results = parseVoiceCommand('team sync at 930am',
          categories: defaultCategories,
          labels: [],
          sections: [],
          groups: [],
          now: now);
      expect(results[0].scheduledAt, isNotNull,
          reason: 'should parse time');
      expect(results[0].scheduledAt!.hour, 9,
          reason: 'hour should be 9');
      expect(results[0].scheduledAt!.minute, 30,
          reason: 'minute should be 30');
      expect(results[0].title, 'Team Sync',
          reason: 'title should not contain time');
    });

    test('full feature combo', () {
      final now = DateTime(2026, 6, 22, 10, 0); // Monday
      final results = parseVoiceCommand(
        'team sync every weekday at 930am high priority for Work tag urgent due friday pin it note: prepare slides',
        categories: defaultCategories,
        labels: defaultLabels,
        sections: [],
        groups: [],
        now: now,
      );
      expect(results.length, 1);
      expect(results[0].title, 'Team Sync');
      expect(results[0].priority, TaskPriority.high);
      expect(results[0].category?.name, 'Work');
      expect(results[0].recurrentConfig, isNotNull);
      expect(results[0].scheduledAt, isNotNull,
          reason: 'should have scheduled time');
      if (results[0].scheduledAt != null) {
        expect(results[0].scheduledAt!.hour, 9,
            reason: 'scheduled hour should be 9');
        expect(results[0].scheduledAt!.minute, 30,
            reason: 'scheduled minute should be 30');
      }
      expect(results[0].deadline, isNotNull,
          reason: 'should have deadline');
      expect(results[0].notes, 'prepare slides');
      expect(results[0].labels.map((l) => l.name), contains('Urgent'));
      expect(results[0].pinned, isTrue, reason: 'pin it should set pinned');
    });

    test('orphaned tag prefix cleaned when no matching label', () {
      final now = DateTime(2026, 6, 22, 10, 0);
      final results = parseVoiceCommand(
        'team sync at 930am high priority tag urgent note: prepare slides',
        categories: defaultCategories,
        labels: [], // no labels in Firestore
        sections: [],
        groups: [],
        now: now,
      );
      expect(results[0].title, 'Team Sync');
      expect(results[0].priority, TaskPriority.high);
      expect(results[0].scheduledAt?.hour, 9);
      expect(results[0].scheduledAt?.minute, 30);
      expect(results[0].notes, 'prepare slides');
    });

    test('orphaned tag prefix with deadline', () {
      final now = DateTime(2026, 6, 22, 10, 0);
      final results = parseVoiceCommand(
        'fix bug p1 tag urgent due friday',
        categories: defaultCategories,
        labels: [],
        sections: [],
        groups: [],
        now: now,
      );
      expect(results[0].title, 'Fix Bug');
      expect(results[0].priority, TaskPriority.high);
      expect(results[0].deadline, isNotNull);
    });

    test('conflicting priorities highest wins: p1 vs no rush', () {
      final results = parseVoiceCommand('p1 no rush',
          categories: defaultCategories, labels: [], sections: [], groups: []);
      expect(results[0].priority, TaskPriority.high,
          reason: 'p1 (high) should win over no rush (low)');
    });

    test('conflicting priorities highest wins: high vs low', () {
      final results = parseVoiceCommand('high priority but low',
          categories: defaultCategories, labels: [], sections: [], groups: []);
      expect(results[0].priority, TaskPriority.high,
          reason: 'high (3) should win over low (1)');
    });

    test('conflicting priorities highest wins: urgent vs not urgent', () {
      final results = parseVoiceCommand('urgent but not urgent',
          categories: defaultCategories, labels: [], sections: [], groups: []);
      expect(results[0].priority, TaskPriority.high,
          reason: 'urgent (3) should win over not urgent (1)');
    });

    test('conflicting priorities highest wins: medium vs low', () {
      final results = parseVoiceCommand('medium but trivial',
          categories: defaultCategories, labels: [], sections: [], groups: []);
      expect(results[0].priority, TaskPriority.medium,
          reason: 'medium (2) should win over trivial/low (1)');
    });

    test('priority word substring does not match: highland', () {
      final results = parseVoiceCommand('highland camping trip',
          categories: defaultCategories, labels: [], sections: [], groups: []);
      expect(results[0].priority, TaskPriority.none,
          reason: 'highland contains high but word boundary should prevent match');
      expect(results[0].title, 'Highland Camping Trip');
    });
  });
}
