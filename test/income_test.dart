import 'package:flutter/material.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/models/budget_limits.dart';
import 'package:flutter_application_1/models/budget_totals.dart';
import 'package:flutter_application_1/services/cloud_account_store.dart';
import 'package:flutter_application_1/services/export_service.dart';
import 'package:flutter_application_1/services/monthly_report_service.dart';
import 'package:flutter_application_1/services/budget_notification_service.dart';
import 'package:flutter_application_1/screens/manual_expense_screen.dart';

void main() {
  test(
    'Income persists in cloud and appears separately in Excel and PDF',
    () async {
      final income = TransactionModel(
        type: 'income',
        merchant: 'Gaji',
        nominalStr: 'Rp3000000',
        dateTime: DateTime(2026, 10, 7),
        category: 'Gaji',
        source: 'BCA',
        paymentMethod: 'Transfer',
        numericNominal: 3000000,
      );
      final store = CloudAccountStore(FakeFirebaseFirestore());
      await store.transactions('alice').add(CloudAccountStore.encode(income));
      final saved = CloudAccountStore.decode(
        'alice',
        (await store.transactions('alice').get()).docs.single,
      );
      expect(saved.isIncome, true);
      final workbook = Excel.decodeBytes(ExportService.buildWorkbook([saved]));
      expect(workbook['Bulanan'].rows[1][2]!.value, IntCellValue(0));
      expect(workbook['Bulanan'].rows[1][3]!.value, IntCellValue(3000000));
      expect(
        workbook['Transaksi'].rows[1][7]!.value,
        TextCellValue('Pemasukan'),
      );
      final pdf = await MonthlyReportService.buildPdf(
        report: MonthlyReport(
          history: [saved],
          month: income.dateTime,
          limits: const BudgetLimits(),
        ),
        name: 'Pengguna',
      );
      expect(pdf.length, greaterThan(1000));
    },
  );
  test('Income never consumes budget or inflates expense reports and notifications', () {
    final date = DateTime(2026, 10, 7);
    TransactionModel row(String type, double amount) => TransactionModel(
      type: type,
      merchant: 'Perusahaan',
      nominalStr: '$amount',
      dateTime: date,
      category: 'Makanan',
      source: 'BCA',
      paymentMethod: 'Transfer',
      numericNominal: amount,
    );
    final expense = row('expense', 25000);
    final income = row('income', 3000000);
    final history = [expense, income];
    const limits = BudgetLimits();
    expect(limits.includes(income), false);
    final totals = BudgetTotals.forPeriod(
      history,
      limits.trackedCategories,
      date,
      monthly: true,
    );
    expect(totals.tracked, 25000);
    expect(totals.other, 0);
    expect(BudgetNotificationService.dailyTotals(history).values.single, 25000);
    final report = MonthlyReport(history: history, month: date, limits: limits);
    expect(report.total, 25000);
    expect(report.incomeTotal, 3000000);
    expect(report.groups().single.count, 1);
    expect(CloudAccountStore.encode(income)['type'], 'income');
    expect(limits.monthly, 1500000);
  });

  testWidgets(
    'Income form saves origin, destination, category and positive amount',
    (tester) async {
      TransactionModel? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<TransactionModel>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManualExpenseScreen(isIncome: true),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Gaji perusahaan',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '3000000');
      await tester.enterText(find.byType(TextFormField).at(2), 'BCA');
      await tester.ensureVisible(find.text('Simpan Pemasukan'));
      await tester.tap(find.text('Simpan Pemasukan'));
      await tester.pumpAndSettle();
      expect(result?.isIncome, true);
      expect(result?.category, 'Gaji');
      expect(result?.source, 'BCA');
      expect(result?.merchant, 'Gaji perusahaan');
      expect(result?.numericNominal, 3000000);
    },
  );
}
