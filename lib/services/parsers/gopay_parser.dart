import '../../models/transaction_model.dart';

/// Parser bukti transaksi GoPay dari teks hasil OCR.
/// Saat ini digunakan oleh alur OCR pembayaran QRIS.
/// Parser metode lain (misalnya Transfer) ditambahkan di file ini,
/// dengan deteksi dan ekstraksi tersendiri sesuai format bukti transaksi.
class GopayParser {
  // === OCR: deteksi format bukti transaksi saat ini ===
  static bool isMatch(String rawText) {
    String lower = rawText.toLowerCase();
    return lower.contains("gopay") && (lower.contains("rincian transaksi") || lower.contains("acquirer name"));
  }

  /// Mengubah teks hasil OCR menjadi transaksi pada alur QRIS saat ini.
  static TransactionModel parse(String rawText, List<String> cleanedLines) {
    String merchantName = "Tidak Diketahui";
    String nominalStr = "Rp0";
    double numericVal = 0;
    int nominalIndex = -1;

    // ==========================================
    // 1. AMBIL NOMINAL DARI "Rp" PALING ATAS
    // ==========================================
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      if (line.toLowerCase().contains("rp")) {
        final match = RegExp(r'Rp\s?[0-9.,]+', caseSensitive: false).firstMatch(line);
        if (match != null) {
          nominalStr = match.group(0)!;
          nominalIndex = i; 
          break; 
        }
      }
    }

    String cleanNumStr = nominalStr;
    if (cleanNumStr.contains(',')) {
      cleanNumStr = cleanNumStr.split(',')[0]; 
    }
    String cleanNum = cleanNumStr.replaceAll(RegExp(r'[^0-9]'), '');
    numericVal = double.tryParse(cleanNum) ?? 0;

    // ==========================================
    // 2. PENCARIAN NAMA MERCHANT GOPAY
    // ==========================================
    if (nominalIndex != -1 && nominalIndex + 1 < cleanedLines.length) {
      String candidate = cleanedLines[nominalIndex + 1];
      if (!candidate.toLowerCase().contains("anda menyimpan") && 
          !candidate.toLowerCase().contains("jalan") &&
          !candidate.toLowerCase().contains("rincian")) {
        merchantName = candidate;
      }
    }

    if (merchantName == "Tidak Diketahui") {
      for (int i = 0; i < cleanedLines.length; i++) {
        String line = cleanedLines[i];
        String lower = line.toLowerCase();
        
        if (lower.contains("merchant name")) {
          // Perbaikan: Gunakan parameter caseSensitive: false alih-alih (?i)
          String cleanedTarget = line.replaceAll(RegExp(r'merchant name', caseSensitive: false), '').trim();
          if (cleanedTarget.length > 2) {
            merchantName = cleanedTarget;
          } 
          else if (i + 1 < cleanedLines.length) {
            merchantName = cleanedLines[i + 1];
          }
          break;
        }
      }
    }

    // ==========================================
    // 3. KATEGORI OTOMATIS
    // ==========================================
    String category = "Belanja";
    String lowerMerchant = merchantName.toLowerCase();
    if (lowerMerchant.contains("toko") || lowerMerchant.contains("mart") || lowerMerchant.contains("jgkrs")) {
      category = "Belanja";
    } else if (lowerMerchant.contains("kopi") || lowerMerchant.contains("makan") || lowerMerchant.contains("resto")) {
      category = "Makanan";
    } else {
      category = "Umum";
    }

    return TransactionModel(
      merchant: merchantName,
      nominalStr: nominalStr,
      dateTime: DateTime.now(),
      category: category,
      numericNominal: numericVal,
      source: "GoPay",
    );
  }
}
