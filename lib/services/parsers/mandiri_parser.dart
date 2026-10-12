import '../../models/transaction_model.dart';
import '../receipt_amount.dart';

/// Parser bukti transaksi Mandiri / Livin' dari teks hasil OCR.
/// Saat ini digunakan oleh alur OCR pembayaran QRIS.
/// Parser metode lain (misalnya Transfer) ditambahkan di file ini,
/// dengan deteksi dan ekstraksi tersendiri sesuai format bukti transaksi.
class MandiriParser {
  // === OCR: deteksi format bukti transaksi saat ini ===
  // Deteksi apakah struk berasal dari Livin' by Mandiri
  static bool isMatch(String rawText) {
    String lower = rawText.toLowerCase();
    return lower.contains("livin'") ||
        lower.contains("by mandiri") ||
        (lower.contains("penerima") &&
            lower.contains("total transaksi") &&
            lower.contains("sumber dana"));
  }

  /// Mengubah teks hasil OCR menjadi transaksi pada alur QRIS saat ini.
  static TransactionModel parse(String rawText, List<String> cleanedLines) {
    String merchantName = "Tidak Diketahui";
    final numericVal = ReceiptAmount.read(cleanedLines) ?? 0;
    final nominalStr = ReceiptAmount.format(numericVal);

    // 2. Ambil Nama Merchant Mandiri (Label "Penerima")
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lower = line.toLowerCase();

      if (lower == "penerima" || lower.startsWith("penerima")) {
        final inline = line
            .replaceFirst(
              RegExp(r'^penerima\b\s*:?\s*', caseSensitive: false),
              '',
            )
            .trim();
        if (inline.isNotEmpty) {
          merchantName = inline;
          break;
        }
        if (i + 1 < cleanedLines.length) {
          String part1 = cleanedLines[i + 1];
          // Cek apakah baris berikutnya masih bagian nama merchant sebelum masuk ke lokasi (misal KUNINGAN)
          if (i + 2 < cleanedLines.length &&
              !cleanedLines[i + 2].toLowerCase().contains("detail") &&
              !cleanedLines[i + 2].toLowerCase().contains("sumber")) {
            // Jika baris berikutnya adalah kota/lokasi, ambil part1 saja
            merchantName = part1;
          } else {
            merchantName = part1;
          }
          break;
        }
      }
    }

    // Fallback pencarian merchant jika label "Penerima" terlewat
    if (merchantName == "Tidak Diketahui") {
      for (int i = 0; i < cleanedLines.length; i++) {
        String line = cleanedLines[i];
        String lower = line.toLowerCase();
        if (!lower.contains("livin") &&
            !lower.contains("berhasil") &&
            !lower.contains("total transaksi") &&
            !lower.contains("sumber dana") &&
            !lower.contains("bank mandiri") &&
            !lower.contains("detail transaksi") &&
            !RegExp(r'\d{2}\s\w{3}\s\d{4}').hasMatch(line) &&
            line.length > 3) {
          merchantName = line;
          break;
        }
      }
    }

    // 3. Kategori Otomatis
    String category = "Tagihan & Pulsa";
    String lowerMerchant = merchantName.toLowerCase();
    if (lowerMerchant.contains("konter") ||
        lowerMerchant.contains("pulsa") ||
        lowerMerchant.contains("token") ||
        lowerMerchant.contains("pdam")) {
      category = "Tagihan & Pulsa";
    } else if (lowerMerchant.contains("makan") ||
        lowerMerchant.contains("kopi") ||
        lowerMerchant.contains("roti")) {
      category = "Makanan";
    } else {
      category = "Belanja";
    }

    return TransactionModel(
      merchant: merchantName,
      nominalStr: nominalStr,
      dateTime: DateTime.now(),
      category: category,
      numericNominal: numericVal,
      source: "Livin' by Mandiri",
    );
  }
}
