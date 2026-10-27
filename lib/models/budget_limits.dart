import '../services/transaction_classifier.dart';
import 'transaction_model.dart';

enum BudgetMode { flat, flexible }

class BudgetLimits {
  static const snackCategories = [
    'Jajan',
    'Makanan',
    'Minuman',
    'Belanja',
    'Umum',
  ];
  // Legacy snapshots kept for older clients/storage rules. Runtime allowances
  // always come from monthly via dailyFor/weeklyFor, including old accounts.
  final double daily;
  final double weekly;
  final double monthly;
  final List<String>? categories;
  final BudgetMode mode;

  const BudgetLimits({
    this.daily = 50000,
    this.weekly = 350000,
    this.monthly = 1500000,
    this.categories,
    this.mode = BudgetMode.flat,
  });

  static int daysInMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0).day;

  double baseDailyFor(DateTime date) => monthly / daysInMonth(date);

  /// Replays completed local calendar days. Underspending is saved, not added
  /// to future allowances; each overspend is spread over the remaining days.
  /// Today's spending therefore changes tomorrow's allowance, never today's.
  double dailyFor(DateTime date, List<TransactionModel> history) {
    final target = date.toLocal();
    var allowance = baseDailyFor(target);
    if (mode == BudgetMode.flat) return allowance;
    final totals = <int, double>{};
    for (final transaction in history) {
      final day = transaction.dateTime.toLocal();
      if (includes(transaction) &&
          day.year == target.year &&
          day.month == target.month &&
          day.day < target.day) {
        totals.update(
          day.day,
          (v) => v + transaction.numericNominal,
          ifAbsent: () => transaction.numericNominal,
        );
      }
    }
    final days = daysInMonth(target);
    for (var day = 1; day < target.day; day++) {
      final excess = (totals[day] ?? 0) - allowance;
      if (excess > 0) {
        allowance = (allowance - excess / (days - day)).clamp(0.0, monthly);
      }
    }
    return allowance;
  }

  /// Seven-day equivalent of the allowance on this date.
  double weeklyFor(DateTime date, List<TransactionModel> history) =>
      dailyFor(date, history) * 7;

  bool get isConfigured => categories != null;
  List<String> get trackedCategories =>
      categories ?? TransactionClassifier.categories;
  bool includes(TransactionModel transaction) =>
      !transaction.isIncome && trackedCategories.contains(transaction.category);
  List<TransactionModel> tracked(List<TransactionModel> history) =>
      history.where(includes).toList();

  bool get isValid =>
      [
        daily,
        weekly,
        monthly,
      ].every((value) => value.isFinite && value > 0 && value <= 1e15) &&
      trackedCategories.isNotEmpty &&
      trackedCategories.toSet().length == trackedCategories.length &&
      trackedCategories.every(TransactionClassifier.categories.contains);

  Map<String, dynamic> toMap() => {
    'daily': daily,
    'weekly': weekly,
    'monthly': monthly,
    'categories': trackedCategories,
    'mode': mode.name,
  };

  factory BudgetLimits.fromMap(Map<String, dynamic> map) {
    final rawMode = map['mode'] ?? 'flat';
    if (rawMode != 'flat' && rawMode != 'flexible') {
      throw const FormatException('Mode budget tidak valid');
    }
    final result = BudgetLimits(
      daily: (map['daily'] as num).toDouble(),
      weekly: (map['weekly'] as num).toDouble(),
      monthly: (map['monthly'] as num).toDouble(),
      mode: rawMode == 'flexible' ? BudgetMode.flexible : BudgetMode.flat,
      categories: map['categories'] == null
          ? null
          : List<String>.unmodifiable(
              (map['categories'] as List).cast<String>(),
            ),
    );
    if (!result.isValid) throw const FormatException('Budget tidak valid');
    return result;
  }
}
