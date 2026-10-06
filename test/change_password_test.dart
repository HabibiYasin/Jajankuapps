import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/change_password_screen.dart';

class _Info extends Fake implements UserInfo {
  @override
  final String providerId;
  _Info(this.providerId);
}

class _User extends Fake implements User {
  final bool google;
  _User({this.google = false});
  @override
  List<UserInfo> get providerData => [
    _Info(google ? 'google.com' : 'password'),
  ];
}

void main() {
  testWidgets('Email form requires old password and validates new password', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ChangePasswordScreen(user: _User())),
    );
    expect(find.text('Password lama'), findsOneWidget);
    await tester.tap(find.text('Simpan password'));
    await tester.pump();
    expect(find.text('Masukkan password lama.'), findsOneWidget);
    expect(find.text('Gunakan minimal 6 karakter.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'old-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
    await tester.enterText(find.byType(TextFormField).at(2), 'different');
    await tester.tap(find.text('Simpan password'));
    await tester.pump();
    expect(find.text('Password tidak sama.'), findsOneWidget);
  });
  testWidgets('Google form has no old password and explains app password', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ChangePasswordScreen(user: _User(google: true))),
    );
    expect(find.text('Password lama'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(
      find.textContaining('password akun Google tetap sama'),
      findsOneWidget,
    );
    expect(find.text('Verifikasi Google dan simpan'), findsOneWidget);
  });
}
