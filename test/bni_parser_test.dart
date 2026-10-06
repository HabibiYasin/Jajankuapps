import 'package:flutter_application_1/services/qris_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mobile = '''
BNI
Transaksi Berhasil
Nama Merchant WATSON BTS BOTANI SQUARE
Merchant PAN 123456789
Nama Acquirer Bank BRI
Tanggal Transaksi 05-09-2023
Waktu Transaksi 11:59:59 WIB
Nama Issuer Bank BNI
Jenis Transaksi Pembayaran QRIS
Nominal Bayar Rp474.800,00
Tip Rp0,00
Total Bayar Rp474.800,00
''';
  const wondr = '''
wondr by BNI
Pembayaran QRIS berhasil
Rp74.000
13 Jun 2025 • 17:16:04 WIB
Penerima
Elias Jordan Systems
JAKARTA PUSAT
Sumber dana
NASABAH
Detail pembayaran
Nominal Rp74.000
Total Rp74.000
Nama issuer Bank BNI
Tipe transaksi QRIS
''';
  test('BNI Mobile memakai total dan bukan bank acquirer', () {
    final tx = QrisParser.parseReceipt(mobile);
    expect(tx.source, 'BNI Mobile Banking');
    expect(tx.merchant, 'WATSON BTS BOTANI SQUARE');
    expect(tx.numericNominal, 474800);
    expect(tx.dateTime, DateTime(2023, 9, 5, 11, 59, 59));
  });
  test('wondr membaca penerima, total, dan tanggal', () {
    final tx = QrisParser.parseReceipt(wondr);
    expect(tx.source, 'wondr by BNI');
    expect(tx.merchant, 'Elias Jordan Systems');
    expect(tx.numericNominal, 74000);
    expect(tx.dateTime, DateTime(2025, 6, 13, 17, 16, 4));
  });
  test('membaca kolom label dan nilai yang dipisahkan OCR', () {
    final tx = QrisParser.parseReceipt(
      mobile
          .replaceAll('Nama Merchant ', 'Nama Merchant\n')
          .replaceAll('Total Bayar ', 'Total Bayar\n'),
    );
    expect(tx.merchant, 'WATSON BTS BOTANI SQUARE');
    expect(tx.numericNominal, 474800);
  });
  test('menolak status kedua gambar referensi', () {
    expect(
      () => QrisParser.parseReceipt(
        wondr.replaceAll('QRIS berhasil', 'QRIS belum berhasil'),
      ),
      throwsFormatException,
    );
    expect(
      () => QrisParser.parseReceipt(
        mobile.replaceAll('Transaksi Berhasil', 'Transaksi Sedang Diproses'),
      ),
      throwsFormatException,
    );
  });
}
