class AuthValidator {
  AuthValidator._();

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9._-]{3,24}$');

  static bool isValidEmail(String email) {
    final trimmed = email.trim();
    return trimmed.isNotEmpty && _emailRegex.hasMatch(trimmed);
  }

  static bool isValidUsername(String username) {
    final trimmed = username.trim();
    return trimmed.isNotEmpty && _usernameRegex.hasMatch(trimmed);
  }

  static String? emailError(String email) {
    if (email.trim().isEmpty) return 'Email is required.';
    if (!isValidEmail(email)) return 'Enter a valid email address.';
    return null;
  }

  static String? usernameError(String username) {
    if (username.trim().isEmpty) return 'Username is required.';
    if (!isValidUsername(username)) {
      return 'Username must be 3–24 characters (letters, numbers, . _ -).';
    }
    return null;
  }
}
