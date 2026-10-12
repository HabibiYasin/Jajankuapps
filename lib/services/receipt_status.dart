/// Status rejection is separate from recoverable layout/extraction failures.
class ReceiptStatus {
  static void ensureSuccessful(String text) {
    final lines = text.split(RegExp(r'[\r\n]+')).map((s) => s.trim()).toList();
    final negative = RegExp(
      r'\b(?:belum berhasil|tidak berhasil|gagal|pending|tertunda|sedang diproses|diproses|dibatalkan|batal|failed|cancelled|canceled|unsuccessful)\b',
      caseSensitive: false,
    );
    final statusField = RegExp(
      r'^(?:status(?: transaksi| pembayaran)?|transaksi(?: pembayaran)?|pembayaran|payment|transfer|qris)\b',
      caseSensitive: false,
    );
    final statusOnly = RegExp(
      r'^(?:belum berhasil|tidak berhasil|gagal|pending|tertunda|sedang diproses|diproses|dibatalkan|batal|failed|cancelled|canceled|unsuccessful)[.!]?$',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (statusOnly.hasMatch(line) ||
          (statusField.hasMatch(line) && negative.hasMatch(line))) {
        throw const FormatException(
          'Transaksi belum berhasil. Gunakan bukti pembayaran berhasil.',
        );
      }
    }
  }
}

/// Only missing layout fields may trigger fallback; invalid status/date must not.
class ReceiptLayoutException extends FormatException {
  const ReceiptLayoutException(super.message);
}
