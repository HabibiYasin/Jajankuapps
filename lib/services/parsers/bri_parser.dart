import '../../models/transaction_model.dart';

class BriParser {
  static bool isMatch(String rawText) {
    String lower = rawText.toLowerCase();
    return lower.contains("pt. bank rakyat indonesia") || 
           lower.contains("brimo") || 
           lower.contains("kantor pusat bri") || 
           (lower.contains("sumber dana") && lower.contains("bri"));
  }

  static TransactionModel parse(String rawText, List<String> cleanedLines) {
    String merchantName = "Tidak Diketahui";
    String nominalStr = "Rp0";
    double numericVal = 0;

    // 1. AMBIL NOMINAL DARI "Rp" PALING ATAS
    for (String line in cleanedLines) {
      if (line.contains("Rp") || line.contains("rp")) {
        final match = RegExp(r'Rp[0-9.]+').firstMatch(line);
        if (match != null) {
          nominalStr = match.group(0)!;
          break; // Ambil yang paling atas/pertama ketemu
        }
      }
    }

    String cleanNum = nominalStr.replaceAll(RegExp(r'[^0-9]'), '');
    numericVal = double.tryParse(cleanNum) ?? 0;

    // 2. AMBIL NAMA MERCHANT TEPAT DI ATAS KATA "CATATAN"
    for (int i = 0; i < cleanedLines.length; i++) {
      String lowerLine = cleanedLines[i].toLowerCase();
      
      // Jika mendeteksi kata "Catatan", ambil baris tepat di atasnya
      if (lowerLine.contains("catatan") && i > 0) {
        String candidate = cleanedLines[i - 1];
        // Pastikan bukan label atau nominal
        if (!candidate.toLowerCase().contains("rp") && candidate.length > 3) {
          merchantName = candidate;
          break;
        }
      }
    }

    // Fallback cadangan jika posisi "catatan" meleset
    if (merchantName == "Tidak Diketahui") {
      for (int i = 0; i < cleanedLines.length; i++) {
        String line = cleanedLines[i];
        if (line.contains("Konter") || line.contains("MbI365739")) {
          merchantName = line;
          break;
        }
      }
    }

    // 3. KATEGORI OTOMATIS
    String category = "Tagihan & Pulsa";
    String lowerMerchant = merchantName.toLowerCase();
    if (lowerMerchant.contains("konter") || lowerMerchant.contains("pulsa") || lowerMerchant.contains("token") || lowerMerchant.contains("pdam")) {
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
    );
  }
}