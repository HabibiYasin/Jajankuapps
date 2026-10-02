import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/services/budget_notification_service.dart';

void main() {
  TransactionModel transaction(double amount, DateTime date) =>
      TransactionModel(
        merchant: 'Warung',
        nominalStr: '$amount',
        dateTime: date,
        category: 'Makanan',
        numericNominal: amount,
      );

  test('daily totals preserve overspending and separate calendar dates', () {
    final totals = BudgetNotificationService.dailyTotals([
      transaction(50000, DateTime(2026, 10, 1, 8)),
      transaction(12500, DateTime(2026, 10, 1, 23, 59)),
      transaction(10000, DateTime(2026, 10, 2)),
    ]);
    expect(totals, {'2026-10-01': 62500.0, '2026-10-02': 10000.0});
    expect(totals['2026-10-01']! / 50000 * 100, 125);
  });

  test('rebuilding after deletion or date edits removes stale totals', () {
    final tx = transaction(62500, DateTime(2026, 10, 1));
    tx.dateTime = DateTime(2026, 9, 30);
    expect(BudgetNotificationService.dailyTotals([tx]), {
      '2026-09-30': 62500.0,
    });
    expect(BudgetNotificationService.dailyTotals([]), isEmpty);
  });
}
