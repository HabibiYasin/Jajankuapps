import '../../models/transaction_model.dart';

/// Parser bukti transaksi BNI / wondr dari teks hasil OCR.
/// Saat ini digunakan oleh alur OCR pembayaran QRIS.
/// Parser metode lain (misalnya Transfer) ditambahkan di file ini,
/// dengan deteksi dan ekstraksi tersendiri sesuai format bukti transaksi.
class BniParser {
  // === OCR: deteksi format bukti transaksi saat ini ===
  static bool isMatch(String rawText) {
    final text = rawText.toLowerCase();
    // Acquirer BNI saja tidak berarti struk diterbitkan oleh BNI.
    return text.contains('qris') &&
        (text.contains('wondr') ||
            RegExp(
              r'^\s*BNI\s*$',
              multiLine: true,
              caseSensitive: false,
            ).hasMatch(rawText) ||
            RegExp(
              r'nama\s+issuer\s*\n?\s*bank\s+bni',
              caseSensitive: false,
            ).hasMatch(rawText));
  }

  /// Mengubah teks hasil OCR menjadi transaksi pada alur QRIS saat ini.
  static TransactionModel parse(String rawText, List<String> lines) {
    final text = rawText.toLowerCase();
    if (RegExp(
      r'belum\s+berhasil|tidak\s+berhasil|gagal|sedang\s+diproses|tertunda|pending',
    ).hasMatch(text)) {
      throw const FormatException(
        'Pembayaran BNI belum berhasil. Gunakan bukti pembayaran berhasil.',
      );
    }
    final wondr = text.contains('wondr');
    final merchant = _field(lines, wondr ? 'Penerima' : 'Nama Merchant');
    final amount = _field(lines, wondr ? 'Total' : 'Total Bayar');
    final amountMatch = RegExp(
      r'Rp\s*([0-9][0-9.,]*)',
      caseSensitive: false,
    ).firstMatch(amount);
    if (merchant.isEmpty || amountMatch == null) {
      throw const FormatException(
        'Nama merchant atau total pembayaran BNI tidak terbaca.',
      );
    }
    final number = amountMatch.group(1)!;
    final numeric = double.tryParse(
      number.replaceAll('.', '').replaceAll(',', '.'),
    );
    if (numeric == null || numeric <= 0) {
      throw const FormatException('Nominal pembayaran BNI tidak valid.');
    }
    final numericDate = RegExp(r'\b(\d{2})-(\d{2})-(\d{4})\b')
        .firstMatch(rawText);
    final textDate = RegExp(r'\b(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})\b')
        .firstMatch(rawText);
    final time = RegExp(r'\b(\d{1,2}):(\d{2})(?::(\d{2}))?\b')
        .firstMatch(rawText);
    const months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'mei',
      'jun',
      'jul',
      'agu',
      'sep',
      'okt',
      'nov',
      'des',
    ];
    var date = DateTime.now();
    if (numericDate != null || textDate != null) {
      final match = numericDate ?? textDate!;
      final monthName = match.group(2)!.toLowerCase();
      final month = numericDate != null
          ? int.parse(monthName)
          : months.indexWhere((m) => monthName.startsWith(m)) + 1;
      if (month == 0) throw const FormatException('Tanggal BNI tidak terbaca.');
      date = DateTime(
        int.parse(match.group(3)!),
        month,
        int.parse(match.group(1)!),
        time == null ? 0 : int.parse(time.group(1)!),
        time == null ? 0 : int.parse(time.group(2)!),
        time?.group(3) == null ? 0 : int.parse(time!.group(3)!),
      );
    }
    return TransactionModel(
      merchant: merchant,
      nominalStr: 'Rp$number',
      numericNominal: numeric,
      dateTime: date,
      category: 'Umum',
      source: wondr ? 'wondr by BNI' : 'BNI Mobile Banking',
    );
  }

  static String _field(List<String> lines, String label) {
    final pattern = RegExp(
      '^${RegExp.escape(label)}(?:\\s+|\\s*:\\s*|\$)',
      caseSensitive: false,
    );
    for (var i = 0; i < lines.length; i++) {
      final match = pattern.firstMatch(lines[i]);
      if (match == null) continue;
      final value = lines[i].substring(match.end).trim();
      return value.isNotEmpty
          ? value
          : (i + 1 < lines.length ? lines[i + 1].trim() : '');
    }
    return '';
  }
}
