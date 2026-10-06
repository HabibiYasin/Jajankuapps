import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/budget_settings_screen.dart';
import 'package:flutter_application_1/screens/personalization_screen.dart';

void main() {
  testWidgets('Guest can configure budget categories without logging in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PersonalizationScreen(
            userName: 'Guest',
            dailyLimit: 50000,
            weeklyLimit: 350000,
            monthlyLimit: 1500000,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limit Budget'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(BudgetSettingsScreen), findsOneWidget);
    expect(find.text('Kategori yang mengurangi budget'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(BudgetSettingsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
