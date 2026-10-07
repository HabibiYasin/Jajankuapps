import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/budget_limits.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/services/monthly_report_service.dart';

TransactionModel tx(
  DateTime date,
  double amount, {
  String category = 'Makanan',
  String merchant = 'Warung',
}) => TransactionModel(
  merchant: merchant,
  nominalStr: '$amount',
  dateTime: date,
  category: category,
  numericNominal: amount,
);

void main() {
  const limits = BudgetLimits(monthly: 100, categories: ['Makanan']);
  test(
    'Budget selection, month boundary, comparable period and merchant ranking',
    () {
      final r = MonthlyReport(
        history: [
          tx(DateTime(2026, 1, 1), 80),
          tx(DateTime(2026, 1, 7), 40, merchant: ' warung '),
          tx(
            DateTime(2026, 1, 7),
            50,
            category: 'Transportasi',
            merchant: 'Bus',
          ),
          tx(DateTime(2025, 12, 7), 100),
          tx(DateTime(2025, 12, 8), 100),
          tx(DateTime(2026, 2, 1), 999),
        ],
        month: DateTime(2026, 1),
        limits: limits,
        generatedAt: DateTime(2026, 1, 7, 20),
      );
      expect(r.total, 170);
      expect(r.tracked, 120);
      expect(r.usedPercent, 120);
      expect(r.previousTotal, 100);
      expect(r.changePercent, 70);
      expect(r.groups(merchants: true).first.count, 2);
      expect(r.groups().first.name, 'Makanan');
      final allCategories = r.groups(includeEmpty: true);
      expect(allCategories, hasLength(8));
      expect(allCategories.first.name, 'Makanan');
      final unused = allCategories.singleWhere((g) => g.name == 'Minuman');
      expect(unused.count, 0);
      expect(unused.total, 0);
      expect(MonthlyReport.sum(r.previous), 200);
    },
  );

  test('Completed month uses all of previous month and zero baseline has no percentage', () {
    final r = MonthlyReport(
      history: [tx(DateTime(2026, 2, 28), 50), tx(DateTime(2026, 1, 31), 0)],
      month: DateTime(2026, 2),
      limits: limits,
      generatedAt: DateTime(2026, 3, 1),
    );
    expect(r.comparablePrevious.length, 1);
    expect(r.changePercent, isNull);
  });

  test('PDF renders empty, over-budget, long names, and many transactions without dropping rows', () async {
    for (final count in [0, 10, 400]) {
      final r = MonthlyReport(
        history: List.generate(
          count,
          (i) => tx(
            DateTime(2026, 9, i % 30 + 1, 12),
            12345.5,
            merchant: i == 0 ? List.filled(2000, 'A').join() : 'Toko $i',
            category: i % 2 == 0 ? 'Makanan' : 'Transportasi',
          ),
        ),
        month: DateTime(2026, 9),
        limits: limits,
        generatedAt: DateTime(2026, 10, 7),
      );
      final bytes = await MonthlyReportService.buildPdf(
        report: r,
        name: 'Nama Pengguna',
      );
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      final raw = latin1.decode(bytes);
      final pages = RegExp(r'/Type\s*/Page\b').allMatches(raw).length;
      expect(pages, greaterThanOrEqualTo(3));
      if (count <= 10) expect(pages, lessThanOrEqualTo(4));
      if (count == 400) expect(pages, greaterThan(3));
    }
  });
}
