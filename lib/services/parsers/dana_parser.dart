import '../../models/transaction_model.dart';
import '../receipt_amount.dart';

/// Parser bukti transaksi DANA dari teks hasil OCR.
/// Saat ini digunakan oleh alur OCR pembayaran QRIS.
/// Parser metode lain (misalnya Transfer) ditambahkan di file ini,
/// dengan deteksi dan ekstraksi tersendiri sesuai format bukti transaksi.
class DanaParser {
  // === OCR: deteksi format bukti transaksi saat ini ===
  static bool isMatch(String rawText) {
    String lower = rawText.toLowerCase();
    return lower.contains("id dana") ||
        lower.contains("dana protection") ||
        (lower.contains("dana") && lower.contains("total bayar"));
  }

  /// Mengubah teks hasil OCR menjadi transaksi pada alur QRIS saat ini.
  static TransactionModel parse(String rawText, List<String> cleanedLines) {
    String merchantName = "Tidak Diketahui";
    final numericVal = ReceiptAmount.read(cleanedLines) ?? 0;
    final nominalStr = ReceiptAmount.format(numericVal);

    // 2. Ambil Nama Merchant DANA (Ekstrak dari "Pembayaran ke [Merchant]")
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lower = line.toLowerCase();

      if (lower.startsWith("pembayaran ke")) {
        // Ambil teks setelah kata "Pembayaran ke"
        String candidate = line.substring(13).trim();
        if (candidate.isNotEmpty) {
          merchantName = candidate;
          break;
        }
      }
    }

    // Fallback tangkap string "XL" atau operator lain jika label meleset
    if (merchantName == "Tidak Diketahui" ||
        merchantName.toLowerCase().contains("location")) {
      for (String line in cleanedLines) {
        String lower = line.toLowerCase();
        if (lower.contains("xl jakarta") || lower.contains("xl ")) {
          merchantName = "XL";
          break;
        }
      }
    }

    String category = "Tagihan & Pulsa";
    String lowerMerchant = merchantName.toLowerCase();
    if (lowerMerchant.contains("xl") ||
        lowerMerchant.contains("telkomsel") ||
        lowerMerchant.contains("pulsa")) {
      category = "Tagihan & Pulsa";
    } else {
      category = "Belanja";
    }

    return TransactionModel(
      merchant: merchantName,
      nominalStr: nominalStr,
      dateTime: DateTime.now(),
      category: category,
      numericNominal: numericVal,
      source: "DANA",
    );
  }
}
