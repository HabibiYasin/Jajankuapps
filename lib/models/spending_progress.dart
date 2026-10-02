class SpendingProgress {
  final String period;
  final DateTime date;
  final bool monthly;
  final double spent;
  final double budget;

  const SpendingProgress({
    required this.period,
    required this.date,
    required this.spent,
    required this.budget,
    this.monthly = false,
  });

  bool get hasBudget => budget.isFinite && budget > 0;
  double get percentage => hasBudget ? spent / budget * 100 : 0;
  String get title {
    if (!hasBudget) return 'Belum Ada Budget';
    if (percentage <= 50) return 'Hematers';
    if (percentage <= 75) return 'Strategist';
    if (percentage <= 100) return 'Perfectionist';
    return 'Budget Buster';
  }

  String get message {
    if (!hasBudget) return 'Atur budget untuk melihat progres pengeluaranmu.';
    if (percentage <= 50) {
      return 'Hematnya juara! Pertahankan kebiasaan baikmu.';
    }
    if (percentage <= 75) {
      return 'Strategi belanjamu mantap. Tetap jaga budgetmu!';
    }
    if (percentage <= 100) {
      return 'Budget terkelola! Yuk, tetap belanja dengan bijak.';
    }
    return 'Budget terlewati. Yuk, evaluasi dan atur langkah berikutnya!';
  }

  String get dateLabel {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${monthly ? '' : '${date.day} '}${months[date.month - 1]} ${date.year}';
  }

  static String rupiah(double value) =>
      'Rp ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')}';
}
