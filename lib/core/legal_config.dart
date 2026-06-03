/// Legal document URLs and version identifiers for Play Store / GDPR compliance.
///
/// Replace the URLs with your hosted Privacy Policy and Terms of Service before
/// publishing. The same URLs must be listed in Google Play Console.
class LegalConfig {
  LegalConfig._();

  static const String privacyPolicyUrl =
      'https://lapis-todo.app/privacy-policy';
  static const String termsOfServiceUrl =
      'https://lapis-todo.app/terms-of-service';

  /// Bump when legal text changes so acceptance can be re-collected if needed.
  static const String privacyPolicyVersion = '1.0';
  static const String termsVersion = '1.0';

  static const String appName = 'Lapis';
  static const String dataCollectionSummary =
      'We store your email, username, and tasks to provide the service. '
      'Data is processed via Firebase (Google).';

}
