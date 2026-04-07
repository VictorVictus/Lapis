import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/taskcategory.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void main() {
  group('Task Model Tests', () {
    final testCategory = TaskCategory(
      id: 'cat1',
      name: 'Work',
      color: Colors.blue.value,
    );

    final testDate = DateTime(2026, 4, 6, 12, 0);

    test('should correctly convert to map', () {
      final task = Task(
        id: '1',
        userId: 'user1',
        title: 'Test Task',
        category: testCategory,
        createdAt: testDate,
        priority: TaskPriority.high,
      );

      final map = task.toMap();

      expect(map['userId'], 'user1');
      expect(map['title'], 'Test Task');
      expect(map['priority'], TaskPriority.high.index);
      expect(map['category']['name'], 'Work');
      expect(map['createdAt'], testDate);
    });

    test('should correctly create from map', () {
      final map = {
        'userId': 'user1',
        'title': 'Test Task',
        'status': 0,
        'type': 0,
        'priority': 3,
        'category': testCategory.toMap(),
        'createdAt': Timestamp.fromDate(testDate),
      };

      final task = Task.fromMap(map, '1');

      expect(task.id, '1');
      expect(task.userId, 'user1');
      expect(task.priority, TaskPriority.high);
      expect(task.createdAt, testDate);
    });

    test('copyWith should work correctly', () {
      final task = Task(
        id: '1',
        userId: 'user1',
        title: 'Old Title',
        category: testCategory,
        createdAt: testDate,
      );

      final updatedTask = task.copyWith(title: 'New Title', status: TaskStatus.fulfilled);

      expect(updatedTask.title, 'New Title');
      expect(updatedTask.status, TaskStatus.fulfilled);
      expect(updatedTask.id, '1'); // Unchanged
      expect(updatedTask.userId, 'user1'); // Unchanged
    });
  });
}
