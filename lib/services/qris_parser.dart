import '../models/transaction_model.dart';
import 'parsers/shopeepay_parser.dart';
import 'parsers/dana_parser.dart';
import 'parsers/bca_parser.dart';
import 'parsers/bca_syariah_parser.dart';
import 'parsers/bri_parser.dart';
import 'parsers/mandiri_parser.dart'; // <-- Import Mandiri Parser

class QrisParser {
  static TransactionModel parseReceipt(String rawText) {
    List<String> lines = rawText.split('\n');
    List<String> cleanedLines = lines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // ROUTER BERBASIS APLIKASI
    if (ShopeePayParser.isMatch(rawText)) {
      return ShopeePayParser.parse(rawText, cleanedLines);
    } else if (DanaParser.isMatch(rawText)) {
      return DanaParser.parse(rawText, cleanedLines);
    } else if (BcaParser.isMatch(rawText)) {
      return BcaParser.parse(rawText, cleanedLines);
    } else if (BcaSyariahParser.isMatch(rawText)) {
      return BcaSyariahParser.parse(rawText, cleanedLines);
    } else if (BriParser.isMatch(rawText)) {
      return BriParser.parse(rawText, cleanedLines);
    } else if (MandiriParser.isMatch(rawText)) {
      return MandiriParser.parse(rawText, cleanedLines);
    }

    // Fallback jika belum terdaftar
    return TransactionModel(
      merchant: "Merchant Umum",
      nominalStr: "Rp0",
      dateTime: DateTime.now(),
      category: "Umum",
      numericNominal: 0,
    );
  }
}