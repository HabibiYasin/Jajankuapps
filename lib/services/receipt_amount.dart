/// Shared amount extraction for bank layouts and unknown receipts.
class ReceiptAmount {
  static final _money = RegExp(
    r'\b(?:rp\.?|idr)\s*(-?\s*\d[\d.,]*)',
    caseSensitive: false,
  );
  static final _discount = RegExp(
    r'\b(?:diskon|discount|potongan|voucher)\b',
    caseSensitive: false,
  );
  static final _finalTotal = RegExp(
    r'\b(?:total (?:pembayaran|bayar|transaksi|akhir)|(?:jumlah|nominal) (?:dibayar|pembayaran)|(?:kamu|anda) membayar|(?:harus|yang) dibayar|setelah (?:diskon|potongan)|grand total|amount paid|total paid)\b|^total\s*:?\s*$',
    caseSensitive: false,
  );
  static final _nonPurchase = RegExp(
    r'\b(?:saldo|balance|limit|cashback|kembalian|uang diterima|hemat|poin|promo)\b|^(?:uang )?(?:tunai|cash)\b',
    caseSensitive: false,
  );

  static double _number(String text) {
    var value = text
        .replaceAll(RegExp(r'[^\d.,]'), '')
        .replaceAll(RegExp(r'[.,]+$'), '');
    final decimal = RegExp(r'[.,](\d{1,2})$').firstMatch(value);
    if (decimal != null) {
      value =
          '${value.substring(0, decimal.start).replaceAll(RegExp(r'[.,]'), '')}.${decimal.group(1)}';
    } else {
      value = value.replaceAll(RegExp(r'[.,]'), '');
    }
    return double.tryParse(value) ?? 0;
  }

  static double? read(List<String> lines) {
    // Bare digits are amounts only immediately after a monetary field label.
    // Account/reference numbers must never enter this path.
    final amountLabel = RegExp(
      r'^(?:total(?: (?:pembayaran|bayar|transaksi|akhir))?|grand total|amount paid|total paid|nominal(?: (?:transaksi|bayar|pembayaran))?|jumlah(?: (?:dibayar|pembayaran))?|subtotal|harga|biaya(?: admin)?|diskon|potongan|kamu membayar)\s*:?\s*$',
      caseSensitive: false,
    );
    final bareAmount = RegExp(r'^\d[\d.,]*$');
    final values = <({double value, String context})>[];
    for (var i = 0; i < lines.length; i++) {
      final matches = _money.allMatches(lines[i]).toList();
      var end = 0;
      for (final match in matches) {
        var context = lines[i].substring(end, match.start).trim();
        if (context.isEmpty && i > 0 && !_money.hasMatch(lines[i - 1])) {
          context = lines[i - 1];
        }
        values.add((value: _number(match.group(1)!), context: context));
        end = match.end;
      }
      if (matches.isEmpty) {
        final inline = RegExp(r'^(.*?)\s+(\d[\d.,]*)$').firstMatch(lines[i]);
        if (inline != null && amountLabel.hasMatch(inline.group(1)!)) {
          values.add((
            value: _number(inline.group(2)!),
            context: inline.group(1)!,
          ));
        } else if (i > 0 &&
            bareAmount.hasMatch(lines[i]) &&
            amountLabel.hasMatch(lines[i - 1])) {
          values.add((value: _number(lines[i]), context: lines[i - 1]));
        }
      }
      // Some OCR engines put "Rp" on a line by itself.
      if (RegExp(r'^(?:rp\.?|idr)$', caseSensitive: false).hasMatch(lines[i]) &&
          i + 1 < lines.length &&
          RegExp(r'^\d[\d.,]*$').hasMatch(lines[i + 1])) {
        values.add((
          value: _number(lines[i + 1]),
          context: i > 0 ? lines[i - 1] : '',
        ));
      }
    }
    final purchases = values
        .where(
          (v) =>
              !_nonPurchase.hasMatch(v.context) &&
              !_discount.hasMatch(v.context),
        )
        .toList();
    final finals = values
        .where(
          (v) =>
              !_nonPurchase.hasMatch(v.context) &&
              _finalTotal.hasMatch(v.context),
        )
        .toList();
    final hasDiscount = lines.any(_discount.hasMatch);
    // Never subtract a discount twice when a net total is printed.
    if (finals.isNotEmpty) return finals.last.value;
    if (purchases.isEmpty) return null;
    final largest = purchases
        .map((v) => v.value)
        .reduce((a, b) => a > b ? a : b);
    if (!hasDiscount) return largest;
    final discounts = values.where(
      (v) =>
          _discount.hasMatch(v.context) &&
          !_finalTotal.hasMatch(v.context) &&
          !_nonPurchase.hasMatch(v.context),
    );
    final deduction = discounts.fold<double>(0, (sum, v) => sum + v.value);
    if (deduction > 0 && deduction <= largest) {
      return double.parse((largest - deduction).toStringAsFixed(2));
    }
    // Percentage-only discounts cannot be applied safely without a printed
    // deduction (caps and eligibility may be missing from the receipt).
    return largest;
  }

  static String format(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'Rp$whole${parts[1] == '00' ? '' : ',${parts[1]}'}';
  }
}
