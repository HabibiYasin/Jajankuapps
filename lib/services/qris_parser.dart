import '../models/transaction_model.dart';

class QrisParser {
  static TransactionModel parseReceipt(String rawText) {
    String merchantName = "Tidak Diketahui";
    String nominal = "Rp0";
    double numericVal = 0;
    DateTime now = DateTime.now();
    String category = "Umum";

    List<String> lines = rawText.split('\n');
    List<String> cleanedLines = lines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lowerLine = line.toLowerCase();

      // 1. Deteksi Nominal (biasanya ada awalan Rp)
      if (line.startsWith("Rp") && nominal == "Rp0") {
        nominal = line;
        String cleanNum = nominal.replaceAll(RegExp(r'[^0-9]'), '');
        numericVal = double.tryParse(cleanNum) ?? 0;
      }
    }

    // 2. Pencarian Nama Merchant yang Lebih Spesifik untuk ShopeePay / e-Wallet
    for (int i = 0; i < cleanedLines.length; i++) {
      String line = cleanedLines[i];
      String lower = line.toLowerCase();

      // Nama merchant di ShopeePay biasanya terletak di antara nominal utama / status sukses 
      // dan rincian "Kamu Membayar" atau "Total Pembelian"
      if (lower.contains("kamu membayar") || lower.contains("total pembelian")) {
        // Cek baris di atasnya yang potensial menjadi nama merchant
        if (i - 1 >= 0) {
          String candidate = cleanedLines[i - 1];
          // Pastikan kandidat bukan nominal, bukan tanggal, dan bukan teks sistem
          if (!candidate.toLowerCase().contains("rp") && 
              !candidate.toLowerCase().contains("2026") && 
              !candidate.toLowerCase().contains("berhasil") &&
              candidate.length > 2) {
            merchantName = candidate;
            break;
          }
        }
      }
    }

    // 3. Fallback jika masih belum ketemu, cari baris yang mengandung "toko", "store", atau format nama unik
    if (merchantName == "Tidak Diketahui" || merchantName.contains(":")) {
      for (var line in cleanedLines) {
        String lower = line.toLowerCase();
        if (lower.contains("toko ") || lower.contains("store ") || lower.contains("shop ") || 
            (!lower.contains("rp") && !lower.contains("qris") && !lower.contains("shopeepay") && 
             !lower.contains("berhasil") && !lower.contains("rincian") && !lower.contains("promo") && 
             !lower.contains("split") && !lower.contains("klaim") && !lower.contains("tanggal") &&
             !RegExp(r'^\d{1,2}:\d{2}').hasMatch(line) && line.length > 3)) {
          
          merchantName = line;
          break;
        }
      }
    }

    // 4. Penentuan Kategori Berdasarkan Nama Merchant
    String lowerMerchant = merchantName.toLowerCase();
    if (lowerMerchant.contains("cilok") || lowerMerchant.contains("siomay") || lowerMerchant.contains("dimsum") || lowerMerchant.contains("snack")) {
      category = "Jajan";
    } else if (lowerMerchant.contains("kopi") || lowerMerchant.contains("teh") || lowerMerchant.contains("boba") || lowerMerchant.contains("cafe")) {
      category = "Minuman";
    } else if (lowerMerchant.contains("roti") || lowerMerchant.contains("nasi") || lowerMerchant.contains("bakso") || lowerMerchant.contains("mie") || lowerMerchant.contains("ayam") || lowerMerchant.contains("makan")) {
      category = "Makanan";
    } else if (lowerMerchant.contains("toko") || lowerMerchant.contains("store") || lowerMerchant.contains("shop") || lowerMerchant.contains("mart") || lowerMerchant.contains("cina")) {
      category = "Belanja";
    } else {
      category = "Lifestyle";
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