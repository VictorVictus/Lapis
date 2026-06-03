import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/focus_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('FocusSession Model Tests', () {
    final testDate = DateTime(2026, 6, 1, 10, 0);

    test('should correctly convert to map', () {
      final session = FocusSession(
        id: 'fs1',
        userId: 'user1',
        taskId: 'task1',
        taskTitle: 'Fix bug',
        durationSeconds: 1500,
        createdAt: testDate,
      );

      final map = session.toMap();

      expect(map['userId'], 'user1');
      expect(map['taskId'], 'task1');
      expect(map['taskTitle'], 'Fix bug');
      expect(map['durationSeconds'], 1500);
      expect(map['createdAt'], testDate);
    });

    test('should correctly create from map', () {
      final map = <String, dynamic>{
        'userId': 'user1',
        'taskId': 'task1',
        'taskTitle': 'Fix bug',
        'durationSeconds': 1500,
        'createdAt': Timestamp.fromDate(testDate),
      };

      final session = FocusSession.fromMap(map, 'fs1');

      expect(session.id, 'fs1');
      expect(session.userId, 'user1');
      expect(session.taskId, 'task1');
      expect(session.taskTitle, 'Fix bug');
      expect(session.durationSeconds, 1500);
      expect(session.createdAt, testDate);
    });

    test('fromMap should handle missing fields', () {
      final map = <String, dynamic>{};

      final session = FocusSession.fromMap(map, 'fs2');

      expect(session.id, 'fs2');
      expect(session.userId, '');
      expect(session.taskTitle, '');
      expect(session.durationSeconds, 0);
    });
  });
}
