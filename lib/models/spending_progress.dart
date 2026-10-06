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
    if (percentage == 0) return 'Ambyar';
    if (percentage <= 50) return 'Hematers';
    if (percentage <= 75) return 'Strategist';
    if (percentage <= 100) return 'Perfectionist';
    return 'Duar';
  }

  String get artworkAsset =>
      'assets/share/${hasBudget ? title.toLowerCase() : 'hematers'}.png';

  List<String> get messages => switch (title) {
    'Ambyar' => const [
      'Nol jajan! Dompet aman, abang cilok kehilangan pelanggan.',
      'Pengeluaran nol. Kamu lagi hemat atau lupa nyatet, nih?',
      'Dompet belum disentuh. QRIS sampai nanya: kita masih temenan?',
      'Jajan belum mulai, dramanya udah Ambyar duluan.',
      'Nol rupiah keluar. Dompet lagi cuti dari dunia perjajanan.',
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
    'Duar' => const [
      'Duar! Budget jebol, dompet minta time-out.',
      'Checkout-nya lancar. Dompetnya yang buffering.',
      'Budget sudah lewat garis. Yuk, ajak dompet pulang dulu.',
      'Promo menang ronde ini. Besok kita comeback pakai rem!',
      'Dompet habis ikut konser checkout. Saatnya istirahat dulu.',
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
