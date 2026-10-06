class SpendingProgress {
  final String period;
  final DateTime date;
  final bool monthly;
  final double spent;
  final double budget;
  final double? previousSpent;

  const SpendingProgress({
    required this.period,
    required this.date,
    required this.spent,
    required this.budget,
    this.monthly = false,
    this.previousSpent,
  });

  bool get hasBudget => budget.isFinite && budget > 0;
  double get percentage => hasBudget ? spent / budget * 100 : 0;
  String get title {
    if (!hasBudget) return 'Belum Ada Budget';
    if (percentage == 0) return 'Puasa atau lupa?';
    if (percentage <= 50) return 'Hematers';
    if (percentage <= 75) return 'Strategist';
    if (percentage <= 100) return 'Perfectionist';
    return 'Ambyar';
  }

  String get artworkKey => !hasBudget
      ? 'hematers'
      : percentage == 0
      ? 'ambyar'
      : percentage > 100
      ? 'duar'
      : title.toLowerCase();
  String get artworkAsset => 'assets/share/$artworkKey.png';

  String amountLabel({bool hideAmounts = false}) =>
      hideAmounts ? 'XX / XX' : '${rupiah(spent)} / ${rupiah(budget)}';

  String? get comparison {
    final previous = previousSpent;
    if (previous == null || !previous.isFinite || previous < 0) return null;
    final period = monthly ? 'bulan kemarin' : 'hari kemarin';
    if (spent == previous) return 'Sama dengan $period';
    if (previous == 0) {
      return 'Belum ada pengeluaran $period untuk dibandingkan';
    }
    final change = ((spent - previous).abs() / previous * 100);
    final percent = change < 1 ? '<1' : change.round().toString();
    return 'Lebih ${spent < previous ? 'hemat' : 'boros'} $percent% dari $period';
  }

  List<String> get messages => switch (title) {
    'Puasa atau lupa?' => const [
      'Belum ada jajan yang tercatat. Lagi hemat, atau belum sempat nyatet?',
      'Catatan jajan masih kosong. Kalau tadi sudah jajan, jangan lupa dicatat, ya.',
      'Belum ada pengeluaran tercatat. Semoga memang belum jajan, bukan lupa nyatet.',
      'Budget masih utuh di catatan. Coba ingat, tadi sempat beli apa?',
      'Belum ada jajan di sini. Kalau ada yang terlewat, masih bisa dicatat kok.',
    ],
    'Hematers' => const [
      'Jajan jalan, dompet tetap santai. Hematers turun tangan!',
      'Diskon boleh menggoda, saldo tetap kamu bela.',
      'Dompet masih tebal. Godaan checkout kalah mental.',
      'Budget baru kepakai dikit. Sisanya jangan diajak balas dendam, ya!',
      'Hemat boleh, pelit jangan. Kamu udah nemu titik amannya!',
    ],
    'Strategist' => const [
      'Jajan pakai taktik. Dompet bukan korban, tapi rekan tim.',
      'Budget masih terkendali. Kamu main catur, promo main petak umpet.',
      'Ada jatah buat senang-senang, ada rem buat checkout.',
      'Strategi mantap! Tinggal jangan kalah sama tulisan gratis ongkir.',
      'Jajan terukur, dompet nggak kabur. Pelatih budget approves!',
    ],
    'Perfectionist' => const [
      'Budget hampir pas! Jangan ditambah cuma biar angkanya cantik.',
      'Rapi banget ngaturnya. Excel aja pengin minta les.',
      'Jajan sudah mendekati garis finish. Rem dulu, bestie!',
      'Dompet bilang cukup. Kamu bilang: siap, bos!',
      'Presisi level sultan kalkulator. Satu checkout lagi, ceritanya beda.',
    ],
    'Ambyar' => const [
      'Wah, jajannya sudah lewat budget. Cek dulu sebelum nambah lagi, ya.',
      'Ternyata total jajannya sudah lewat batas. Yuk, lihat mana yang paling banyak.',
      'Budget sudah terlewati. Nggak apa-apa, catat dulu biar tahu habisnya ke mana.',
      'Jajannya ternyata sudah lewat batas. Yuk, cek catatannya dan atur lagi pelan-pelan.',
      'Sudah lewat budget, nih. Sebelum jajan lagi, coba lihat totalnya dulu.',
    ],
    _ => const ['Atur budget dulu, biar jajannya punya pagar pembatas.'],
  };

  String messageForVariant(int variant) => messages[variant % messages.length];
  String get message => messageForVariant(0);

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
