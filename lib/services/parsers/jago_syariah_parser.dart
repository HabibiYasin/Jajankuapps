import '../../models/transaction_model.dart';

class JagoSyariahParser {
  static bool isMatch(String rawText) {
    final lower = rawText.toLowerCase();
    return (lower.contains('jago syariah') ||
            (lower.contains('syariah') && lower.contains('jago')) ||
            (lower.contains('syariah') && lower.contains('id transaksi'))) &&
        lower.contains('sumber akun');
  }

  static TransactionModel parse(
    String rawText,
    List<String> cleanedLines,
  ) {
    var merchantName = 'Tidak Diketahui';
    var nominalStr = 'Rp0';
    var parsedDate = DateTime.now();

    final nominalRegex = RegExp(
      r'Rp\s*[0-9][0-9.,]*',
      caseSensitive: false,
    );
    var nominalIndex = -1;
    for (var i = 0; i < cleanedLines.length; i++) {
      final match = nominalRegex.firstMatch(cleanedLines[i]);
      if (match == null) continue;

      nominalStr = _normalizeNominal(match.group(0)!);
      nominalIndex = i;
      break;
    }

    // Nama merchant berada di bagian header, sebelum nominal. Ambil baris
    // pertama setelah judul Jago Syariah agar kode avatar dan kota terlewati.
    final headerIndex = cleanedLines.indexWhere(
      (line) => line.toLowerCase().contains('syariah'),
    );
    if (headerIndex >= 0) {
      final end = nominalIndex >= 0 ? nominalIndex : cleanedLines.length;
      for (var i = headerIndex + 1; i < end; i++) {
        final candidate = cleanedLines[i].trim();
        if (_isMerchantCandidate(candidate)) {
          merchantName = candidate;
          break;
        }
      }
    }

    final dateRegex = RegExp(
      r'(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})\s*,?\s*(\d{1,2}):(\d{2})',
      caseSensitive: false,
    );
    for (final line in cleanedLines) {
      final match = dateRegex.firstMatch(line);
      if (match == null) continue;

      final day = int.tryParse(match.group(1)!);
      final month = _monthNumber(match.group(2)!);
      final year = int.tryParse(match.group(3)!);
      final hour = int.tryParse(match.group(4)!);
      final minute = int.tryParse(match.group(5)!);
      if (day == null ||
          month == null ||
          year == null ||
          hour == null ||
          minute == null) {
        continue;
      }

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
      source: 'Jago Syariah',
    );
  }

  static bool _isMerchantCandidate(String value) {
    final lower = value.toLowerCase();
    return value.length > 3 &&
        !RegExp(r'^[a-z]{1,3}$', caseSensitive: false).hasMatch(value) &&
        !RegExp(r'^\d+$').hasMatch(value) &&
        !lower.contains('jago syariah') &&
        !lower.contains('id transaksi') &&
        !lower.contains('sumber akun') &&
        !lower.contains('tanggal') &&
        !lower.contains('biaya');
  }

  static String _normalizeNominal(String value) {
    final number = value.replaceAll(RegExp(r'[^0-9.,]'), '');
    return number.isEmpty ? 'Rp0' : 'Rp$number';
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
        lower.contains('roti')) {
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
