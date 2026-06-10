import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_app/widgets/onboarding_screen.dart';

void main() {
  group('OnboardingScreen', () {
    testWidgets('renders step 1 on launch', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(next: const SizedBox.shrink()),
        ),
      );

      expect(find.text('Add your first task'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Get started'), findsNothing);
    });

    testWidgets('tapping Next advances to step 2', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(next: const SizedBox.shrink()),
        ),
      );

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Organize with categories'), findsOneWidget);
    });

    testWidgets('advancing twice shows Get started', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(next: const SizedBox.shrink()),
        ),
      );

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Track your progress'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('Skip button completes onboarding immediately', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(next: const SizedBox.shrink()),
        ),
      );

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Should have navigated away from onboarding
      expect(find.text('Add your first task'), findsNothing);
    });
  });
}
