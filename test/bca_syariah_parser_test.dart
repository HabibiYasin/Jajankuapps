import 'package:flutter_application_1/services/qris_parser.dart';
import 'package:flutter_application_1/services/parsers/bca_syariah_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const receipt = '''
Transaksi Berhasil
Sumber Dana BUDI SANTOSO 123***456
Tujuan D BEST CHICKEN JAKARTA
Lokasi Merchant JAKARTA
Total Transaksi Rp25.000
Saldo Rp900.000
10 Oktober 2026 12:34:56
''';

  for (final header in [
    'BCA Syariah\n',
    'BCA   SYARIAH\n',
    'BCA\nSYARIAH\n',
    'BCAsyariah\n',
    'BCA\nBCAsyariah\n',
    'BCAsyarnah\n',
    'BCA syarnah\n',
    'BCA\nsyarnah\n',
  ]) {
    test('BCA Syariah layout takes priority with header "$header"', () {
      final tx = QrisParser.parseReceipt('$header$receipt');
      expect(tx.source, 'BCA Syariah');
      // The dedicated parser removes the trailing city from this layout.
      expect(tx.merchant, 'D BEST CHICKEN');
      expect(tx.numericNominal, 25000);
      expect(tx.category, 'Makanan');
      expect(tx.paymentMethod, 'QRIS');
      expect(tx.dateTime, DateTime(2026, 10, 10, 12, 34, 56));
    });
  }

  test('dedicated parser recognizes the joined logo without layout labels', () {
    expect(BcaSyariahParser.isMatch('BCAsyariah\nQRIS'), isTrue);
    expect(BcaSyariahParser.isMatch('BCAsyarnah\nQRIS'), isTrue);
  });

  for (final label in ['tujuan: ', 'TUJUAN : ', 'Tujuan\n']) {
    test('reads merchant from destination label "$label"', () {
      final tx = QrisParser.parseReceipt(
        'BCA Syariah\n${receipt.replaceAll('Tujuan ', label)}',
      );
      expect(tx.source, 'BCA Syariah');
      expect(tx.merchant, 'D BEST CHICKEN');
      expect(tx.category, 'Makanan');
      expect(tx.numericNominal, 25000);
    });
  }

  for (final header in [
    'BCA\nPembayaran QRIS\nBCA Syariah\n',
    'BCA\nSYARIAH Mobile\n',
  ]) {
    test('partial BCA logo does not hide the full bank name "$header"', () {
      final tx = QrisParser.parseReceipt('$header$receipt');
      expect(tx.source, 'BCA Syariah');
      expect(tx.merchant, 'D BEST CHICKEN');
      expect(tx.numericNominal, 25000);
    });
  }

  for (final destination in [
    'Nama Acquirer: BCA Syariah',
    'Nama Acquirer: BCAsyariah',
    'Nama Acquirer: BCAsyarnah',
    'Bank tujuan\nBCA\nSYARIAH Mobile',
    'Merchant: BCA Syariah',
  ]) {
    test('BCA source is preserved when destination is "$destination"', () {
      final tx = QrisParser.parseReceipt('''
BCA
QRIS
$destination
Total Rp25.000
''');
      expect(tx.source, 'BCA');
    });
  }

  test('explicit BCA payer takes precedence over a BCA Syariah logo', () {
    final tx = QrisParser.parseReceipt('''
BCA Syariah
Sumber Dana: BCA
Merchant: TOKO MAJU
Total Rp25.000
''');
    expect(tx.source, 'BCA');
  });

  test('warung is shopping through the BCA Syariah receipt pipeline', () {
    final tx = QrisParser.parseReceipt(
      'BCA Syariah\n${receipt.replaceAll('D BEST CHICKEN', 'WARUNG BU SITI')}',
    );
    expect(tx.source, 'BCA Syariah');
    expect(tx.merchant, 'WARUNG BU SITI');
    expect(tx.category, 'Belanja');
  });

  test('missing bank identity stays unknown despite generic layout labels', () {
    final tx = QrisParser.parseReceipt(receipt);
    expect(tx.source, 'Tidak Diketahui');
    expect(tx.merchant, 'D BEST CHICKEN JAKARTA');
    expect(tx.numericNominal, 25000);
  });

  test('receiving bank does not select the BCA Syariah parser', () {
    final tx = QrisParser.parseReceipt('''
QRIS
Nama Acquirer: BCA Syariah
Merchant: WARUNG BU SITI
Total Rp25.000
''');
    expect(tx.source, 'Tidak Diketahui');
    expect(tx.merchant, 'WARUNG BU SITI');
  });

  test('unsupported BCA Syariah methods still use the general parser', () {
    final tx = QrisParser.parseReceipt('''
BCA Syariah
Metode pembayaran: Transfer
Sumber Dana: BCA Syariah
Tujuan
BCA
1234567890
BUDI SANTOSO
Total Transaksi Rp25.000
''');
    expect(tx.source, 'BCA Syariah');
    expect(tx.paymentMethod, 'Transfer');
    expect(tx.merchant, 'BUDI SANTOSO');
    expect(tx.numericNominal, 25000);
  });

  test('unknown layout uses the general parser and common merchant cues', () {
    for (final merchant in ['D BEST CHICKEN', 'WARUNG BU SITI']) {
      final tx = QrisParser.parseReceipt('''
SeaBank
Pembayaran Berhasil
$merchant
Total Rp25.000
''');
      expect(tx.source, 'SeaBank');
      expect(tx.merchant, merchant);
      expect(tx.category, merchant.contains('CHICKEN') ? 'Makanan' : 'Belanja');
      expect(tx.numericNominal, 25000);
    }
  });
}
