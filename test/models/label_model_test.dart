import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/subclasses/label.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void main() {
  group('Label Model', () {
    test('toMap and fromMap should round-trip correctly', () {
      final original = Label(
        id: 'label1',
        name: 'Work',
        color: Colors.blue.toARGB32(),
        userId: 'user123',
      );

      final map = original.toMap();
      final restored = Label.fromMap(map, 'label1');

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.color, original.color);
      expect(restored.userId, original.userId);
    });

    test('fromMap should use defaults for missing fields', () {
      final restored = Label.fromMap({}, 'label1');

      expect(restored.id, 'label1');
      expect(restored.name, '');
      expect(restored.color, 0xFF9E9E9E);
      expect(restored.userId, '');
    });

    test('toMap should contain all required fields', () {
      final label = Label(
        id: 'l1',
        name: 'Test',
        color: 0xFFFF0000,
        userId: 'uid',
      );

      final map = label.toMap();

      expect(map['name'], 'Test');
      expect(map['color'], 0xFFFF0000);
      expect(map['userId'], 'uid');
      expect(map.length, 3);
    });

    test('copyWith should update only specified fields', () {
      final original = Label(
        id: 'l1',
        name: 'Original',
        color: 0xFF000000,
        userId: 'uid',
      );

      final updated = original.copyWith(name: 'Updated', color: 0xFFFFFFFF);

      expect(updated.id, 'l1');
      expect(updated.name, 'Updated');
      expect(updated.color, 0xFFFFFFFF);
      expect(updated.userId, 'uid');
    });

    test('copyWith with no args should return identical fields', () {
      final original = Label(
        id: 'l1',
        name: 'Test',
        color: 0xFF000000,
        userId: 'uid',
      );

      final updated = original.copyWith();

      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.color, original.color);
      expect(updated.userId, original.userId);
    });
  });

  group('Task labelIds persistence', () {
    final testCategory = TaskCategory(
      id: 'cat1',
      name: 'Work',
      color: Colors.blue.toARGB32(),
    );

    final testDate = DateTime(2026, 6, 23);

    test('task should persist labelIds through toMap/fromMap round-trip', () {
      final task = Task(
        id: 'task1',
        userId: 'user1',
        title: 'Labeled Task',
        category: testCategory,
        createdAt: testDate,
        labelIds: ['label1', 'label2', 'label3'],
      );

      final map = task.toMap();
      map['createdAt'] = Timestamp.fromDate(testDate);
      final restored = Task.fromMap(map, 'task1');

      expect(restored.labelIds, ['label1', 'label2', 'label3']);
    });

    test('task fromMap should default to empty list for missing labelIds', () {
      final map = {
        'userId': 'user1',
        'title': 'No Labels',
        'status': 0,
        'type': 0,
        'priority': 0,
        'category': testCategory.toMap(),
        'createdAt': Timestamp.fromDate(testDate),
      };

      final task = Task.fromMap(map, 'task1');

      expect(task.labelIds, isEmpty);
    });

    test('task copyWith should preserve labelIds when not overridden', () {
      final original = Task(
        id: 'task1',
        userId: 'user1',
        title: 'Original',
        category: testCategory,
        createdAt: testDate,
        labelIds: ['label1'],
      );

      final updated = original.copyWith(title: 'Updated');

      expect(updated.labelIds, ['label1']);
    });

    test('task copyWith should override labelIds when provided', () {
      final original = Task(
        id: 'task1',
        userId: 'user1',
        title: 'Original',
        category: testCategory,
        createdAt: testDate,
        labelIds: ['label1'],
      );

      final updated = original.copyWith(labelIds: ['label2', 'label3']);

      expect(updated.labelIds, ['label2', 'label3']);
    });
  });
}
