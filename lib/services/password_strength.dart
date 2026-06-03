/// Password rules aligned with Firebase Auth minimums and Play Store guidance.
class PasswordStrength {
  PasswordStrength._();

  static const int minLength = 8;
  static const int maxLength = 128;

  static bool validatePassword(String password) {
    if (password.length < minLength || password.length > maxLength) {
      return false;
    }
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    return hasUpper && hasLower && hasDigit;
  }

  static String? passwordError(String password) {
    if (password.isEmpty) return 'Password is required.';
    if (password.length < minLength) {
      return 'Password must be at least $minLength characters.';
    }
    if (password.length > maxLength) {
      return 'Password must be at most $maxLength characters.';
    }
    if (!validatePassword(password)) {
      return 'Use upper and lower case letters and at least one number.';
    }
    return null;
  }

  /// Returns "Weak", "Medium", or "Strong" for UI feedback during sign-up.
  static String getStrengthOfPassword(String password) {
    if (password.isEmpty) return 'Weak';
    if (!validatePassword(password)) return 'Weak';
    if (password.length >= 12 &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Strong';
    }
    if (password.length >= 10) return 'Strong';
    return 'Medium';
  }

  static List<String> requirementsMet(String password) {
    final met = <String>[];
    if (password.length >= minLength) met.add('At least $minLength characters');
    if (RegExp(r'[A-Z]').hasMatch(password)) met.add('Uppercase letter');
    if (RegExp(r'[a-z]').hasMatch(password)) met.add('Lowercase letter');
    if (RegExp(r'[0-9]').hasMatch(password)) met.add('Number');
    return met;
  }
}
