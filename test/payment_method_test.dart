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
      await tester.tap(find.text('PayLater').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(edited?.paymentMethod, 'PayLater');
      expect(edited?.source, 'BCA');
      expect(find.textContaining('Metode: PayLater'), findsOneWidget);
    },
  );

  testWidgets('Payment method filter combines with search and method sorting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    TransactionModel row(String name, String method, int minutesAgo) =>
        transaction()
          ..merchant = name
          ..paymentMethod = method
          ..dateTime = now.subtract(Duration(minutes: minutesAgo));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionHistoryScreen(
            history: [
              row('Toko QRIS', 'QRIS', 0),
              row('Toko cicilan lama', 'PayLater', 2),
              row('Toko tunai', 'Cash', 3),
              row('Toko cicilan baru', 'PayLater', 1),
            ],
            onDelete: (_) {},
            onUpdateDate: (_, _) {},
            onUpdateTransaction: (_) {},
          ),
        ),
      ),
    );
    Future<void> select(String key, String value) async {
      final field = find.byKey(ValueKey(key));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).last);
      await tester.pumpAndSettle();
    }

    List<String> merchants() => tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data!)
        .toList();

    await select('history-sort-order', 'Metode pembayaran (A–Z)');
    expect(merchants(), [
      'Toko tunai',
      'Toko cicilan baru',
      'Toko cicilan lama',
      'Toko QRIS',
    ]);
    await select('history-payment-method-filter', 'PayLater');
    expect(merchants(), ['Toko cicilan baru', 'Toko cicilan lama']);
    await tester.enterText(find.byType(TextField), 'baru');
    await tester.pumpAndSettle();
    expect(merchants(), ['Toko cicilan baru']);
    await select('history-payment-method-filter', 'VA');
    expect(find.text('Tidak ada transaksi yang cocok'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await select('history-payment-method-filter', 'Semua');
    expect(merchants().length, 4);
    expect(tester.takeException(), isNull);
  });

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
