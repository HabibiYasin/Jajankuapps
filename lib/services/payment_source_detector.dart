import '../data/payment_sources.dart';
import 'transaction_classifier.dart';

/// Offline bank/wallet detection using the supplied workbook's aliases.
class PaymentSourceDetector {
  static final _aliases = [
    for (final source in paymentSources)
      for (final alias in source.$2)
        (name: source.$1, alias: TransactionClassifier.normalize(alias)),
  ]..sort((a, b) => b.alias.length.compareTo(a.alias.length));

  static final sourceLabel = RegExp(
    r'^(?:sumber (?:dana|uang|akun|rekening)|rekening (?:asal|sumber)|bank (?:asal|pengirim)|dari(?: bank)?|(?:nama )?issuer|metode pembayaran|dibayar dengan|bayar dengan|paid with|payment source)\b',
    caseSensitive: false,
  );
  static final destinationLabel = RegExp(
    r'^(?:(?:nama )?(?:bank )?(?:penerima|tujuan)|transfer ke|kirim ke|kepada|ke|(?:nama )?acquirer|merchant|nama merchant|pengirim|nama pengirim|dari)\b',
    caseSensitive: false,
  );

  static String? match(String text) {
    // "dana" in these field labels is not the DANA wallet.
    final normalized =
        ' ${TransactionClassifier.normalize(text).replaceAll(RegExp(r'\b(?:sumber dana|transfer dana|kirim dana|dana masuk|dana keluar)\b'), '').trim()} ';
    for (final entry in _aliases) {
      if (normalized.contains(' ${entry.alias} ')) return entry.name;
    }
    return null;
  }

  static bool isExactSource(String text) {
    final normalized = TransactionClassifier.normalize(text);
    return _aliases.any((entry) => entry.alias == normalized);
  }

  static String? detect(List<String> lines) {
    // OCR can split the BCA Syariah logo or a bank field over two rows.
    // Preserve its field label so a receiving bank remains excluded.
    lines = List<String>.from(lines);
    for (var i = 0; i + 1 < lines.length; i++) {
      if (RegExp(r'\bbca$', caseSensitive: false).hasMatch(lines[i]) &&
          RegExp(
            r'^syar(?:iah|nah)(?:\s+mobile)?$',
            caseSensitive: false,
          ).hasMatch(lines[i + 1])) {
        lines[i] = '${lines[i]} ${lines.removeAt(i + 1)}';
      }
    }
    // Explicit payer fields take precedence over a receiving bank or logo.
    for (var i = 0; i < lines.length; i++) {
      if (!sourceLabel.hasMatch(lines[i])) continue;
      final inline = match(lines[i].replaceFirst(sourceLabel, ''));
      if (inline != null) return inline;
      for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
        if (destinationLabel.hasMatch(lines[j]) || _field.hasMatch(lines[j])) {
          break;
        }
        final found = match(lines[j]);
        if (found != null) return found;
      }
    }

    // Shared receipts may lose the bank logo during OCR. Only use the payer's
    // explicitly labelled PAN, never a merchant PAN or an unlabelled number.
    // BCA Syariah issuer code: https://bicara131.bi.go.id/knowledgebase/article/KA-01154/en-us
    final customerPan = RegExp(
      r'^customer\s+pan\b\s*[:\-]?\s*(.*)$',
      caseSensitive: false,
    );
    for (var i = 0; i < lines.length; i++) {
      final field = customerPan.firstMatch(lines[i]);
      if (field == null) continue;
      final inline = field.group(1)!.trim();
      final value = inline.isNotEmpty
          ? inline
          : (i + 1 < lines.length ? lines[i + 1] : '');
      final compact = value.replaceAll(RegExp(r'[\s-]'), '');
      if (RegExp(r'^93600536[0-9*xX•]{4,11}$').hasMatch(compact)) {
        return 'BCA Syariah';
      }
    }

    var inDestination = false;
    String? candidate;
    for (final line in lines) {
      if (destinationLabel.hasMatch(line)) {
        inDestination = true;
        continue;
      }
      if (sourceLabel.hasMatch(line) || _field.hasMatch(line)) {
        inDestination = false;
        continue;
      }
      if (inDestination) continue;
      final found = match(line);
      // A partial BCA logo can precede its complete name elsewhere on the
      // receipt. Refine that name using only eligible source rows; explicit
      // payer fields above still take precedence over all logos.
      if (candidate == null ||
          (candidate == 'BCA' &&
              (found == 'BCA Syariah' || found == 'BCA Digital'))) {
        candidate = found;
      }
    }
    return candidate;
  }

  static final _field = RegExp(
    r'^(?:total|nominal|jumlah|biaya|tanggal|waktu|metode|status|saldo|keterangan|catatan|diskon|cashback|promo|no\.?|nomor|id|kode|lokasi|alamat)\b',
    caseSensitive: false,
  );
}
