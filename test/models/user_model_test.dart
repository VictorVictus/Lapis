import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('User Model Tests', () {
    final testDate = DateTime(2026, 4, 6, 12, 0);

    test('should correctly convert to map', () {
      final user = User(
        uid: 'user1',
        username: 'testuser',
        email: 'test@example.com',
        createdAt: testDate,
      );

      final map = user.toMap();

      expect(map['uid'], 'user1');
      expect(map['username'], 'testuser');
      expect(map['email'], 'test@example.com');
      expect(map['createdAt'], testDate);
      expect(map.containsKey('taskIds'), isFalse); // Scalability check
    });

    test('should correctly create from map', () {
      final map = {
        'uid': 'user1',
        'username': 'testuser',
        'email': 'test@example.com',
        'createdAt': Timestamp.fromDate(testDate),
      };

      final user = User.fromMap(map);

      expect(user.uid, 'user1');
      expect(user.username, 'testuser');
      expect(user.email, 'test@example.com');
      expect(user.createdAt, testDate);
    });

    test('copyWith should work correctly', () {
      final user = User(
        uid: 'user1',
        username: 'testuser',
        email: 'test@example.com',
      );

      final updatedUser = user.copyWith(
        profilePictureUrl: 'https://example.com/pic.jpg',
      );

      expect(updatedUser.uid, 'user1');
      expect(updatedUser.profilePictureUrl, 'https://example.com/pic.jpg');
    });
  });
}
