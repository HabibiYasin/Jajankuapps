import '../../models/transaction_model.dart';

/// Parser bukti transaksi BSI / BYOND dari teks hasil OCR.
/// Saat ini digunakan oleh alur OCR pembayaran QRIS.
/// Parser metode lain (misalnya Transfer) ditambahkan di file ini,
/// dengan deteksi dan ekstraksi tersendiri sesuai format bukti transaksi.
class BsiParser {
  // === OCR: deteksi format bukti transaksi saat ini ===
  static bool isMatch(String rawText) {
    final lower = rawText.toLowerCase();
    return lower.contains('qris') &&
        (lower.contains('byond') ||
            lower.contains('bsi mobile') ||
            lower.contains('bank syariah indonesia') ||
            RegExp(
              r'^\s*BSI\b',
              multiLine: true,
              caseSensitive: false,
            ).hasMatch(rawText));
  }

  /// Mengubah teks hasil OCR menjadi transaksi pada alur QRIS saat ini.
  static TransactionModel parse(String rawText, List<String> lines) {
    if (RegExp(
      r'belum\s+berhasil|tidak\s+berhasil|sedang\s+diproses|tertunda|(?:status\s*:\s*|transaksi\s+pembayaran\s+(?:qris\s+mpm\s+kamu\s+)?)(?:gagal|pending|diproses)',
      caseSensitive: false,
    ).hasMatch(rawText)) {
      throw const FormatException(
        'Pembayaran BSI belum berhasil. Gunakan bukti pembayaran berhasil.',
      );
    }
    final byond = rawText.toLowerCase().contains('byond');
    final merchant = _field(lines, byond ? 'Nama Merchant' : 'Merchant');
    final amountRegex = RegExp(r'Rp\s*([0-9][0-9.,]*)', caseSensitive: false);
    final total = _field(lines, 'Total');
    final amountMatch =
        amountRegex.firstMatch(total) ??
        amountRegex.firstMatch(
          _field(lines, byond ? 'Nominal Transaksi' : 'Jumlah'),
        );
    if (amountMatch == null) {
      throw const FormatException('Total pembayaran BSI tidak terbaca.');
    }
    final number = amountMatch.group(1)!;
    final amount = double.tryParse(
      number.replaceAll('.', '').replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0 || !amount.isFinite) {
      throw const FormatException('Nominal pembayaran BSI tidak valid.');
    }
    return TransactionModel(
      merchant: merchant.isEmpty ? 'Tidak Diketahui' : merchant,
      nominalStr: 'Rp$number',
      numericNominal: amount,
      dateTime: _dateTime(rawText),
      category: 'Umum',
      source: byond ? 'BYOND by BSI' : 'BSI Mobile',
    );
  }

  // Stop at the next field so a redacted merchant never becomes an address,
  // account number, or another label. OCR may put values on separate lines.
  static String _field(List<String> lines, String label) {
    final prefix = RegExp(
      '^${RegExp.escape(label)}(?:\\s*:\\s*|\\s+|\$)',
      caseSensitive: false,
    );
    for (var i = 0; i < lines.length; i++) {
      // "Merchant PAN" is a different field from "Merchant".
      if (label == 'Merchant' &&
          RegExp(
            r'^Merchant\s+PAN\b',
            caseSensitive: false,
          ).hasMatch(lines[i])) {
        continue;
      }
      final match = prefix.firstMatch(lines[i]);
      if (match == null) continue;
      final parts = <String>[];
      final inline = lines[i].substring(match.end).trim();
      if (inline.isNotEmpty) parts.add(inline);
      for (var j = i + 1; j < lines.length; j++) {
        final next = lines[j].trim();
        if (RegExp(r'^BSI$', caseSensitive: false).hasMatch(next)) continue;
        if (_isField(next)) break;
        parts.add(next);
      }
      return parts.join(' ');
    }
    return '';
  }

  static bool _isField(String line) => RegExp(
    r'^(?:nama\s+(?:merchant|acquirer|issuer)|merchant\s+PAN|merchant(?:\s*:|$)|lokasi\s+merchant|alamat|rekening\s+sumber|MPAN|CPAN|terminal|nominal\s+transaksi|jumlah|tips?|total|RRN|referensi|tanggal\s+transaksi|no\.?\s*(?:transaksi|struk)|nomor\s+(?:struk|transaksi)|terima\s+kasih)\b',
    caseSensitive: false,
  ).hasMatch(line);

  static DateTime _dateTime(String text) {
    final iso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b').firstMatch(text);
    final words = RegExp(r'\b(\d{1,2})[ \t]+([A-Za-z]+)[ \t]+(\d{4})\b')
        .firstMatch(text);
    final time = RegExp(r'\b(\d{1,2}):(\d{2})(?::(\d{2}))?\b').firstMatch(text);
    if (iso == null && words == null) return DateTime.now();
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'mei': 5,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'agu': 8,
      'aug': 8,
      'sep': 9,
      'okt': 10,
      'oct': 10,
      'nov': 11,
      'des': 12,
      'dec': 12,
    };
    final monthName = words?.group(2)?.toLowerCase();
    final month = iso != null
        ? int.parse(iso.group(2)!)
        : months[monthName!.substring(
            0,
            monthName.length < 3 ? monthName.length : 3,
          )];
    if (month == null) {
      throw const FormatException('Tanggal pembayaran BSI tidak valid.');
    }
    final year = int.parse(iso?.group(1) ?? words!.group(3)!);
    final day = int.parse(iso?.group(3) ?? words!.group(1)!);
    final hour = int.parse(time?.group(1) ?? '0');
    final minute = int.parse(time?.group(2) ?? '0');
    final second = int.parse(time?.group(3) ?? '0');
    final date = DateTime(year, month, day, hour, minute, second);
    if (date.year != year ||
        date.month != month ||
        date.day != day ||
        date.hour != hour ||
        date.minute != minute ||
        date.second != second) {
      throw const FormatException('Tanggal pembayaran BSI tidak valid.');
    }
    return date;
  }
}
