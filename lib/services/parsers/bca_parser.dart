import '../../models/transaction_model.dart';

class BcaParser {
  // Deteksi apakah struk berasal dari BCA / m-BCA
  static bool isMatch(String rawText) {
    String lower = rawText.toLowerCase();
    return lower.contains("pembayaran qr") &&
        (lower.contains("bca") ||
            lower.contains("ref") ||
            lower.contains("rrn"));
  }

  static TransactionModel parse(String rawText, List<String> cleanedLines) {
    String merchantName = "Tidak Diketahui";
    String nominalStr = "Rp0";
    double numericVal = 0;
    DateTime parsedDate = DateTime.now(); // Default ke hari ini jika gagal

    // Pola Regex untuk mendeteksi tanggal BCA: 16/08/2026 13:56:51
    RegExp dateRegex = RegExp(
      r'(\d{2})/(\d{2})/(\d{4})\s*(?:[-–]\s*)?(\d{2}):(\d{2}):(\d{2})',
    );

    // 1. Ekstrak Tanggal & Waktu Akurat
    for (String line in cleanedLines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        int day = int.parse(match.group(1)!);
        int month = int.parse(match.group(2)!);
        int year = int.parse(match.group(3)!);
        int hour = int.parse(match.group(4)!);
        int minute = int.parse(match.group(5)!);
        int second = int.parse(match.group(6)!);
        parsedDate = DateTime(year, month, day, hour, minute, second);
        break;
      }
    }

    // 2. Ambil Nominal
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lower = line.toLowerCase();

      if (lower.contains("total pembayaran") || lower.contains("rp")) {
        final amountRegex = RegExp(r'Rp\s*[0-9][0-9.,]*', caseSensitive: false);
        final match =
            amountRegex.firstMatch(line) ??
            (lower.contains('total pembayaran') && i + 1 < cleanedLines.length
                ? amountRegex.firstMatch(cleanedLines[i + 1])
                : null);
        if (match != null) {
          nominalStr =
              'Rp${match.group(0)!.replaceFirst(RegExp(r'^Rp\s*', caseSensitive: false), '')}';
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

    // 3. Ambil Nama Merchant BCA (1 baris di bawah tanggal)
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];

      if (dateRegex.hasMatch(line)) {
        for (var j = i + 1; j < cleanedLines.length; j++) {
          String candidate = cleanedLines[j];
          if (candidate.toLowerCase() == 'bca') continue;
          if (!candidate.toLowerCase().contains("no. transaksi") &&
              !candidate.toLowerCase().contains("total")) {
            merchantName = candidate;
          }
          break;
        }
        if (merchantName != 'Tidak Diketahui') break;
      }
    }

    if (merchantName == "Tidak Diketahui") {
      for (int i = 0; i < cleanedLines.length; i++) {
        String line = cleanedLines[i];
        String lower = line.toLowerCase();
        if (!lower.contains("pembayaran qr") &&
            !lower.contains("berhasil") &&
            !lower.contains("bca") &&
            !lower.contains("total pembayaran") &&
            !lower.contains("no. transaksi") &&
            !lower.contains("dari") &&
            !lower.contains("rrn") &&
            !lower.contains("ref") &&
            !dateRegex.hasMatch(line) &&
            line.length > 3) {
          merchantName = line;
          break;
        }
      }
    }

    // 4. Kategori Otomatis
    String category = "Makanan";
    String lowerMerchant = merchantName.toLowerCase();
    if (lowerMerchant.contains("bika ambon") ||
        lowerMerchant.contains("roti") ||
        lowerMerchant.contains("kopi") ||
        lowerMerchant.contains("bakso") ||
        lowerMerchant.contains("rica")) {
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
      dateTime: parsedDate,
      category: category,
      numericNominal: numericVal,
      source: "BCA",
    );
  }
}
