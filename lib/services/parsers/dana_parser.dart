import '../../models/transaction_model.dart';

class DanaParser {
  static bool isMatch(String rawText) {
    String lower = rawText.toLowerCase();
    return lower.contains("id dana") || lower.contains("dana protection") || (lower.contains("dana") && lower.contains("total bayar"));
  }

  static TransactionModel parse(String rawText, List<String> cleanedLines) {
    String merchantName = "Tidak Diketahui";
    String nominalStr = "Rp0";
    double numericVal = 0;

    // 1. Ambil Nominal
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lower = line.toLowerCase();

      if (lower.contains("total bayar") || lower.contains("total pembayaran")) {
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

    String cleanNum = nominalStr.replaceAll(RegExp(r'[^0-9]'), '');
    numericVal = double.tryParse(cleanNum) ?? 0;

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
    if (merchantName == "Tidak Diketahui" || merchantName.toLowerCase().contains("location")) {
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
    if (lowerMerchant.contains("xl") || lowerMerchant.contains("telkomsel") || lowerMerchant.contains("pulsa")) {
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