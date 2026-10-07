import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/screens/income_screen.dart';
import 'package:flutter_application_1/screens/transaction_history_screen.dart';

void main() {
  testWidgets(
    'Expense history and income tab isolate their rows and categories',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TransactionModel row(String type, String name, String category) =>
          TransactionModel(
            type: type,
            merchant: name,
            category: category,
            nominalStr: 'Rp10000',
            numericNominal: 10000,
            dateTime: DateTime.now(),
          );
      final history = [
        row('expense', 'Warung', 'Makanan'),
        row('income', 'Perusahaan', 'Gaji'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionHistoryScreen(
              history: history,
              onDelete: (_) {},
              onUpdateDate: (_, _) {},
              onUpdateTransaction: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Warung'), findsOneWidget);
      expect(find.text('Perusahaan'), findsNothing);
      expect(find.text('Jenis Transaksi'), findsNothing);
      expect(find.text('Catat Pemasukan'), findsNothing);
      var added = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncomeScreen(
              history: history,
              onAddIncome: () async {
                added = true;
              },
              onDelete: (_) {},
              onUpdateDate: (_, _) {},
              onUpdateTransaction: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Perusahaan'), findsOneWidget);
      expect(find.text('Warung'), findsNothing);
      expect(find.text('Jenis Transaksi'), findsNothing);
      expect(find.text('Download Laporan Bulanan PDF'), findsNothing);
      await tester.tap(find.text('Catat Pemasukan'));
      await tester.pump();
      expect(added, true);
      final category = find.byKey(const ValueKey('history-category-filter'));
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      for (final label in TransactionModel.incomeCategories) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Makanan'), findsNothing);
    },
  );
}
