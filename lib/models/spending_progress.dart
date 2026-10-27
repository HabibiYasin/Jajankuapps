class SpendingProgress {
  final String period;
  final DateTime date;
  final bool monthly;
  final double spent;
  final double budget;
  final bool budgetExhausted;
  final double? previousSpent;

  const SpendingProgress({
    required this.period,
    required this.date,
    required this.spent,
    required this.budget,
    this.budgetExhausted = false,
    this.monthly = false,
    this.previousSpent,
  });

  bool get hasBudget => budget.isFinite && budget > 0;
  double get percentage => hasBudget ? spent / budget * 100 : 0;
  String get title {
    if (budgetExhausted) return 'Budget Habis';
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
      return 'Lebih boros ${rupiah(spent)} dari $period. ${monthly ? 'Bulan kemarin' : 'Kemarin'} belum nyatet kali.';
    }
    final change = ((spent - previous).abs() / previous * 100);
    final percent = change < 1 ? '<1' : change.round().toString();
    return 'Lebih ${spent < previous ? 'hemat' : 'boros'} $percent% dari $period';
  }

  String? comparisonLabel({bool hideAmounts = false}) {
    final value = comparison;
    return hideAmounts && previousSpent == 0
        ? value?.replaceAll(rupiah(spent), 'XX')
        : value;
  }

  List<String> get messages => switch (title) {
    'Budget Habis' => const [
      'Jatah budget hari ini sudah habis setelah penyesuaian pengeluaran sebelumnya. Tahan dulu pengeluaran berikutnya, ya.',
    ],
    'Puasa atau lupa?' => const [
      'Belum ada jajan yang tercatat. Lagi hemat, atau belum sempat nyatet?',
      'Catatan jajan masih kosong. Kalau tadi sudah jajan, jangan lupa dicatat, ya.',
      'Belum ada pengeluaran tercatat. Semoga memang belum jajan, bukan lupa nyatet.',
      'Budget masih utuh di catatan. Coba ingat, tadi sempat beli apa?',
      'Belum ada jajan di sini. Kalau ada yang terlewat, masih bisa dicatat kok.',
      'Catatan masih sepi. Tim bawa bekal atau tim lupa input?',
      'Angkanya masih nol. Cek dulu, es teh tadi sudah masuk belum?',
      'Jajan belum terdeteksi. Dompet aman, catatan juga harus aman.',
      'Belum ada jejak checkout. Kalau sudah belanja, tinggal catat aja.',
      'Nol pengeluaran tercatat. Kalau memang belum jajan, nikmati dulu jedanya.',
    ],
    'Hematers' => const [
      'Jajan jalan, dompet tetap santai. Hematers turun tangan!',
      'Diskon boleh menggoda, saldo tetap kamu bela.',
      'Dompet masih tebal. Godaan checkout kalah mental.',
      'Budget baru kepakai dikit. Sisanya jangan diajak balas dendam, ya!',
      'Hemat boleh, pelit jangan. Kamu udah nemu titik amannya!',
      'Jajan secukupnya, senyum sepuasnya. Dompet ikut bahagia.',
      'Promo lewat, kamu tetap kalem. Pertahanan dompet lagi bagus!',
      'Pengeluaran masih adem. Es teh aja kalah sejuk.',
      'Kamu yang pegang kendali, keranjang belanja cukup antre dulu.',
      'Jatah masih lega. Simpan ruang buat kebutuhan berikutnya, ya.',
    ],
    'Strategist' => const [
      'Jajan pakai taktik. Dompet bukan korban, tapi rekan tim.',
      'Budget masih terkendali. Kamu main catur, promo main petak umpet.',
      'Ada jatah buat senang-senang, ada rem buat checkout.',
      'Strategi mantap! Tinggal jangan kalah sama tulisan gratis ongkir.',
      'Jajan terukur, dompet nggak kabur. Pelatih budget approves!',
      'Tahu kapan jajan, tahu kapan tahan. Ini baru strategi matang.',
      'Keranjang boleh penuh ide, checkout tetap pakai hitungan.',
      'Ada rencana di balik tiap jajan. Dompet suka cara mainmu.',
      'Budget masih di jalur. Pertahankan ritmenya sampai akhir.',
      'Keinginan boleh banyak, prioritas tetap nomor satu.',
    ],
    'Perfectionist' => const [
      'Budget hampir pas! Jangan ditambah cuma biar angkanya cantik.',
      'Rapi banget ngaturnya. Excel aja pengin minta les.',
      'Jajan sudah mendekati garis finish. Rem dulu, bestie!',
      'Dompet bilang cukup. Kamu bilang: siap, bos!',
      'Presisi level sultan kalkulator. Satu checkout lagi, ceritanya beda.',
      'Budget sudah mepet garis. Saatnya kasih jeda buat dompet.',
      'Hampir mentok, masih terkontrol. Wishlist bisa tunggu giliran.',
      'Sisa budget makin tipis. Pilih yang perlu, sisanya simpan dulu.',
      'Sudah dekat batas. Gratis ongkir juga tetap keluar uang, bestie.',
      'Finishing rapi dimulai dari berani bilang: cukup dulu.',
    ],
    'Ambyar' => const [
      'Wah, jajannya sudah lewat budget. Cek dulu sebelum nambah lagi, ya.',
      'Ternyata total jajannya sudah lewat batas. Yuk, lihat mana yang paling banyak.',
      'Budget sudah terlewati. Nggak apa-apa, catat dulu biar tahu habisnya ke mana.',
      'Jajannya ternyata sudah lewat batas. Yuk, cek catatannya dan atur lagi pelan-pelan.',
      'Sudah lewat budget, nih. Sebelum jajan lagi, coba lihat totalnya dulu.',
      'Dompet minta jeda. Yuk, urutkan lagi mana yang paling perlu.',
      'Budget terlewat, rencana bisa diperbaiki. Mulai dari catatan yang lengkap.',
      'Checkout-nya kebablasan. Tarik napas, cek total, lalu atur langkah berikutnya.',
      'Angkanya bikin kaget? Pelan-pelan cek jajan yang paling sering muncul.',
      'Lewat batas bukan akhir cerita. Catatan ini bisa jadi bekal atur budget lagi.',
    ],
    _ => const [
      'Atur budget dulu, biar jajannya punya pagar pembatas.',
      'Jajan enak, rencana juga perlu. Tentukan budget pertamamu, yuk.',
      'Biar tahu kapan gas dan kapan rem, pasang batas jajan dulu.',
      'Budget belum diatur. Mulai dari angka yang nyaman buat kebutuhanmu.',
      'Kasih dompet petunjuk arah. Atur budget sebelum jajan berikutnya.',
      'Catat sudah, batasnya menyusul. Yuk, tentukan jatah jajanmu.',
      'Mau jajan lebih tenang? Mulai dengan budget yang masuk akal.',
      'Rencana kecil dulu: tentukan berapa yang mau kamu sisihkan buat jajan.',
      'Dompet juga butuh rencana. Pasang budget, lalu pantau bareng.',
      'Belum ada patokan jajan. Atur budget supaya progresnya kelihatan.',
    ],
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
