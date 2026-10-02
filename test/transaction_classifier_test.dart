import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/transaction_keywords.dart';
import 'package:flutter_application_1/services/transaction_classifier.dart';
import 'package:flutter_application_1/services/qris_parser.dart';

void main() {
  String classify(String merchant, [String receipt = '']) =>
      TransactionClassifier.classify(
        merchant: merchant,
        receiptText: receipt,
      ).category;

  test('imports 1400 keywords, 200 per category, with consistent labels', () {
    expect(transactionKeywords, hasLength(1400));
    for (final category in TransactionClassifier.categories.where(
      (c) => c != 'Umum',
    )) {
      expect(
        transactionKeywords.where((entry) => entry.$2 == category),
        hasLength(200),
      );
    }
  });

  test('every strong dictionary entry is recognized on its own', () {
    for (final entry in transactionKeywords.where((e) => e.$3 == 3)) {
      expect(classify(entry.$1), entry.$2, reason: entry.$1);
    }
  });

  test('handles category-specific merchants, punctuation and casing', () {
    final cases = {
      'MIE GACOAN - CABANG DEPOK': 'Makanan',
      'KOPI   KENANGAN, MARGONDA': 'Minuman',
      'Holland Bakery': 'Jajan',
      'INDOMARET 1234': 'Belanja',
      'Token listrik': 'Tagihan & Pulsa',
      'NETFLIX': 'Lifestyle',
      'Tiket KRL': 'Transportasi',
      'A&W': 'Makanan',
      'H&M': 'Belanja',
    };
    for (final entry in cases.entries) {
      expect(classify(entry.key), entry.value, reason: entry.key);
    }
  });

  test('uses whole words and avoids payment/footer/sender contamination', () {
    for (final merchant in [
      'MECCA QRIS',
      'BUDI SANTOSO',
      'TRI SUSANTI',
      'RESTU JAYA',
      'QRIS',
      'TOP UP GOPAY',
      'GOJEK',
    ]) {
      expect(
        classify(
          merchant,
          'OVO Cash\nTransfer Berhasil\nSumber Dana\nKOPI SUSU\nPromo Netflix\nBiaya pengiriman',
        ),
        'Umum',
        reason: merchant,
      );
    }
  });

  test('specific phrase wins over a contained category keyword', () {
    expect(classify('PERMEN KOPI'), 'Jajan');
    expect(classify('ES TELER 77'), 'Makanan');
    expect(classify('SUSU FORMULA'), 'Belanja');
  });

  test(
    'conflicting evidence stays reviewable instead of defaulting to food',
    () {
      expect(classify('MIE GACOAN DAN KOPI KENANGAN'), 'Umum');
      expect(classify('TOKO TAK DIKENAL'), 'Umum');
      expect(
        classify('TOKO TAK DIKENAL', 'Keterangan: tiket krl'),
        'Transportasi',
      );
      expect(classify('INDOMARET', 'Produk: token listrik'), 'Tagihan & Pulsa');
      expect(classify('KOPI KENANGAN', 'Keterangan: ongkos kirim'), 'Minuman');
    },
  );

  test(
    'receipt router applies the classifier without changing amount or source',
    () {
      final tx = QrisParser.parseReceipt('''
Pembayaran Berhasil
KOPI KENANGAN
Total Transaksi Rp25.000
OVO Cash Terpakai Rp25.000
''');
      expect(tx.category, 'Minuman');
      expect(tx.source, 'OVO');
      expect(tx.numericNominal, 25000);
    },
  );
}
