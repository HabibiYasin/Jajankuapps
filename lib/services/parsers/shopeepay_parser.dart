import '../../models/transaction_model.dart';

/// Parser bukti transaksi ShopeePay dari teks hasil OCR.
/// Saat ini digunakan oleh alur OCR pembayaran QRIS.
/// Parser metode lain (misalnya Transfer) ditambahkan di file ini,
/// dengan deteksi dan ekstraksi tersendiri sesuai format bukti transaksi.
class ShopeePayParser {
  // === OCR: deteksi format bukti transaksi saat ini ===
  static bool isMatch(String rawText) {
    return rawText.toLowerCase().contains("shopeepay") || rawText.toLowerCase().contains("spaylater");
  }

  /// Mengubah teks hasil OCR menjadi transaksi pada alur QRIS saat ini.
  static TransactionModel parse(String rawText, List<String> cleanedLines) {
    String merchantName = "Tidak Diketahui";
    String nominalStr = "Rp0";
    double numericVal = 0;

    // 1. Ambil Nominal Final (Mendukung Diskon/Promo)
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lower = line.toLowerCase();

      if (lower.contains("kamu membayar") || lower.contains("total pembayaran")) {
        for (int j = i; j <= i + 2 && j < cleanedLines.length; j++) {
          String targetLine = cleanedLines[j];
          if (targetLine.contains("Rp") || targetLine.contains("rp") || RegExp(r'[0-9]').hasMatch(targetLine)) {
            final match = RegExp(r'(Rp\s?[0-9.,]+|[0-9]{1,3}(\.[0-9]{3})*(,\d+)?)').firstMatch(targetLine);
            if (match != null) {
              String found = match.group(0)!;
              if (!found.contains("132005") && found.length < 12) {
                nominalStr = found.startsWith("Rp") || found.startsWith("rp") ? found : "Rp$found";
                break;
              }
            }
          }
        }
        if (nominalStr != "Rp0") break;
      }
    }

    // Normalisasi angka
    String cleanNumStr = nominalStr;
    if (cleanNumStr.contains(',')) cleanNumStr = cleanNumStr.split(',')[0];
    numericVal = double.tryParse(cleanNumStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    // 2. Ambil Nama Merchant
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lower = line.toLowerCase();
      if (lower.contains("roti o") || lower.contains("st juanda") || lower.contains("toko")) {
        merchantName = line;
        break;
      }
    }
    if (merchantName == "Tidak Diketahui") {
      for (String line in cleanedLines) {
        String lower = line.toLowerCase();
        if (!lower.contains("rp") && !lower.contains("shopeepay") && !lower.contains("berhasil") && !lower.contains("tanggal") && !lower.contains("rincian") && !lower.contains("order") && line.length > 4) {
          merchantName = line;
          break;
        }
      }
    }

    // 3. Kategori
    String category = merchantName.toLowerCase().contains("roti") || merchantName.toLowerCase().contains("kopi") ? "Makanan" : "Lifestyle";

    return TransactionModel(
      merchant: merchantName,
      nominalStr: nominalStr,
      dateTime: DateTime.now(),
      category: category,
      numericNominal: numericVal,
      source: "ShopeePay", 
    );
  }
}
