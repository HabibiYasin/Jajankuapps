import '../services/transaction_classifier.dart';
import 'transaction_model.dart';

class BudgetLimits {
  static const snackCategories = ['Jajan', 'Makanan', 'Minuman', 'Belanja'];
  final double daily;
  final double weekly;
  final double monthly;
  final List<String>? categories;

  const BudgetLimits({
    this.daily = 50000,
    this.weekly = 350000,
    this.monthly = 1500000,
    this.categories,
  });

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
  };

  factory BudgetLimits.fromMap(Map<String, dynamic> map) {
    final result = BudgetLimits(
      daily: (map['daily'] as num).toDouble(),
      weekly: (map['weekly'] as num).toDouble(),
      monthly: (map['monthly'] as num).toDouble(),
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
