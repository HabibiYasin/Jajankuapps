import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/account_deletion_service.dart';

void main() {
  test(
    'Deletes paginated account data and preserves another account',
    () async {
      final db = FakeFirebaseFirestore();
      final user = db.collection('users').doc('alice');
      await user.set({'displayName': 'Alice'});
      for (var i = 0; i < 451; i++) {
        await user.collection('transactions').doc('$i').set({'amount': i});
      }
      await user.collection('settings').doc('budget').set({'daily': 50});
      await user.collection('imports').doc('one').set({'completed': true});
      await user.collection('installations').doc('device').set({
        'deletedAt': null,
      });
      await db.collection('users').doc('bob').set({'displayName': 'Bob'});
      await deleteAccountData(db, 'alice', checkOwner: () {});
      expect((await user.get()).exists, false);
      for (final collection in [
        'transactions',
        'settings',
        'imports',
        'installations',
      ]) {
        expect((await user.collection(collection).get()).docs, isEmpty);
      }
      expect((await db.collection('users').doc('bob').get()).exists, true);
      await deleteAccountData(db, 'alice', checkOwner: () {});
    },
  );
  test('Owner mismatch prevents deletion', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('alice').set({'displayName': 'Alice'});
    await expectLater(
      deleteAccountData(
        db,
        'alice',
        checkOwner: () => throw StateError('Changed account'),
      ),
      throwsStateError,
    );
    expect((await db.collection('users').doc('alice').get()).exists, true);
  });
}
