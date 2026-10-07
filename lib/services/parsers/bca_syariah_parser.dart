import '../../models/transaction_model.dart';

/// Parser bukti transaksi BCA Syariah dari teks hasil OCR.
/// Saat ini digunakan oleh alur OCR pembayaran QRIS.
/// Parser metode lain (misalnya Transfer) ditambahkan di file ini,
/// dengan deteksi dan ekstraksi tersendiri sesuai format bukti transaksi.
class BcaSyariahParser {
  // === OCR: deteksi format bukti transaksi saat ini ===
  static bool isMatch(String rawText) {
    String lower = rawText.toLowerCase();
    return lower.contains("bca syariah") || (lower.contains("sumber dana") && lower.contains("tujuan") && lower.contains("total transaksi"));
  }

  /// Mengubah teks hasil OCR menjadi transaksi pada alur QRIS saat ini.
  static TransactionModel parse(String rawText, List<String> cleanedLines) {
    String merchantName = "Tidak Diketahui";
    String nominalStr = "Rp0";
    double numericVal = 0;

    // 1. Ambil Nominal
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lower = line.toLowerCase();

      if (lower.contains("total transaksi") || lower.contains("nominal")) {
        final match = RegExp(r'Rp\s?[0-9.,]+').firstMatch(line);
        if (match != null) {
          nominalStr = match.group(0)!;
          break;
        }
      }
    }

    if (nominalStr == "Rp0") {
      for (String line in cleanedLines) {
        if (line.toLowerCase().startsWith("rp")) {
          nominalStr = line;
          break;
        }
      }
    }

    // Normalisasi angka nominal
    String cleanNumStr = nominalStr;
    if (cleanNumStr.contains(',')) {
      cleanNumStr = cleanNumStr.split(',')[0];
    }
    String cleanNum = cleanNumStr.replaceAll(RegExp(r'[^0-9]'), '');
    numericVal = double.tryParse(cleanNum) ?? 0;

    // 2. Ambil Nama Merchant (Pencarian lebih agresif untuk label "Tujuan")
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lower = line.toLowerCase();

      // Cek baris yang mengandung kata "tujuan"
      if (lower.contains("tujuan")) {
        // Jika nama merchant tergabung dalam satu baris yang sama setelah kata "tujuan"
        if (line.contains("Tujuan")) {
          // Coba split berdasarkan spasi atau kata Tujuan jika formatnya "Tujuan   WARUNG AYAM SOGIL"
          String cleaned = line.replaceAll(RegExp(r'tujuan', caseSensitive: false), '').trim();
          if (cleaned.isNotEmpty && cleaned.length > 2) {
            merchantName = cleaned;
            break;
          }
        }
        
        // Atau jika posisinya berada tepat di baris berikutnya
        if (i + 1 < cleanedLines.length) {
          String candidate = cleanedLines[i + 1];
          // Pastikan bukan label lain seperti Lokasi Merchant
          if (!candidate.toLowerCase().contains("lokasi")) {
            merchantName = candidate;
            break;
          }
        }
      }
    }

    // Fallback jika masih belum ketemu
    if (merchantName == "Tidak Diketahui" || merchantName == "Transaksi Berhasil") {
      for (int i = 0; i < cleanedLines.length; i++) {
        String line = cleanedLines[i];
        String lower = line.toLowerCase();
        // Cari baris yang mirip nama toko (mengandung huruf kapital semua atau kata khas)
        if (lower.contains("ayam") || lower.contains("warung") || lower.contains("toko") || lower.contains("kopi")) {
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
    if (lowerMerchant.contains("ayam") || lowerMerchant.contains("warung") || lowerMerchant.contains("makan") || lowerMerchant.contains("kopi") || lowerMerchant.contains("roti")) {
      category = "Makanan";
    } else if (lowerMerchant.contains("indomaret") || lowerMerchant.contains("alfamart")) {
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
