import '../../models/transaction_model.dart';

class MandiriParser {
  // Deteksi apakah struk berasal dari Livin' by Mandiri
  static bool isMatch(String rawText) {
    String lower = rawText.toLowerCase();
    return lower.contains("livin'") || lower.contains("by mandiri") || (lower.contains("penerima") && lower.contains("total transaksi") && lower.contains("sumber dana"));
  }

  static TransactionModel parse(String rawText, List<String> cleanedLines) {
    String merchantName = "Tidak Diketahui";
    String nominalStr = "Rp0";
    double numericVal = 0;

    // 1. Ambil Nominal (Mencari baris "Total Transaksi" atau yang berawalan "Rp")
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lower = line.toLowerCase();

      if (lower.contains("total transaksi")) {
        // Cek baris yang sama atau baris berikutnya
        for (int j = i; j <= i + 1 && j < cleanedLines.length; j++) {
          String target = cleanedLines[j];
          if (target.contains("Rp") || target.contains("rp")) {
            final match = RegExp(r'Rp[0-9.]+').firstMatch(target);
            if (match != null) {
              nominalStr = match.group(0)!;
              break;
            }
          }
        }
        if (nominalStr != "Rp0") break;
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

    // Normalisasi angka nominal ke double
    String cleanNum = nominalStr.replaceAll(RegExp(r'[^0-9]'), '');
    numericVal = double.tryParse(cleanNum) ?? 0;

    // 2. Ambil Nama Merchant Mandiri (Label "Penerima")
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lower = line.toLowerCase();

      if (lower == "penerima" || lower.startsWith("penerima")) {
        if (i + 1 < cleanedLines.length) {
          String part1 = cleanedLines[i + 1];
          // Cek apakah baris berikutnya masih bagian nama merchant sebelum masuk ke lokasi (misal KUNINGAN)
          if (i + 2 < cleanedLines.length && !cleanedLines[i + 2].toLowerCase().contains("detail") && !cleanedLines[i + 2].toLowerCase().contains("sumber")) {
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
    if (lowerMerchant.contains("konter") || lowerMerchant.contains("pulsa") || lowerMerchant.contains("token") || lowerMerchant.contains("pdam")) {
      category = "Tagihan & Pulsa";
    } else if (lowerMerchant.contains("makan") || lowerMerchant.contains("kopi") || lowerMerchant.contains("roti")) {
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