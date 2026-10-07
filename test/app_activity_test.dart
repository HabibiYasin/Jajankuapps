import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/app_activity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FakeFirebaseFirestore();
  });

  test('First observed installation stays fixed and every opening updates local timestamp', () async {
    final preferences = await SharedPreferences.getInstance();
    final first = DateTime.utc(2026, 10, 7);
    final next = first.add(const Duration(days: 1));
    expect(
      await AppActivityService.recordLocalOpen(preferences, now: first),
      first,
    );
    expect(
      await AppActivityService.recordLocalOpen(preferences, now: next),
      first,
    );
    expect(
      preferences.getString(AppActivityService.openedKey),
      next.toIso8601String(),
    );
  });

  test(
    'Account installedAt is retained; uninstall is not falsely recorded',
    () async {
      final first = Timestamp.fromDate(DateTime.utc(2026, 1, 1));
      final existing = await AppActivityService.profileFields({
        'installedAt': first,
        'deletedAt': null,
      });
      expect(existing.containsKey('installedAt'), false);
      expect(existing.containsKey('deletedAt'), false);
      final newFields = await AppActivityService.profileFields(null);
      expect(newFields['installedAt'], isA<Timestamp>());
      expect(newFields['deletedAt'], isNull);
    },
  );

  test(
    'Cloud openings reuse installation and preserve other accounts',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.doc('users/alice').set({'displayName': 'Alice'});
      await firestore.doc('users/bob').set({'displayName': 'Bob'});
      await AppActivityService.recordCloudOpen(firestore, 'alice');
      final installations = firestore.collection('users/alice/installations');
      final first = (await installations.get()).docs.single;
      expect(first.data()['installedAt'], isA<Timestamp>());
      expect(first.data()['lastOpenedAt'], isA<Timestamp>());
      expect(first.data()['deletedAt'], isNull);
      await AppActivityService.recordCloudOpen(firestore, 'alice');
      final next = (await installations.get()).docs.single;
      expect(next.id, first.id);
      expect(next.data()['installedAt'], first.data()['installedAt']);
      expect(
        (await firestore.doc('users/bob').get()).data()!.containsKey(
          'lastOpenedAt',
        ),
        false,
      );
    },
  );
}
