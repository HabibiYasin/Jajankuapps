import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/login_screen.dart';

void main() {
  testWidgets('Login validates email and password before contacting Firebase', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pump();
    expect(find.text('Masukkan email yang valid.'), findsOneWidget);
    expect(find.text('Masukkan password.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Registration rejects short and mismatched passwords', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.tap(find.text('Belum punya akun? Daftar'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'user@example.com');
    await tester.enterText(fields.at(1), '123');
    await tester.enterText(fields.at(2), 'different');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Daftar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Daftar'));
    await tester.pump();
    expect(find.text('Password minimal 6 karakter.'), findsOneWidget);
    expect(find.text('Password tidak sama.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
