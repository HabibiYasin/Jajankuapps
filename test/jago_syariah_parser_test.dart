import 'package:flutter_application_1/services/parsers/jago_syariah_parser.dart';
import 'package:flutter_application_1/services/qris_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rawJagoText = '''
Uago Syariah
MECCA QRIS
MQ
CIAMIS
Rp2.000
ID Transaksi
260902-FX34-FEAHQJ Sukses
Sumber akun
HABIBI YASIN
Jago 508977642195
Sumber Dana
508977642195
Tanggal & waktu transaksi
02 Sep 2026, 13:59 WIB
Nama Acquirer
BNI
Biaya
Gratis
PAN Merchant
9360000915040102269
PAN Pelanggan
A01 Soo ago saon
9360054218977642190
ID Terminal
Nomor Referensi
1rwbnhe54219
Resi ini merupakan bukti transaksi yang sah
Ada pertanyaan?
Qagos Hubungi Tanya Jago 24/7
''';

  test('mendeteksi resi Jago Syariah dengan logo yang salah dibaca OCR', () {
    expect(JagoSyariahParser.isMatch(rawJagoText), isTrue);
    expect(JagoSyariahParser.isMatch('Jago biasa'), isFalse);
  });

  test('router membaca transaksi dan field vertikal Jago Syariah', () {
    final transaction = QrisParser.parseReceipt(rawJagoText);

    expect(transaction.source, 'Jago Syariah');
    expect(transaction.merchant, 'MECCA QRIS');
    expect(transaction.nominalStr, 'Rp2.000');
    expect(transaction.numericNominal, 2000);
    expect(transaction.dateTime, DateTime(2026, 9, 2, 13, 59));
    expect(transaction.category, 'Umum'); // Merchant tanpa sinyal kategori.
  });

  test('Biaya dan Gratis pada baris berbeda tidak menjadi merchant', () {
    final lines = rawJagoText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final transaction = JagoSyariahParser.parse(rawJagoText, lines);

    expect(transaction.merchant, isNot('Biaya'));
    expect(transaction.merchant, isNot('Gratis'));
  });
}
