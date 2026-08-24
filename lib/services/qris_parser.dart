import '../models/transaction_model.dart';

class QrisParser {
  static TransactionModel parseReceipt(String rawText) {
    String merchantName = "Tidak Diketahui";
    String nominal = "Rp0";
    double numericVal = 0;
    DateTime now = DateTime.now();
    String category = "Umum";

    List<String> lines = rawText.split('\n');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      if (line.toLowerCase().contains("terbayar ke") || line.toLowerCase().contains("kamu membayar")) {
        if (i + 1 < lines.length) {
          merchantName = lines[i + 1].trim();
          String lowerMerchant = merchantName.toLowerCase();

          if (lowerMerchant.contains("cilok") || lowerMerchant.contains("siomay") || lowerMerchant.contains("dimsum") || lowerMerchant.contains("snack") || lowerMerchant.contains("cilor") || lowerMerchant.contains("es krim") || lowerMerchant.contains("martabak") || lowerMerchant.contains("batagor") || lowerMerchant.contains("pentol")) {
            category = "Jajan";
          } else if (lowerMerchant.contains("kopi") || lowerMerchant.contains("teh") || lowerMerchant.contains("boba") || lowerMerchant.contains("jus") || lowerMerchant.contains("es ") || lowerMerchant.contains("drink") || lowerMerchant.contains("cafe")) {
            category = "Minuman";
          } else if (lowerMerchant.contains("roti") || lowerMerchant.contains("nasi") || lowerMerchant.contains("bakso") || lowerMerchant.contains("mie") || lowerMerchant.contains("ayam") || lowerMerchant.contains("soto") || lowerMerchant.contains("sate") || lowerMerchant.contains("gulung") || lowerMerchant.contains("makan") || lowerMerchant.contains("resto") || lowerMerchant.contains("warung")) {
            category = "Makanan";
          } else if (lowerMerchant.contains("toko") || lowerMerchant.contains("store") || lowerMerchant.contains("shop") || lowerMerchant.contains("mart") || lowerMerchant.contains("supermarket") || lowerMerchant.contains("grosir")) {
            category = "Belanja";
          } else {
            category = "Lifestyle";
          }
        }
      }

      if (line.startsWith("Rp") && nominal == "Rp0") {
        if (i > 2) {
          nominal = line;
          String cleanNum = nominal.replaceAll(RegExp(r'[^0-9]'), '');
          numericVal = double.tryParse(cleanNum) ?? 0;
        }
      }
    }

    return TransactionModel(
      merchant: merchantName,
      nominalStr: nominal,
      dateTime: now,
      category: category,
      numericNominal: numericVal,
    );
  }
}