import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';
import 'package:flutter/material.dart';

void main() {
  group('TaskCategory Model Tests', () {
    test('should correctly convert to map', () {
      final category = TaskCategory(
        id: 'cat1',
        name: 'Work',
        color: Colors.blue.toARGB32(),
      );

      final map = category.toMap();

      expect(map['id'], 'cat1');
      expect(map['name'], 'Work');
      expect(map['color'], Colors.blue.toARGB32());
    });

    test('should correctly create from map', () {
      final map = <String, dynamic>{
        'id': 'cat1',
        'name': 'Work',
        'color': Colors.blue.toARGB32(),
      };

      final category = TaskCategory.fromMap(map);

      expect(category.id, 'cat1');
      expect(category.name, 'Work');
      expect(category.color, Colors.blue.toARGB32());
    });

    test('fromMap should handle missing fields with defaults', () {
      final map = <String, dynamic>{};

      final category = TaskCategory.fromMap(map);

      expect(category.id, '');
      expect(category.name, '');
      expect(category.color, 0xFFFFFFFF);
    });
  });
}
