import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/subclasses/sub_task.dart';

void main() {
  group('SubTask Model Tests', () {
    test('should correctly convert to map', () {
      final subTask = SubTask(
        id: 'st1',
        taskId: 'task1',
        userId: 'user1',
        title: 'Subtask 1',
        isDone: true,
        order: 1,
      );

      final map = subTask.toMap();

      expect(map['taskId'], 'task1');
      expect(map['userId'], 'user1');
      expect(map['title'], 'Subtask 1');
      expect(map['isDone'], isTrue);
      expect(map['order'], 1);
    });

    test('should correctly create from map', () {
      final map = <String, dynamic>{
        'taskId': 'task1',
        'userId': 'user1',
        'title': 'Subtask 1',
        'isDone': true,
        'order': 1,
      };

      final subTask = SubTask.fromMap(map, 'st1');

      expect(subTask.id, 'st1');
      expect(subTask.taskId, 'task1');
      expect(subTask.userId, 'user1');
      expect(subTask.title, 'Subtask 1');
      expect(subTask.isDone, isTrue);
      expect(subTask.order, 1);
    });

    test('fromMap should handle missing fields', () {
      final map = <String, dynamic>{};

      final subTask = SubTask.fromMap(map, 'st2');

      expect(subTask.id, 'st2');
      expect(subTask.title, '');
      expect(subTask.isDone, isFalse);
      expect(subTask.order, 0);
    });

    test('copyWith should work correctly', () {
      final subTask = SubTask(
        id: 'st1',
        taskId: 'task1',
        userId: 'user1',
        title: 'Old title',
      );

      final updated = subTask.copyWith(title: 'New title', isDone: true);

      expect(updated.title, 'New title');
      expect(updated.isDone, isTrue);
      expect(updated.id, 'st1');
      expect(updated.taskId, 'task1');
    });
  });
}
