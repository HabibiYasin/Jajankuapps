import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/profile_avatar_store.dart';

import 'profile_name_test.dart' show profileApp;

void main() {
  test(
    'Avatar survives a new store and only updates its owner profile',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('alice').set({'displayName': 'Alice'});
      await db.collection('users').doc('bob').set({'avatarCode': 2});
      final store = ProfileAvatarStore(db);
      expect(await store.watch('alice').first, 1);
      for (var code = 1; code <= 6; code++) {
        await store.save('alice', code);
        expect(await ProfileAvatarStore(db).watch('alice').first, code);
      }
      expect(
        (await db.collection('users').doc('alice').get())
            .data()?['displayName'],
        'Alice',
      );
      expect(await store.watch('bob').first, 2);
      for (final code in [0, 7, -1]) {
        await expectLater(store.save('alice', code), throwsArgumentError);
      }
      expect(await store.watch('alice').first, 6);
    },
  );

  testWidgets('Guest can select a mascot, reload it, and cancel a change', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(profileApp());
    await tester.pumpAndSettle();
    Future<void> openPicker() async {
      await tester.tap(find.byTooltip('Pengaturan akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ganti foto profil'));
      await tester.pumpAndSettle();
    }

    await openPicker();
    for (final label in ProfileAvatarStore.labels) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Cilok'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getInt('guest_avatar_code'),
      6,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(profileApp());
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CircleAvatar &&
            widget.backgroundImage == const AssetImage('assets/avatars/6.png'),
      ),
      findsOneWidget,
    );
    await openPicker();
    await tester.tap(find.text('Boba'));
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CircleAvatar &&
            widget.backgroundImage == const AssetImage('assets/avatars/6.png'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
