import '../../models/transaction_model.dart';
import '../payment_source_detector.dart';
import '../transaction_classifier.dart';
import '../receipt_amount.dart';
import '../receipt_status.dart';

/// Fallback for unrecognized receipts and methods without a dedicated parser.
class GeneralParser {
  static final _money = RegExp(
    r'\b(?:rp\.?|idr)\s*(-?\s*\d[\d.,]*)',
    caseSensitive: false,
  );
  static TransactionModel parse(String rawText, List<String> lines) {
    ReceiptStatus.ensureSuccessful(rawText);
    final method = detectMethod(rawText);
    final merchant = _merchant(lines, method);
    final amount = ReceiptAmount.read(lines) ?? 0;
    return TransactionModel(
      merchant: merchant,
      nominalStr: ReceiptAmount.format(amount),
      numericNominal: amount,
      source: PaymentSourceDetector.detect(lines) ?? 'Tidak Diketahui',
      paymentMethod: method,
      dateTime: extractDateTime(lines) ?? DateTime.now(),
      category: TransactionClassifier.classify(
        merchant: merchant,
        receiptText: rawText,
      ).category,
    );
  }

  static String detectMethod(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final label = RegExp(
      r'^(?:metode|jenis|cara) (?:pembayaran|transaksi)\b|^payment method\b',
      caseSensitive: false,
    );
    final evidence = <String>[];
    var inPromo = false;
    var skipValue = false;
    for (final line in lines) {
      if (RegExp(
        r'^(?:promo|cashback|diskon|nikmati|gunakan|coba)\b',
        caseSensitive: false,
      ).hasMatch(line)) {
        inPromo = true;
        continue;
      }
      if (label.hasMatch(line) || _metadata.hasMatch(line)) inPromo = false;
      if (inPromo) continue;
      if (skipValue) {
        skipValue = false;
        if (!label.hasMatch(line) && !_metadata.hasMatch(line)) continue;
      }
      if (RegExp(
        r'^(?:merchant|nama merchant|nama toko|tujuan|penerima|keterangan|catatan|produk|item)\b',
        caseSensitive: false,
      ).hasMatch(line)) {
        skipValue = RegExp(
          r'^(?:merchant|nama merchant|nama toko|tujuan|penerima|keterangan|catatan|produk|item)\s*:?$',
          caseSensitive: false,
        ).hasMatch(line);
        continue;
      }
      evidence.add(line);
    }
    for (var i = 0; i < evidence.length; i++) {
      if (!label.hasMatch(evidence[i])) continue;
      final method =
          _method(evidence[i]) ??
          (i + 1 < evidence.length ? _method(evidence[i + 1]) : null);
      if (method != null) return method;
    }
    // Promotions and item/merchant names must not select a payment method.
    return _method(
          evidence
              .where(
                (line) => RegExp(
                  r'^(?:pembayaran|transaksi|transfer|trf|tf|bi[ -]?fast|rtgs|skn|kirim uang|kirim ke|qris|qr|virtual account|va|s?pay\s*later|gopay\s*later|shopee\s*pay\s*later|kredivo|akulaku|tunai|cash|ovo cash|otto cash)\b',
                  caseSensitive: false,
                ).hasMatch(line),
              )
              .join('\n'),
        ) ??
        'QRIS';
  }

