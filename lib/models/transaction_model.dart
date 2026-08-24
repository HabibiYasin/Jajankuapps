class TransactionModel {
  String merchant;
  String nominalStr;
  DateTime dateTime;
  String category;
  double numericNominal;

  TransactionModel({
    required this.merchant,
    required this.nominalStr,
    required this.dateTime,
    required this.category,
    required this.numericNominal,
  });

  // Getter OOP untuk format tanggal instan
  String get formattedTime {
    return "${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }
}