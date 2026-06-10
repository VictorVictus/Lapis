import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';

/// Extracts what _titleStyle does in task_list_item.dart for testability.
TextStyle _titleStyle({required Task task, required Color color, required double fontSize}) {
  final isDone = task.status == TaskStatus.fulfilled;
  return TextStyle(
    color: isDone ? color.withValues(alpha: 0.55) : color,
    fontWeight: FontWeight.bold,
    fontSize: fontSize,
    decoration: isDone ? TextDecoration.lineThrough : null,
    decorationColor: color.withValues(alpha: 0.5),
  );
}

final _baseTask = Task(
  id: 't1',
  userId: 'u1',
  title: 'Test task',
  category: TaskCategory(id: 'c1', name: 'General', color: 0xFF9E9E9E),
  createdAt: DateTime(2026, 1, 1),
  status: TaskStatus.undone,
);

final _doneTask = Task(
  id: 't2',
  userId: 'u1',
  title: 'Done task',
  category: TaskCategory(id: 'c1', name: 'General', color: 0xFF9E9E9E),
  createdAt: DateTime(2026, 1, 1),
  status: TaskStatus.fulfilled,
  completedAt: DateTime(2026, 6, 10),
);

void main() {
  group('TaskListItem _titleStyle', () {
    final color = const Color(0xFF9E9E9E);

    test('undone task has no strikethrough', () {
      final style = _titleStyle(task: _baseTask, color: color, fontSize: 16);
      expect(style.decoration, isNull);
      expect(style.color, color);
    });

    test('fulfilled task has strikethrough', () {
      final style = _titleStyle(task: _doneTask, color: color, fontSize: 16);
      expect(style.decoration, TextDecoration.lineThrough);
    });

    test('fulfilled task has reduced opacity', () {
      final style = _titleStyle(task: _doneTask, color: color, fontSize: 16);
      expect(style.color?.alpha, lessThan(255));
    });
  });
}
