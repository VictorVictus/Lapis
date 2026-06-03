import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/core/legal_config.dart';
import 'package:url_launcher/url_launcher.dart';

/// Play Store–compliant terms/privacy links and optional acceptance checkbox.
class LegalConsentSection extends StatelessWidget {
  const LegalConsentSection({
    super.key,
    required this.accepted,
    required this.onAcceptedChanged,
    this.showCheckbox = true,
    this.compact = false,
  });

  final bool accepted;
  final ValueChanged<bool?> onAcceptedChanged;
  final bool showCheckbox;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white.withValues(alpha: 0.8),
    );

    final legalText = Text.rich(
      TextSpan(
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: compact ? 11 : 12,
          height: 1.4,
        ),
        children: [
          if (showCheckbox)
            const TextSpan(text: 'I agree to the ')
          else
            const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openUrl(LegalConfig.termsOfServiceUrl),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openUrl(LegalConfig.privacyPolicyUrl),
          ),
          if (!showCheckbox) const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );

    if (!showCheckbox) {
      return legalText;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: accepted,
            onChanged: onAcceptedChanged,
            activeColor: Colors.white,
            checkColor: Theme.of(context).colorScheme.primary,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: legalText),
      ],
    );
  }

  static Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not open $url');
    }
  }
}