  static String? _method(String text) {
    if (RegExp(
      r'\b(?:s?pay\s*later|gopay\s*later|shopee\s*pay\s*later|paylater|kredivo|akulaku)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 'PayLater';
    }
    if (RegExp(
      r'\b(?:virtual\s+account|virtual\s+akun|va)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 'VA';
    }
    if (RegExp(
      r'\b(?:qris|qr(?:\s+code)?|kode\s+qr)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 'QRIS';
    }
    if (RegExp(
      r'\b(?:transfer|trf|tf|bi[ -]?fast|rtgs|skn|kirim uang|kirim ke)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 'Transfer';
    }
    final withoutWalletBalance = text.replaceAll(
      RegExp(r'\b(?:ovo|otto)\s+cash\b', caseSensitive: false),
      '',
    );
    if (RegExp(
      r'\b(?:cash|tunai)\b',
      caseSensitive: false,
    ).hasMatch(withoutWalletBalance)) {
      return 'Cash';
    }
    return null;
  }

  static final _metadata = RegExp(
    r'^(?:total|subtotal|nominal|jumlah|biaya|saldo|diskon|potongan|promo|cashback|tanggal|waktu|pukul|jam|metode|jenis transaksi|status|transaksi|pembayaran|transfer berhasil|berhasil|sukses|rincian|detail|no\.?|nomor|id|kode|ref|referensi|rrn|pan|mpan|cpan|terminal|merchant (?:pan|id)|nama (?:acquirer|issuer)|lokasi|alamat|keterangan|catatan|produk|item|pengirim|nama pengirim|dari|sumber|rekening asal|bank asal|terima kasih|bagikan|unduh|tutup)\b',
    caseSensitive: false,
  );
  static bool isMerchantName(String text) =>
      text.length > 2 &&
      RegExp(r'[a-zA-Z]').hasMatch(text) &&
      !_metadata.hasMatch(text) &&
      !_money.hasMatch(text) &&
      !PaymentSourceDetector.isExactSource(text) &&
      !RegExp(
        r'^(?:nama|merchant|nama merchant|qris|virtual account|va|paylater|pay later|transfer|tunai|cash)$',
        caseSensitive: false,
      ).hasMatch(text);

  static String _merchant(List<String> lines, String method) {
    final labels = <RegExp>[
      if (method == 'Transfer' || method == 'VA')
        RegExp(
          r'^(?:nama penerima|nama (?:rekening|pemilik rekening) tujuan|penerima|transfer (?:ke|kepada)|kirim (?:ke|kepada)|rekening tujuan|tujuan transfer|tujuan|kepada|ke|recipient|beneficiary)\b\s*[:\-]?\s*(.*)$',
          caseSensitive: false,
        ),
      RegExp(
        r'^(?:nama merchant|merchant name|merchant|nama toko|nama penjual|dibayar ke|bayar ke|pembayaran ke|tujuan|penerima)\b\s*[:\-]?\s*(.*)$',
        caseSensitive: false,
      ),
    ];
    for (final label in labels) {
      for (var i = 0; i < lines.length; i++) {
        final match = label.firstMatch(lines[i]);
        if (match == null ||
            RegExp(
              r'^merchant (?:pan|id)\b',
              caseSensitive: false,
            ).hasMatch(lines[i])) {
          continue;
        }
        final inline = match.group(1)!.trim();
        if (isMerchantName(inline)) return inline;
        for (var j = i + 1; j < lines.length && j <= i + 4; j++) {
          if (_metadata.hasMatch(lines[j])) break;
          if (isMerchantName(lines[j]) &&
              !labels.any((l) => l.hasMatch(lines[j])) &&
              !RegExp(r'^bank\b', caseSensitive: false).hasMatch(lines[j])) {
            return lines[j];
          }
        }
      }
    }
    // OCR may place the value to the left of its field label.
    for (final line in lines) {
      final match = RegExp(
        r'^(.+?)\s+(?:nama merchant|merchant)\s*:?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (match != null && isMerchantName(match.group(1)!)) {
        return match.group(1)!.trim();
      }
    }
    // Reuse the existing 7,000-keyword classifier, including its ambiguity rules.
    for (var i = 0; i < lines.length; i++) {
      if (!isMerchantName(lines[i])) continue;
      if (i > 0 &&
          RegExp(
            r'^(?:pengirim|nama pengirim|dari|keterangan|catatan|produk|item|alamat)\s*:?$',
            caseSensitive: false,
          ).hasMatch(lines[i - 1])) {
        continue;
      }
      if (TransactionClassifier.classify(merchant: lines[i])
          .matchedKeywords
          .isNotEmpty) {
        return lines[i];
      }
    }
    return 'Tidak Diketahui';
  }

  static DateTime? extractDateTime(List<String> lines) {
    final dates = [
      RegExp(r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?=\b|T)'),
      RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4}|\d{2})\b'),
      RegExp(r'\b(\d{1,2})[\s-]+([a-zA-Z]+)[\s,-]+(\d{4})\b'),
    ];
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
      'agt': 8,
      'aug': 8,
      'sep': 9,
      'okt': 10,
      'oct': 10,
      'nov': 11,
      'des': 12,
      'dec': 12,
    };
    final time = RegExp(
      r'(?:\b|T)(\d{1,2})[:.](\d{2})(?:[:.](\d{2}))?(?:\s*(AM|PM))?\b',
      caseSensitive: false,
    );
    for (var i = 0; i < lines.length; i++) {
      for (var kind = 0; kind < dates.length; kind++) {
        final match = dates[kind].firstMatch(lines[i]);
        if (match == null) continue;
        var year = int.parse(match.group(kind == 0 ? 1 : 3)!);
        if (year < 100) year += 2000;
        final monthText = match.group(2)!.toLowerCase();
        final month = kind == 2
            ? months[monthText.length > 3
                  ? monthText.substring(0, 3)
                  : monthText]
            : int.tryParse(monthText);
        if (month == null) continue;
        final day = int.parse(match.group(kind == 0 ? 3 : 1)!);
        // Prefer time next to the date, not the phone's status-bar clock.
        var clock = time.firstMatch(lines[i].substring(match.end));
        for (
          var j = i + 1;
          clock == null && j < lines.length && j <= i + 2;
          j++
        ) {
          if (_money.hasMatch(lines[j])) break;
          if (RegExp(
                r'^(?:waktu|pukul|jam)',
                caseSensitive: false,
              ).hasMatch(lines[j]) ||
              RegExp(
                r'^\d{1,2}[:.]\d{2}(?:[:.]\d{2})?(?:\s*(?:WIB|WITA|WIT|AM|PM))?$',
                caseSensitive: false,
              ).hasMatch(lines[j])) {
            clock = time.firstMatch(lines[j]);
          }
        }
        clock ??= time.firstMatch(lines[i].substring(0, match.start));
        var hour = clock == null ? 0 : int.parse(clock.group(1)!);
        final minute = clock == null ? 0 : int.parse(clock.group(2)!);
        final second = int.parse(clock?.group(3) ?? '0');
        final period = clock?.group(4)?.toUpperCase();
        if (period != null) {
          if (hour < 1 || hour > 12) continue;
          hour = hour % 12 + (period == 'PM' ? 12 : 0);
        }
        final result = DateTime(year, month, day, hour, minute, second);
        if (result.year == year &&
            result.month == month &&
            result.day == day &&
            result.hour == hour &&
            result.minute == minute &&
            result.second == second) {
          return result;
        }
      }
    }
    return null;
  }
}
