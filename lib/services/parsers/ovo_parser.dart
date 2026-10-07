import '../../models/transaction_model.dart';

/// Parser bukti transaksi OVO dari teks hasil OCR.
/// Saat ini digunakan oleh alur OCR pembayaran QRIS.
/// Parser metode lain (misalnya Transfer) ditambahkan di file ini,
/// dengan deteksi dan ekstraksi tersendiri sesuai format bukti transaksi.
class OvoParser {
  // === OCR: deteksi format bukti transaksi saat ini ===
  static bool isMatch(String rawText) {
    final lower = rawText.toLowerCase();
    return lower.contains('ovo cash terpakai') ||
        (lower.contains('ovo') &&
            lower.contains('pembayaran berhasil') &&
            lower.contains('total transaksi'));
  }

  /// Mengubah teks hasil OCR menjadi transaksi pada alur QRIS saat ini.
  static TransactionModel parse(
    String rawText,
    List<String> cleanedLines,
  ) {
    String merchantName = 'Tidak Diketahui';
    String nominalStr = 'Rp0';
    DateTime parsedDate = DateTime.now();

    // Pada struk OVO, nilai transaksi dapat berada di baris yang sama dengan
    // label atau di baris berikutnya jika hasil OCR memecah kolom.
    final nominalRegex = RegExp(r'Rp\s*[0-9][0-9.,]*', caseSensitive: false);
    for (var i = 0; i < cleanedLines.length; i++) {
      if (!cleanedLines[i].toLowerCase().contains('total transaksi')) continue;

      for (var j = i; j <= i + 1 && j < cleanedLines.length; j++) {
        final match = nominalRegex.firstMatch(cleanedLines[j]);
        if (match != null) {
          nominalStr = _normalizeNominal(match.group(0)!);
          break;
        }
      }
      if (nominalStr != 'Rp0') break;
    }

    // Nama merchant tampil tepat sebelum label "Total Transaksi".
    for (var i = 1; i < cleanedLines.length; i++) {
      if (cleanedLines[i].toLowerCase().contains('total transaksi')) {
        final candidate = cleanedLines[i - 1].trim();
        if (_isMerchantCandidate(candidate)) {
          merchantName = candidate;
          break;
        }
      }
    }

    // Fallback: "MECCA QRIS telah menerima Rp2.000".
    if (merchantName == 'Tidak Diketahui') {
      final receivedRegex = RegExp(
        r'^(.+?)\s+telah\s+menerima\s+Rp',
        caseSensitive: false,
      );
      for (final line in cleanedLines) {
        final match = receivedRegex.firstMatch(line);
        if (match != null && _isMerchantCandidate(match.group(1)!)) {
          merchantName = match.group(1)!.trim();
          break;
        }
      }
    }

    final dateRegex = RegExp(
      r'(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})\s*[^0-9A-Za-z\s]?\s*(\d{1,2}):(\d{2})',
      caseSensitive: false,
    );
    for (final line in cleanedLines) {
      final match = dateRegex.firstMatch(line);
      if (match == null) continue;

      final month = _monthNumber(match.group(2)!);
      final day = int.tryParse(match.group(1)!);
      final year = int.tryParse(match.group(3)!);
      final hour = int.tryParse(match.group(4)!);
      final minute = int.tryParse(match.group(5)!);
      if (month != null && day != null && year != null && hour != null && minute != null) {
        final candidate = DateTime(year, month, day, hour, minute);
        if (candidate.year == year &&
            candidate.month == month &&
            candidate.day == day &&
            candidate.hour == hour &&
            candidate.minute == minute) {
          parsedDate = candidate;
          break;
        }
      }
    }

    final numericNominal = double.tryParse(
          nominalStr.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;

    return TransactionModel(
      merchant: merchantName,
      nominalStr: nominalStr,
      dateTime: parsedDate,
      category: _categoryFor(merchantName),
      numericNominal: numericNominal,
      source: 'OVO',
    );
  }

  static String _normalizeNominal(String value) {
    final number = value.replaceAll(RegExp(r'[^0-9.,]'), '');
    return number.isEmpty ? 'Rp0' : 'Rp$number';
  }

  static bool _isMerchantCandidate(String value) {
    final lower = value.toLowerCase();
    return value.length > 2 &&
        !lower.contains('pembayaran berhasil') &&
        !lower.contains('ovo') &&
        !lower.contains('total transaksi');
  }

  static int? _monthNumber(String value) {
    const months = <String, int>{
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'mei': 5,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'agu': 8,
      'agt': 8,
      'aug': 8,
      'sep': 9,
      'okt': 10,
      'oct': 10,
      'nov': 11,
      'des': 12,
      'dec': 12,
    };
    final key = value.toLowerCase();
    return months[key.length > 3 ? key.substring(0, 3) : key];
  }

  static String _categoryFor(String merchantName) {
    final lower = merchantName.toLowerCase();
    if (lower.contains('kopi') ||
        lower.contains('coffee') ||
        lower.contains('resto') ||
        lower.contains('bakso') ||
        lower.contains('roti') ||
        lower.contains('food')) {
      return 'Makanan';
    }
    if (lower.contains('pulsa') ||
        lower.contains('token') ||
        lower.contains('pdam')) {
      return 'Tagihan & Pulsa';
    }
    return 'Belanja';
  }
}
