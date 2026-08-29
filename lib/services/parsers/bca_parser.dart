import '../../models/transaction_model.dart';

class BcaParser {
  // Deteksi apakah struk berasal dari BCA / m-BCA
  static bool isMatch(String rawText) {
    String lower = rawText.toLowerCase();
    return lower.contains("pembayaran qr") && (lower.contains("bca") || lower.contains("ref") || lower.contains("rrn"));
  }

  static TransactionModel parse(String rawText, List<String> cleanedLines) {
    String merchantName = "Tidak Diketahui";
    String nominalStr = "Rp0";
    double numericVal = 0;

    // 1. Ambil Nominal (Mencari baris yang mengandung "TOTAL PEMBAYARAN" atau "Rp")
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lower = line.toLowerCase();

      if (lower.contains("total pembayaran") || lower.contains("rp")) {
        final match = RegExp(r'Rp[0-9.,]+').firstMatch(line);
        if (match != null) {
          nominalStr = match.group(0)!;
          break;
        }
      }
    }

    // Normalisasi angka nominal & penanganan koma desimal (misal Rp75.000,00 -> 75000)
    String cleanNumStr = nominalStr;
    if (cleanNumStr.contains(',')) {
      cleanNumStr = cleanNumStr.split(',')[0]; // Buang bagian koma desimal di belakang
    }
    String cleanNum = cleanNumStr.replaceAll(RegExp(r'[^0-9]'), '');
    numericVal = double.tryParse(cleanNum) ?? 0;

    // 2. Ambil Nama Merchant BCA (Biasanya terletak di baris ke-3 setelah Header "Pembayaran QR BERHASIL" dan Tanggal)
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lower = line.toLowerCase();

      // Cari baris yang berisi tanggal (misal "16/08/2026"), nama merchant biasanya tepat 1 baris di bawahnya
      if (RegExp(r'\d{2}/\d{2}/\d{4}').hasMatch(line)) {
        if (i + 1 < cleanedLines.length) {
          String candidate = cleanedLines[i + 1];
          // Pastikan bukan baris nomor transaksi atau total bayar
          if (!candidate.toLowerCase().contains("no. transaksi") && !candidate.toLowerCase().contains("total")) {
            merchantName = candidate;
            break;
          }
        }
      }
    }

    // Fallback jika pola tanggal tidak terdeteksi presisi
    if (merchantName == "Tidak Diketahui") {
      for (int i = 0; i < cleanedLines.length; i++) {
        String line = cleanedLines[i];
        String lower = line.toLowerCase();
        if (!lower.contains("pembayaran qr") &&
            !lower.contains("berhasil") &&
            !lower.contains("total pembayaran") &&
            !lower.contains("no. transaksi") &&
            !lower.contains("dari") &&
            !lower.contains("rrn") &&
            !lower.contains("ref") &&
            !RegExp(r'\d{2}/\d{2}/\d{4}').hasMatch(line) &&
            line.length > 3) {
          merchantName = line;
          break;
        }
      }
    }

    // 3. Kategori Otomatis
    String category = "Makanan";
    String lowerMerchant = merchantName.toLowerCase();
    if (lowerMerchant.contains("bika ambon") || lowerMerchant.contains("roti") || lowerMerchant.contains("kopi") || lowerMerchant.contains("bakso")) {
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
    );
  }
}