import '../../models/transaction_model.dart';
import '../receipt_amount.dart';

/// Parser bukti transaksi BCA Syariah dari teks hasil OCR.
/// Saat ini digunakan oleh alur OCR pembayaran QRIS.
/// Parser metode lain (misalnya Transfer) ditambahkan di file ini,
/// dengan deteksi dan ekstraksi tersendiri sesuai format bukti transaksi.
class BcaSyariahParser {
  // === OCR: deteksi format bukti transaksi saat ini ===
  static bool isMatch(String rawText) {
    final lower = rawText.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return RegExp(r'\bbca\s*syar(?:iah|nah)\b').hasMatch(lower) ||
        hasLayoutSignature(rawText);
  }

  static bool hasLayoutSignature(String rawText) {
    final lower = rawText.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return lower.contains('sumber dana') &&
        lower.contains('tujuan') &&
        lower.contains('total transaksi');
  }

  /// Mengubah teks hasil OCR menjadi transaksi pada alur QRIS saat ini.
  static TransactionModel parse(String rawText, List<String> cleanedLines) {
    String merchantName = "Tidak Diketahui";
    final numericVal = ReceiptAmount.read(cleanedLines) ?? 0;
    final nominalStr = ReceiptAmount.format(numericVal);

    // 2. Ambil nama merchant dari label Tujuan, inline atau baris berikutnya.
    final destination = RegExp(
      r'^tujuan\b\s*[:\-]?\s*(.*)$',
      caseSensitive: false,
    );
    for (int i = 0; i < cleanedLines.length; i++) {
      final match = destination.firstMatch(cleanedLines[i]);
      if (match == null) continue;
      final inline = match.group(1)!.trim();
      final candidate = inline.isNotEmpty
          ? inline
          : (i + 1 < cleanedLines.length ? cleanedLines[i + 1] : '');
      if (candidate.length > 2 &&
          RegExp(r'[a-z]', caseSensitive: false).hasMatch(candidate) &&
          !RegExp(
            r'^(?:lokasi|total|nominal|sumber|tanggal|waktu|status|transaksi|no\.?|nomor|rp)\b',
            caseSensitive: false,
          ).hasMatch(candidate)) {
        merchantName = candidate;
        break;
      }
    }

    // Fallback jika masih belum ketemu
    if (merchantName == "Tidak Diketahui" ||
        merchantName == "Transaksi Berhasil") {
      for (int i = 0; i < cleanedLines.length; i++) {
        String line = cleanedLines[i];
        String lower = line.toLowerCase();
        // Cari baris yang mirip nama toko (mengandung huruf kapital semua atau kata khas)
        if (lower.contains("ayam") ||
            lower.contains("warung") ||
            lower.contains("toko") ||
            lower.contains("kopi")) {
          merchantName = line;
          break;
        }
      }
    }

    // Bersihkan embel-embel lokasi
    if (merchantName.contains(" JAKARTA")) {
      merchantName = merchantName.split(" JAKARTA")[0].trim();
    }

    // 3. Kategori Otomatis
    String category = "Makanan";
    String lowerMerchant = merchantName.toLowerCase();
    if (lowerMerchant.contains("ayam") ||
        lowerMerchant.contains("warung") ||
        lowerMerchant.contains("makan") ||
        lowerMerchant.contains("kopi") ||
        lowerMerchant.contains("roti")) {
      category = "Makanan";
    } else if (lowerMerchant.contains("indomaret") ||
        lowerMerchant.contains("alfamart")) {
      category = "Belanja";
    } else {
      category = "Lifestyle";
    }

    return TransactionModel(
      merchant: merchantName,
      nominalStr: nominalStr,
      dateTime: DateTime.now(),
      category: category,
      numericNominal: numericVal,
      source: "BCA Syariah",
    );
  }
}
