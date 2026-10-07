import '../models/transaction_model.dart';
import 'transaction_classifier.dart';
import 'payment_source_detector.dart';
import 'parsers/general_parser.dart';
import 'parsers/shopeepay_parser.dart';
import 'parsers/dana_parser.dart';
import 'parsers/bca_parser.dart';
import 'parsers/bca_syariah_parser.dart';
import 'parsers/bri_parser.dart';
import 'parsers/gopay_parser.dart';
import 'parsers/mandiri_parser.dart'; // <-- Import Mandiri Parser
import 'parsers/ovo_parser.dart';
import 'parsers/jago_syariah_parser.dart';
import 'parsers/bni_parser.dart';
import 'parsers/bsi_parser.dart';

class QrisParser {
  static TransactionModel parseReceipt(String rawText) {
    final transaction = _parseReceipt(rawText);
    transaction.category = TransactionClassifier.classify(
      merchant: transaction.merchant,
      receiptText: rawText,
    ).category;
    return transaction;
  }

  static TransactionModel _parseReceipt(String rawText) {
    List<String> lines = rawText.split('\n');
    List<String> cleanedLines = lines
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final source = PaymentSourceDetector.detect(cleanedLines);
    final method = GeneralParser.detectMethod(rawText);
    // Dedicated parsers currently understand QRIS layouts only.
    if (method != 'QRIS') return GeneralParser.parse(rawText, cleanedLines);
    // A bank mentioned only as recipient/acquirer must not select its parser.
    // Retain the established Jago layout signature for OCR-damaged logos.
    bool accepts(String name) =>
        source == name || (source == null && name == 'Bank Jago');

    final transaction = _parseSpecialized(rawText, cleanedLines, accepts);
    if (transaction == null) return GeneralParser.parse(rawText, cleanedLines);

    // Keep a recognized layout's valid fields, filling missing data via fallback.
    if (transaction.numericNominal <= 0 ||
        transaction.merchant == 'Tidak Diketahui' ||
        transaction.merchant == 'Merchant Umum') {
      final fallback = GeneralParser.parse(rawText, cleanedLines);
      if (transaction.numericNominal <= 0) {
        transaction.numericNominal = fallback.numericNominal;
        transaction.nominalStr = fallback.nominalStr;
      }
      if (transaction.merchant == 'Tidak Diketahui' ||
          transaction.merchant == 'Merchant Umum') {
        transaction.merchant = fallback.merchant;
      }
    }
    // Several legacy parsers default to now even when the receipt has a date.
    transaction.dateTime =
        GeneralParser.extractDateTime(cleanedLines) ?? transaction.dateTime;
    transaction.paymentMethod = method;
    return transaction;
  }

  static TransactionModel? _parseSpecialized(
    String rawText,
    List<String> cleanedLines,
    bool Function(String) accepts,
  ) {
    if (accepts('ShopeePay') && ShopeePayParser.isMatch(rawText)) {
      return ShopeePayParser.parse(rawText, cleanedLines);
    } else if (accepts('OVO') && OvoParser.isMatch(rawText)) {
      return OvoParser.parse(rawText, cleanedLines);
    } else if (accepts('Bank Jago') && JagoSyariahParser.isMatch(rawText)) {
      return JagoSyariahParser.parse(rawText, cleanedLines);
    } else if (accepts('BNI') && BniParser.isMatch(rawText)) {
      return BniParser.parse(rawText, cleanedLines);
    } else if (accepts('BSI') && BsiParser.isMatch(rawText)) {
      return BsiParser.parse(rawText, cleanedLines);
    } else if (accepts('DANA') && DanaParser.isMatch(rawText)) {
      return DanaParser.parse(rawText, cleanedLines);
    } else if (accepts('BCA Syariah') &&
        rawText.toLowerCase().contains('bca syariah')) {
      return BcaSyariahParser.parse(rawText, cleanedLines);
    } else if (accepts('BCA') && BcaParser.isMatch(rawText)) {
      return BcaParser.parse(rawText, cleanedLines);
    } else if (accepts('BRI') && BriParser.isMatch(rawText)) {
      return BriParser.parse(rawText, cleanedLines);
    } else if (accepts('Bank Mandiri') && MandiriParser.isMatch(rawText)) {
      return MandiriParser.parse(rawText, cleanedLines);
    } else if (accepts('GoPay') && GopayParser.isMatch(rawText)) {
      return GopayParser.parse(rawText, cleanedLines);
    }
    return null;
  }
}
