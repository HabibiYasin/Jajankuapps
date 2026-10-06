import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/budget_limits.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/services/account_data_service.dart';
import 'package:flutter_application_1/services/cloud_account_store.dart';

TransactionModel sample({double amount = 62500}) => TransactionModel(
  merchant: 'Warung',
  nominalStr: 'Rp62.500',
  dateTime: DateTime(2026, 10, 1, 12),
  category: 'Makanan',
  numericNominal: amount,
);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  test(
    'denied budget save never completes onboarding and can be retried',
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
      final data = AccountDataService(
        firestore: firestore,
        currentUid: () => 'alice',
      );
      addTearDown(data.dispose);
      await data.switchAccount('alice');
      await settle();
      var completed = false;
      data.addListener(() {
        completed = completed || data.limits.isConfigured;
      });
      const budget = BudgetLimits(
        daily: 75000,
        categories: BudgetLimits.snackCategories,
      );
      await expectLater(
        data.saveBudget(budget, expectedUid: 'alice'),
        throwsA(isA<Exception>()),
      );
      await settle();
      expect(completed, false);
      expect(data.limits.isConfigured, false);
      expect(data.pending, false);
      firestore.authObject.add({'uid': 'alice'});
      await data.saveBudget(budget, expectedUid: 'alice');
      await settle();
      expect(data.limits.isConfigured, true);
      expect(data.limits.daily, 75000);
      expect(data.error, isNull);
      await data.switchAccount('alice');
      await settle();
      expect(data.limits.isConfigured, true);
    },
  );
  test('transactions and budget stream across devices and stay isolated by account', () async {
    final firestore = FakeFirebaseFirestore();
    var current = 'alice';
    final first = AccountDataService(
      firestore: firestore,
      currentUid: () => current,
    );
    final second = AccountDataService(
      firestore: firestore,
      currentUid: () => 'alice',
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await first.switchAccount('alice');
    await second.switchAccount('alice');
    await first.insert(sample(), expectedUid: 'alice');
    await first.saveBudget(
      const BudgetLimits(
        daily: 70000,
        categories: BudgetLimits.snackCategories,
      ),
      expectedUid: 'alice',
    );
    await settle();
    expect(second.history.single.numericNominal, 62500);
    expect(second.limits.daily, 70000);
    expect(second.limits.isConfigured, true);
    expect(second.limits.trackedCategories, BudgetLimits.snackCategories);
    final previousTransaction = first.history.single;
    current = 'bob';
    final switching = first.switchAccount('bob');
    expect(first.history, isEmpty);
    expect(first.limits.isConfigured, false);
    expect(first.limits.daily, 50000);
    await switching;
    await settle();
    expect(first.history, isEmpty);
    await expectLater(first.delete(previousTransaction), throwsStateError);
    await expectLater(
      first.insert(sample(), expectedUid: 'alice'),
      throwsStateError,
    );
    await expectLater(
      first.saveBudget(const BudgetLimits(daily: 10), expectedUid: 'alice'),
      throwsStateError,
    );
    await second.insert(sample(amount: 900), expectedUid: 'alice');
    await settle();
    expect(first.history, isEmpty);
    expect(second.history, hasLength(2));
  });

  test('cloud edits, date changes and deletions propagate without stale index writes', () async {
    final firestore = FakeFirebaseFirestore();
    final data = AccountDataService(
      firestore: firestore,
      currentUid: () => 'alice',
    );
    addTearDown(data.dispose);
    await data.switchAccount('alice');
    await data.insert(sample(), expectedUid: 'alice');
    await settle();
    final tx = data.history.single;
    tx.merchant = 'Edited';
    await data.updateDetails(tx);
    await data.updateDate(tx, DateTime(2026, 9, 30));
    await settle();
    expect(data.history.single.merchant, 'Edited');
    expect(data.history.single.dateTime, DateTime(2026, 9, 30));
    await data.delete(tx);
    await settle();
    expect(data.history, isEmpty);
  });

  test(
    'import retry neither duplicates nor overwrites nor resurrects cloud rows',
    () async {
      final firestore = FakeFirebaseFirestore();
      final cloud = CloudAccountStore(firestore);
      await cloud.importOnce('alice', 'stable-id', sample());
      await cloud.transactions('alice').doc('stable-id').update({
        'merchant': 'Changed elsewhere',
      });
      await cloud.importOnce('alice', 'stable-id', sample());
      expect((await cloud.transactions('alice').get()).docs, hasLength(1));
      expect(
        (await cloud.transactions('alice').doc('stable-id').get())
            .data()!['merchant'],
        'Changed elsewhere',
      );
      await cloud.transactions('alice').doc('stable-id').delete();
      await cloud.importOnce('alice', 'stable-id', sample());
      expect((await cloud.transactions('alice').get()).docs, isEmpty);
    },
  );

  test('budget validation rejects zero, negative and non-finite values', () {
    for (final value in [0.0, -1.0, double.infinity, double.nan, 1e16]) {
      expect(BudgetLimits(daily: value).isValid, false);
    }
    expect(const BudgetLimits().isValid, true);
  });
}
