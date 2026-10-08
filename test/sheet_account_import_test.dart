import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/services/account_data_service.dart';
import 'package:flutter_application_1/services/cloud_account_store.dart';

TransactionModel sample(String merchant, {String type = 'expense'}) =>
    TransactionModel(
      merchant: merchant,
      type: type,
      nominalStr: 'Rp1000',
      numericNominal: 1000,
      dateTime: DateTime(2026, 10, 8),
      category: type == 'income' ? 'Gaji' : 'Makanan',
    );
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  test('import replaces whole account ledger, persists additions, and leaves other accounts/budget intact', () async {
    final firestore = FakeFirebaseFirestore();
    final cloud = CloudAccountStore(firestore);
    await cloud
        .transactions('alice')
        .doc('old')
        .set(CloudAccountStore.encode(sample('Old')));
    await cloud
        .transactions('alice')
        .doc('removed')
        .set(CloudAccountStore.encode(sample('Remove')));
    await cloud
        .transactions('bob')
        .doc('keep')
        .set(CloudAccountStore.encode(sample('Bob')));
    await cloud.budget('alice').set({
      'daily': 1000,
      'weekly': 7000,
      'monthly': 30000,
    });
    final service = AccountDataService(
      firestore: firestore,
      currentUid: () => 'alice',
    );
    addTearDown(service.dispose);
    await service.switchAccount('alice');
    await settle();
    await service.replaceTransactions(
      [sample('Edited'), sample('Salary', type: 'income'), sample('Added')],
      expectedUid: 'alice',
      expectedRevision: service.transactionRevision,
    );
    await settle();
    expect(service.history.map((t) => t.merchant).toSet(), {
      'Edited',
      'Salary',
      'Added',
    });
    expect(service.history.where((t) => t.isIncome), hasLength(1));
    expect(
      (await cloud.transactions('bob').get()).docs.single.data()['merchant'],
      'Bob',
    );
    expect((await cloud.budget('alice').get()).data()!['daily'], 1000);
    await service.replaceTransactions(
      [sample('Only')],
      expectedUid: 'alice',
      expectedRevision: service.transactionRevision,
    );
    await settle();
    expect(service.history.single.merchant, 'Only');
    expect((await cloud.transactions('alice').get()).docs, hasLength(1));
  });

  test(
    'empty, stale and wrong account imports leave old data intact',
    () async {
      final firestore = FakeFirebaseFirestore();
      final cloud = CloudAccountStore(firestore);
      await cloud
          .transactions('alice')
          .doc('old')
          .set(CloudAccountStore.encode(sample('Old')));
      final service = AccountDataService(
        firestore: firestore,
        currentUid: () => 'alice',
      );
      addTearDown(service.dispose);
      await service.switchAccount('alice');
      await settle();
      for (final rows in [<TransactionModel>[]]) {
        await expectLater(
          service.replaceTransactions(
            rows,
            expectedUid: 'alice',
            expectedRevision: service.transactionRevision,
          ),
          throwsStateError,
        );
      }
      await expectLater(
        service.replaceTransactions(
          [sample('New')],
          expectedUid: 'bob',
          expectedRevision: service.transactionRevision,
        ),
        throwsStateError,
      );
      await expectLater(
        service.replaceTransactions(
          [sample('New')],
          expectedUid: 'alice',
          expectedRevision: 'stale',
        ),
        throwsStateError,
      );
      expect(
        (await cloud.transactions('alice').get()).docs.single
            .data()['merchant'],
        'Old',
      );
      expect(service.importing, false);
    },
  );

  test(
    'server rejection is surfaced instead of reporting successful import',
    () async {
      final firestore = FakeFirebaseFirestore(
        securityRules: '''
        service cloud.firestore {
          match /databases/{database}/documents {
            match /{document=**} {
              allow read: if true;
              allow write: if request.auth != null;
            }
          }
        }
      ''',
      );
      firestore.authObject.add({'uid': 'alice'});
      final cloud = CloudAccountStore(firestore);
      await cloud
          .transactions('alice')
          .doc('old')
          .set(CloudAccountStore.encode(sample('Old')));
      firestore.authObject.add(null);
      final service = AccountDataService(
        firestore: firestore,
        currentUid: () => 'alice',
      );
      addTearDown(service.dispose);
      await service.switchAccount('alice');
      await settle();
      await expectLater(
        service.replaceTransactions(
          [sample('New')],
          expectedUid: 'alice',
          expectedRevision: service.transactionRevision,
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        (await cloud.transactions('alice').get()).docs.single
            .data()['merchant'],
        'Old',
      );
      expect(service.importing, false);
    },
  );
}
