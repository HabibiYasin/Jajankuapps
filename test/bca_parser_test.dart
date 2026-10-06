import 'package:flutter_application_1/services/qris_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Teks dari gambar referensi; nomor rekening dan referensi disamarkan.
  const receipt = '''
Pembayaran QR
BERHASIL
03/10/2026 - 14:08:07 WIB
IDM INDOMARET D
JAKARTA UTARA
BCA - 123456789
TID: A1BP1629
TOTAL PEMBAYARAN: Rp 35.700
Dari 123456789
CPAN: 123456789
No. Transaksi: CARDLESS123456
RRN: 123456
Ref 123456
''';
  test('membaca format BCA dari gambar referensi', () {
    final tx = QrisParser.parseReceipt(receipt);
    expect(tx.source, 'BCA');
    expect(tx.merchant, 'IDM INDOMARET D');
    expect(tx.nominalStr, 'Rp35.700');
    expect(tx.numericNominal, 35700);
    expect(tx.dateTime, DateTime(2026, 10, 3, 14, 8, 7));
  });
  test('tetap membaca format tanpa tanda hubung dan spasi rupiah', () {
    final tx = QrisParser.parseReceipt(
      receipt.replaceAll(' - 14:', ' 14:').replaceAll('Rp 35.700', 'Rp35.700'),
    );
    expect(tx.merchant, 'IDM INDOMARET D');
    expect(tx.numericNominal, 35700);
    expect(tx.dateTime, DateTime(2026, 10, 3, 14, 8, 7));
  });
  test('membaca nominal di baris berikutnya dan melewati watermark BCA', () {
    final tx = QrisParser.parseReceipt(
      receipt
          .replaceAll('TOTAL PEMBAYARAN: Rp', 'TOTAL PEMBAYARAN:\nrp')
          .replaceAll('WIB\nIDM', 'WIB\nBCA\nIDM')
          .replaceAll('35.700', '35.700,00'),
    );
    expect(tx.merchant, 'IDM INDOMARET D');
    expect(tx.numericNominal, 35700);
  });
}
