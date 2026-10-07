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

  static String? detect(List<String> lines) {
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

    var inDestination = false;
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
      if (found != null) return found;
    }
    return null;
  }

  static final _field = RegExp(
    r'^(?:total|nominal|jumlah|biaya|tanggal|waktu|metode|status|saldo|keterangan|catatan|diskon|cashback|promo|no\.?|nomor|id|kode|lokasi|alamat)\b',
    caseSensitive: false,
  );
}
