import '../../models/transaction_model.dart';

/// Parser bukti transaksi BRI / BRImo dari teks hasil OCR.
/// Saat ini digunakan oleh alur OCR pembayaran QRIS.
/// Parser metode lain (misalnya Transfer) ditambahkan di file ini,
/// dengan deteksi dan ekstraksi tersendiri sesuai format bukti transaksi.
class BriParser {
  // === OCR: deteksi format bukti transaksi saat ini ===
  static bool isMatch(String rawText) {
    String lower = rawText.toLowerCase();
    return lower.contains("pt. bank rakyat indonesia") || 
           lower.contains("brimo") || 
           lower.contains("kantor pusat bri") || 
           (lower.contains("sumber dana") && lower.contains("bri"));
  }

  /// Mengubah teks hasil OCR menjadi transaksi pada alur QRIS saat ini.
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

    // 2. AMBIL FIELD "NAMA MERCHANT". Nilainya bisa berada pada baris yang
    // sama dan berlanjut ke baris berikutnya, misalnya:
    // Nama Merchant MbI365739 Konter
    // Ryan Nug
    // Lokasi Merchant KUNINGAN
    merchantName = _valueWithContinuation(
      cleanedLines,
      label: 'nama merchant',
    );

    // Pada ringkasan bagian atas, merchant juga ditampilkan setelah "Tujuan".
    if (merchantName == "Tidak Diketahui") {
      merchantName = _valueWithContinuation(
        cleanedLines,
        label: 'tujuan',
      );
    }

    // Fallback cadangan untuk variasi struk lama.
    if (merchantName == "Tidak Diketahui") {
      for (String line in cleanedLines) {
        final lower = line.toLowerCase();
        if (lower.contains("konter") || lower.contains("merchant")) {
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
      source: "BRImo", 
    );
  }

  static String _valueWithContinuation(
    List<String> lines, {
    required String label,
  }) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lower = line.toLowerCase();
      if (!lower.startsWith(label)) continue;

      final parts = <String>[];
      final inlineValue = line.substring(label.length).trim();
      if (inlineValue.isNotEmpty) parts.add(inlineValue);

      for (int j = i + 1; j < lines.length; j++) {
        final next = lines[j].trim();
        if (_isBriFieldLabel(next)) break;
        if (_isMerchantContinuation(next)) parts.add(next);
      }

      if (parts.isNotEmpty) return parts.join(' ');
    }

    return "Tidak Diketahui";
  }

  static bool _isBriFieldLabel(String line) {
    final lower = line.toLowerCase();
    const labels = <String>[
      'total transaksi',
      'no. ref',
      'sumber dana',
      'tujuan',
      'id ',
      'jenis transaksi',
      'nama merchant',
      'lokasi merchant',
      'nama penerbit',
      'nama pengakuisisi',
      'nomor invoice',
      'kode pan pelanggan',
      'merchant pan',
      'id terminal',
      'catatan',
      'nominal pembayaran',
      'pembayaran',
      'biaya admin',
      'informasi',
    ];
    return labels.any(lower.startsWith);
  }

  static bool _isMerchantContinuation(String line) {
    final lower = line.toLowerCase();
    return line.isNotEmpty &&
        !RegExp(r'^rp\s*[0-9]', caseSensitive: false).hasMatch(line) &&
        !RegExp(r'^\d{6,}$').hasMatch(line) &&
        lower != 'qris bayar' &&
        lower != 'sukses';
  }
}
