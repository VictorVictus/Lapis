import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/auth_result.dart';
import 'package:to_do_app/models/user.dart';

void main() {
  group('AuthResult Tests', () {
    final testUser = User(uid: 'u1', username: 'test', email: 't@t.com');

    test('success should have no failureCode', () {
      const result = AuthResult.success();
      expect(result.isSuccess, isTrue);
      expect(result.failureCode, isNull);
      expect(result.user, isNull);
    });

    test('success with user should carry user', () {
      final result = AuthResult.success(testUser);
      expect(result.isSuccess, isTrue);
      expect(result.user, testUser);
    });

    test('failure should have code and message', () {
      const result = AuthResult.failure(
        failureCode: AuthFailureCode.invalidEmail,
        message: 'Invalid email',
      );
      expect(result.isSuccess, isFalse);
      expect(result.failureCode, AuthFailureCode.invalidEmail);
      expect(result.message, 'Invalid email');
      expect(result.user, isNull);
    });
  });
}
