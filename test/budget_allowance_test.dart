import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/budget_limits.dart';
import 'package:flutter_application_1/models/transaction_model.dart';

TransactionModel expense(
  int day,
  double amount, {
  String category = 'Jajan',
  String type = 'expense',
}) => TransactionModel(
  merchant: 'Toko',
  nominalStr: '$amount',
  numericNominal: amount,
  dateTime: DateTime(2026, 11, day),
  category: category,
  type: type,
);

void main() {
  const flexible = BudgetLimits(
    mode: BudgetMode.flexible,
    categories: ['Jajan'],
  );
  const flat = BudgetLimits(categories: ['Jajan']);

  test(
    'flat derives allowances from calendar month and ignores overspending',
    () {
      for (final date in [
        DateTime(2026, 2),
        DateTime(2028, 2),
        DateTime(2026, 11),
        DateTime(2026, 12),
      ]) {
        final daily = 1500000 / BudgetLimits.daysInMonth(date);
        expect(flat.dailyFor(date, [expense(1, 3000000)]), daily);
        expect(flat.weeklyFor(date, []), daily * 7);
      }
      expect(
        flat.dailyFor(DateTime(2026, 11, 11), [expense(10, 100000)]),
        50000,
      );
    },
  );

  test('50k overspend with 20 days left gives 47.5k from tomorrow', () {
    final history = [expense(10, 100000)];
    expect(flexible.dailyFor(DateTime(2026, 11, 10), history), 50000);
    expect(flexible.dailyFor(DateTime(2026, 11, 11), history), 47500);
    expect(flexible.weeklyFor(DateTime(2026, 11, 11), history), 332500);
    expect(flexible.dailyFor(DateTime(2026, 11, 30), history), 47500);
  });

  test(
    'subsequent excess uses adjusted allowance and calendar days remaining',
    () {
      final history = [expense(10, 100000), expense(11, 60000)];
      expect(flexible.dailyFor(DateTime(2026, 11, 11), history), 47500);
      expect(
        flexible.dailyFor(DateTime(2026, 11, 12), history),
        closeTo(47500 - 12500 / 19, 0.000001),
      );
      history.removeLast();
      expect(flexible.dailyFor(DateTime(2026, 11, 12), history), 47500);
      history.first.dateTime = DateTime(2026, 10, 10);
      expect(flexible.dailyFor(DateTime(2026, 11, 12), history), 50000);
    },
  );

  test('savings, income, unselected categories and future spending do not reduce allowance', () {
    final history = [
      expense(1, 10000),
      expense(2, 200000, type: 'income'),
      expense(3, 200000, category: 'Tagihan & Pulsa'),
      expense(20, 200000),
    ];
    expect(flexible.dailyFor(DateTime(2026, 11, 10), history), 50000);
  });

  test(
    'depletion clamps to zero and resets at new month including December',
    () {
      final history = [expense(10, 2000000), expense(30, 3000000)];
      expect(flexible.dailyFor(DateTime(2026, 11, 11), history), 0);
      expect(flexible.weeklyFor(DateTime(2026, 11, 30), history), 0);
      expect(flexible.dailyFor(DateTime(2026, 12, 1), history), 1500000 / 31);
      expect(flexible.dailyFor(DateTime(2027, 1, 1), history), 1500000 / 31);
    },
  );

  test(
    'mode persists and old budgets default to flat with monthly as source',
    () {
      expect(BudgetLimits.fromMap(flexible.toMap()).mode, BudgetMode.flexible);
      final legacy = BudgetLimits.fromMap({
        'daily': 1,
        'weekly': 2,
        'monthly': 1500000,
      });
      expect(legacy.mode, BudgetMode.flat);
      expect(legacy.dailyFor(DateTime(2026, 11, 1), []), 50000);
      expect(
        () => BudgetLimits.fromMap({...flat.toMap(), 'mode': 'unknown'}),
        throwsFormatException,
      );
    },
  );
}
