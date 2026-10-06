import 'transaction_model.dart';

class BudgetTotals {
  final double tracked;
  final double other;
  const BudgetTotals({required this.tracked, required this.other});

  factory BudgetTotals.forPeriod(
    List<TransactionModel> history,
    List<String> categories,
    DateTime period, {
    bool monthly = false,
  }) {
    var tracked = 0.0;
    var other = 0.0;
    final target = period.toLocal();
    for (final transaction in history) {
      final date = transaction.dateTime.toLocal();
      if (date.year != target.year ||
          date.month != target.month ||
          (!monthly && date.day != target.day)) {
        continue;
      }
      if (categories.contains(transaction.category)) {
        tracked += transaction.numericNominal;
      } else {
        other += transaction.numericNominal;
      }
    }
    return BudgetTotals(tracked: tracked, other: other);
  }
}
