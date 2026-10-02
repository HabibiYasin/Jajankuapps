import 'package:flutter_application_1/services/parsers/ovo_parser.dart';
import 'package:flutter_application_1/services/qris_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rawOvoText = '''
13:54 . N183
X
Pembayaran Berhasil
MECCA QRIS
Total Transaksi Rp2.000
OVO Cash Terpakai Rp2.000
MECCA QRIS telah menerima Rp2.000
Waktu Transaksi Berhasil
01 Sep 2026 - 09:55
Kode Transaksi
32af69ac-8802-4be4-a45c-5cccc5caecf9
Aktivitas
Detail Transaksi
Pusat Bantuan
Solusi dari masalah kamu di OVO
Tutup
''';

  test('mendeteksi bukti pembayaran OVO', () {
    expect(OvoParser.isMatch(rawOvoText), isTrue);
    expect(OvoParser.isMatch('Pembayaran Berhasil dari aplikasi lain'), isFalse);
  });

  test('router mengekstrak data transaksi OVO', () {
    final transaction = QrisParser.parseReceipt(rawOvoText);

    expect(transaction.source, 'OVO');
    expect(transaction.merchant, 'MECCA QRIS');
    expect(transaction.nominalStr, 'Rp2.000');
    expect(transaction.numericNominal, 2000);
    expect(transaction.dateTime, DateTime(2026, 9, 1, 9, 55));
    expect(transaction.category, 'Umum'); // Merchant tanpa sinyal kategori.
  });

  test('mendukung nominal yang terpisah dari label', () {
    const rawText = '''
Pembayaran Berhasil
TOKO CONTOH
Total Transaksi
Rp15.500
OVO Cash Terpakai
Rp15.500
''';

    final transaction = QrisParser.parseReceipt(rawText);

    expect(transaction.merchant, 'TOKO CONTOH');
    expect(transaction.nominalStr, 'Rp15.500');
    expect(transaction.numericNominal, 15500);
  });
}
