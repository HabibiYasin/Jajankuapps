import 'package:flutter_application_1/services/qris_parser.dart';
import 'package:flutter_application_1/services/transaction_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final bank in ['BCA Syariah', 'SeaBank', 'GoPay', 'BNI', 'BSI']) {
    for (final status in [
      'Transaksi Gagal',
      'Status: Pending',
      'Status\nTertunda',
      'Pembayaran belum berhasil',
      'Transaksi dibatalkan',
    ]) {
      test('$bank rejects $status before selecting any parser', () {
        expect(
          () => QrisParser.parseReceipt('''
$bank
$status
Merchant: CHICKEN
Total Rp25.000
Promo
Bayar pakai PayLater dapat cashback
'''),
          throwsFormatException,
        );
      });
    }
  }

  test('incidental failure words do not reject a successful payment', () {
    final tx = QrisParser.parseReceipt('''
BNI
Pembayaran QRIS Berhasil
Nama Merchant CHICKEN
Total Bayar Rp25.000
Catatan: kemarin gagal pesan
Promo: Jangan gagal hemat
''');
    expect(tx.numericNominal, 25000);
  });

  for (final bank in ['DANA', "Livin' by Mandiri"]) {
    for (final amount in ['Rp 25.000,00', 'rp25,000.00', 'IDR 25000.00']) {
      test('$bank preserves decimals in $amount', () {
        final tx = QrisParser.parseReceipt('''
$bank
DANA Protection
Sumber Dana: $bank
Penerima
CHICKEN
Pembayaran ke CHICKEN
Total Bayar
$amount
Total Transaksi
$amount
''');
        expect(tx.numericNominal, 25000);
        expect(tx.merchant, 'CHICKEN');
        expect(tx.category, 'Makanan');
      });
    }
  }

  final amounts = <String, String>{
    'BCA net total': 'BCA Syariah\nTujuan CHICKEN\nNominal Rp30.000\nDiskon Rp5.000\nTotal Transaksi Rp25.000',
    'GoPay balance': 'GoPay\nSaldo Rp900.000\nRincian transaksi\nMerchant name CHICKEN\nTotal Rp25.000',
    'cash tendered': 'Merchant: CHICKEN\nMetode pembayaran: Tunai\nTotal Rp25.000\nTunai Rp100.000\nKembalian Rp75.000',
    'cash payment total': 'Merchant: CHICKEN\nMetode pembayaran: Tunai\nTotal pembayaran tunai Rp25.000\nTunai Rp100.000',
    'bare total next line': 'SeaBank\nMerchant: CHICKEN\nTotal\n25.000',
    'bare total inline': 'SeaBank\nMerchant: CHICKEN\nTotal: 25.000',
  };
  for (final entry in amounts.entries) {
    test('${entry.key} selects the actual payment', () {
      final tx = QrisParser.parseReceipt(entry.value);
      expect(tx.numericNominal, 25000);
      expect(tx.merchant, 'CHICKEN');
    });
  }

  test('bare references and bank accounts are never purchase amounts', () {
    final tx = QrisParser.parseReceipt('''
SeaBank
Merchant: CHICKEN
No. rekening
1234567890
Referensi 999999999
''');
    expect(tx.numericNominal, 0);
  });

  test('zero net total stays zero in a dedicated parser', () {
    final tx = QrisParser.parseReceipt('''
BCA Syariah
Tujuan CHICKEN
Nominal Rp25.000
Diskon Rp25.000
Total Transaksi Rp0
''');
    expect(tx.numericNominal, 0);
  });

  test('unknown bank cannot impersonate BCA Syariah using generic fields', () {
    final tx = QrisParser.parseReceipt('''
Bank Contoh
Pembayaran QRIS Berhasil
Sumber Dana 123***456
Tujuan CHICKEN
Total Transaksi Rp25.000
''');
    expect(tx.source, 'Tidak Diketahui');
    expect(tx.merchant, 'CHICKEN');
  });

  test('split recipient bank stays excluded from source detection', () {
    final tx = QrisParser.parseReceipt('''
QRIS
Nama Acquirer
BCA
SYARIAH
Merchant CHICKEN
Total Rp25.000
''');
    expect(tx.source, 'Tidak Diketahui');
    expect(tx.merchant, 'CHICKEN');
  });

  test('a recoverable BNI layout error uses general extraction', () {
    final tx = QrisParser.parseReceipt('''
BNI
Pembayaran QRIS Berhasil
Nama Merchant CHICKEN
Total Pembayaran Rp25.000
''');
    expect(tx.source, 'BNI');
    expect(tx.merchant, 'CHICKEN');
    expect(tx.numericNominal, 25000);
  });

  for (final receipt in [
    "Livin' by Mandiri\nPenerima CHICKEN\nTotal Transaksi Rp25.000",
    'ShopeePay\nPembayaran Berhasil\nNo. Transaksi 123456\nMerchant: CHICKEN\nTotal Pembayaran Rp25.000',
  ]) {
    test(
      'metadata does not replace merchant in ${receipt.split('\n').first}',
      () {
        final tx = QrisParser.parseReceipt(receipt);
        expect(tx.merchant, 'CHICKEN');
        expect(tx.category, 'Makanan');
      },
    );
  }

  test('a wallet alias inside a merchant name remains a merchant', () {
    final tx = QrisParser.parseReceipt(
      'SeaBank\nMerchant: DANA MART\nTotal Rp25.000',
    );
    expect(tx.source, 'SeaBank');
    expect(tx.merchant, 'DANA MART');
  });

  test(
    'multiline promo cannot change method or bypass the dedicated parser',
    () {
      final tx = QrisParser.parseReceipt('''
BCA Syariah
Tujuan CHICKEN JAKARTA
Total Transaksi Rp25.000
Promo
Bayar pakai PayLater dapat cashback
''');
      expect(tx.paymentMethod, 'QRIS');
      expect(tx.merchant, 'CHICKEN');
      expect(tx.source, 'BCA Syariah');
    },
  );

  test('a multiline purchase detail refines warung category', () {
    final tx = QrisParser.parseReceipt('''
SeaBank
Merchant: WARUNG BU SITI
Produk
Token listrik
Total Rp25.000
''');
    expect(tx.category, 'Tagihan & Pulsa');
    expect(tx.merchant, 'WARUNG BU SITI');
  });

  for (final merchant in [
    'KFC',
    'KFC DEPOK',
    'WARUNG TEKKO',
    'WARUNG LEKO',
    'WARUNG AYAM SOGIL',
    'AYAM BANG DOYOK',
  ]) {
    test('$merchant is food even with a contextual workbook entry', () {
      expect(
        TransactionClassifier.classify(merchant: merchant).category,
        'Makanan',
      );
    });
  }

  test('food corrections preserve groceries and generic warung', () {
    for (final merchant in [
      'AYAM MENTAH',
      'RAW CHICKEN',
      'DAGING AYAM',
      'TELUR AYAM',
      'WARUNG BU SITI',
    ]) {
      expect(
        TransactionClassifier.classify(merchant: merchant).category,
        'Belanja',
      );
    }
    expect(
      TransactionClassifier.classify(
        merchant: 'WARUNG BU SITI',
        receiptText: 'Produk\nAlamat: KOPI SUSU',
      ).category,
      'Belanja',
    );
  });
}
