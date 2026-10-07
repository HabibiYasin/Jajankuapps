class TransactionModel {
  static const incomeCategories = [
    'Gaji',
    'Uang Saku',
    'Bonus',
    'Usaha',
    'Lainnya',
  ];
  final String type;
  bool get isIncome => type == 'income';
  static const paymentMethods = ['QRIS', 'Transfer', 'VA', 'Cash', 'PayLater'];
  String paymentMethod;
  final String? cloudId;
  final String? ownerUid;
  int? id; // Tambahkan ID untuk referensi ke database
  String merchant;
  String nominalStr;
  DateTime dateTime;
  String category;
  String source; // Menampung asal aplikasi QRIS (ShopeePay, DANA, dll)
  double numericNominal;

  TransactionModel({
    this.cloudId,
    this.ownerUid,
    this.id,
    this.type = 'expense',
    this.paymentMethod = 'QRIS',
    required this.merchant,
    required this.nominalStr,
    required this.dateTime,
    required this.category,
    this.source = "QRIS Umum", // Nilai default
    required this.numericNominal,
  });

  // Getter OOP untuk format tanggal instan
  String get formattedTime {
    return "${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }
}
