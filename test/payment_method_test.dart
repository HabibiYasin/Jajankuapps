import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/services/cloud_account_store.dart';
import 'package:flutter_application_1/screens/transaction_history_screen.dart';

void main() {
  TransactionModel transaction() => TransactionModel(
    merchant: 'Toko',
    nominalStr: 'Rp10000',
    numericNominal: 10000,
    category: 'Makanan',
    dateTime: DateTime(2026, 10, 7),
    source: 'BCA',
  );

  testWidgets(
    'History displays payment method and edits method independently of money source',
    (tester) async {
      final tx = transaction()..dateTime = DateTime.now();
      TransactionModel? edited;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionHistoryScreen(
              history: [tx],
              onDelete: (_) {},
              onUpdateDate: (_, _) {},
              onUpdateTransaction: (value) => edited = value,
            ),
          ),
        ),
      );
      expect(find.textContaining('Sumber Uang: BCA'), findsOneWidget);
      await tester.ensureVisible(find.text('Toko'));
      await tester.tap(find.text('Toko'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Detail'));
      await tester.pumpAndSettle();
      expect(find.text('Sumber Uang'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'QRIS'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transfer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(edited?.paymentMethod, 'Transfer');
      expect(edited?.source, 'BCA');
      expect(find.textContaining('Metode: Transfer'), findsOneWidget);
    },
  );

  test('Legacy documents default to QRIS; all methods survive cloud round trip and edits', () async {
    final db = FakeFirebaseFirestore();
    final store = CloudAccountStore(db);
    final legacy = CloudAccountStore.encode(transaction())
      ..remove('paymentMethod');
    await store.transactions('alice').doc('legacy').set(legacy);
    expect(
      CloudAccountStore.decode(
        'alice',
        (await store.transactions('alice').get()).docs.single,
      ).paymentMethod,
      'QRIS',
    );
    for (final method in TransactionModel.paymentMethods) {
      final tx = transaction()..paymentMethod = method;
      await store
          .transactions('alice')
          .doc('legacy')
          .set(CloudAccountStore.encode(tx));
      final read = CloudAccountStore.decode(
        'alice',
        (await store.transactions('alice').get()).docs.single,
      );
      expect(read.paymentMethod, method);
      expect(read.source, 'BCA');
    }
  });
}
