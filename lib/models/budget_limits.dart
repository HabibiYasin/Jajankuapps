class BudgetLimits {
  final double daily;
  final double weekly;
  final double monthly;

  const BudgetLimits({
    this.daily = 50000,
    this.weekly = 350000,
    this.monthly = 1500000,
  });

  bool get isValid => [
    daily,
    weekly,
    monthly,
  ].every((value) => value.isFinite && value > 0 && value <= 1e15);

  Map<String, dynamic> toMap() => {
    'daily': daily,
    'weekly': weekly,
    'monthly': monthly,
  };

  factory BudgetLimits.fromMap(Map<String, dynamic> map) {
    final result = BudgetLimits(
      daily: (map['daily'] as num).toDouble(),
      weekly: (map['weekly'] as num).toDouble(),
      monthly: (map['monthly'] as num).toDouble(),
    );
    if (!result.isValid) throw const FormatException('Budget tidak valid');
    return result;
  }
}
