import 'package:to_do_app/models/user.dart';

enum AuthFailureCode {
  invalidEmail,
  invalidUsername,
  weakPassword,
  termsNotAccepted,
  emailAlreadyInUse,
  wrongPassword,
  userNotFound,
  userDisabled,
  tooManyRequests,
  networkError,
  requiresRecentLogin,
  cancelled,
  unknown,
}

class AuthResult {
  final User? user;
  final AuthFailureCode? failureCode;
  final String? message;

  const AuthResult.success([this.user])
      : failureCode = null,
        message = null;

  const AuthResult.failure({
    required this.failureCode,
    required this.message,
  }) : user = null;

  bool get isSuccess => failureCode == null;
}
