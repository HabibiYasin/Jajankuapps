import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/screens/personalization_screen.dart';

Widget profileApp() => const MaterialApp(
  home: Scaffold(
    body: PersonalizationScreen(
      userName: 'Guest',
      dailyLimit: 50000,
      weeklyLimit: 350000,
      monthlyLimit: 1500000,
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Guest can edit a name and reload it without dialog errors', (
    tester,
  ) async {
    await tester.pumpWidget(profileApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pengaturan akun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit nama'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  Habibi  ');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Habibi'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('guest_profile_name'), 'Habibi');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(profileApp());
    await tester.pumpAndSettle();
    expect(find.text('Habibi'), findsOneWidget);
  });

  testWidgets('Blank name is rejected and cancel keeps existing name', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'guest_profile_name': 'Habibi'});
    await tester.pumpWidget(profileApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pengaturan akun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit nama'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Nama tidak boleh kosong.'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Habibi'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('guest_profile_name'), 'Habibi');
  });
}
