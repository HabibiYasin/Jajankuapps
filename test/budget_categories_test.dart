import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/budget_limits.dart';
import 'package:flutter_application_1/models/budget_totals.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/services/budget_notification_service.dart';
import 'package:flutter_application_1/services/transaction_classifier.dart';

TransactionModel expense(String category, double amount, DateTime date) =>
    TransactionModel(
      merchant: 'Toko',
      nominalStr: '$amount',
      dateTime: date,
      category: category,
      numericNominal: amount,
    );

void main() {
  test('legacy budgets preserve limits and require category setup', () {
    final legacy = BudgetLimits.fromMap({
      'daily': 75000,
      'weekly': 400000,
      'monthly': 2000000,
    });
    expect(legacy.daily, 75000);
    expect(legacy.isConfigured, false);
    expect(legacy.trackedCategories, TransactionClassifier.categories);
    final saved = BudgetLimits.fromMap(legacy.toMap());
    expect(saved.isConfigured, true);
    expect(saved.monthly, 2000000);
  });

  test('snack budget excludes bills without removing transactions', () {
    final date = DateTime(2026, 10, 6);
    final history = [
      expense('Jajan', 10000, date),
      expense('Makanan', 20000, date),
      expense('Minuman', 5000, date),
      expense('Belanja', 15000, date),
      expense('Tagihan & Pulsa', 100000, date),
      expense('Transportasi', 30000, DateTime(2026, 10, 5)),
      expense('Tagihan & Pulsa', 70000, DateTime(2026, 9, 6)),
      expense('Umum', 90000, DateTime(2025, 10, 6)),
    ];
    const limits = BudgetLimits(categories: BudgetLimits.snackCategories);
    final daily = BudgetTotals.forPeriod(
      history,
      limits.trackedCategories,
      date,
    );
    final monthly = BudgetTotals.forPeriod(
      history,
      limits.trackedCategories,
      date,
      monthly: true,
    );
    expect(daily.tracked, 50000);
    expect(daily.other, 100000);
    expect(monthly.tracked, 50000);
    expect(monthly.other, 130000);
    expect(history, hasLength(8));
    expect(BudgetNotificationService.dailyTotals(limits.tracked(history)), {
      '2026-10-06': 50000,
    });
    final all = BudgetTotals.forPeriod(
      history,
      TransactionClassifier.categories,
      date,
    );
    expect(all.tracked, 150000);
    expect(all.other, 0);
    history.first.category = 'Tagihan & Pulsa';
    expect(
      BudgetTotals.forPeriod(history, limits.trackedCategories, date).tracked,
      40000,
    );
  });

  test('category settings reject empty, unknown and duplicate categories', () {
    for (final categories in <List<String>>[
      [],
      ['admin'],
      ['Jajan', 'Jajan'],
    ]) {
      expect(BudgetLimits(categories: categories).isValid, false);
    }
    expect(
      const BudgetLimits(categories: BudgetLimits.snackCategories).isValid,
      true,
    );
  });
}
