import 'package:flutter_application_1/services/qris_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rawBriText = '''
Transaksi Berhasil
26 Aug 2026, 10:01:04 WIB
Total Transaksi
Rp125.000
No. Ref 200970251959
Sumber Dana
LAELA FITRIA SARI
BR
5849 *** *** 532
Tujuan
MbI365739 Konter Ryan
Nug
QRIS Bayar
ID 26011900000209
Jenis Transaksi QRIS Bayar
Nama Merchant MbI365739 Konter
Ryan Nug
Lokasi Merchant KUNINGAN
Nama Penerbit BRI
Nama Pengakuisisi ePay
Nomor Invoice 5L96MCTHOI5L96M
CTHOI
Kode PAN Pelanggan 93600002100781694
Merchant PAN 9360050300000898
48
ID Terminal A01
Catatan bayar air PDAM
Nominal Rp125.000
Pembayaran
Biaya Admin Rp0
Kantor Pusat BRI -Jakarta Pusat
PT. Bank Rakyat Indonesia (Persero), Tbk.
''';

  test('menggabungkan nama merchant BRI yang terpisah dua baris', () {
    final transaction = QrisParser.parseReceipt(rawBriText);

    expect(transaction.source, 'BRImo');
    expect(transaction.merchant, 'MbI365739 Konter Ryan Nug');
    expect(transaction.nominalStr, 'Rp125.000');
    expect(transaction.numericNominal, 125000);
    expect(transaction.category, 'Tagihan & Pulsa');
  });

  test('menggunakan bagian Tujuan jika field Nama Merchant tidak tersedia', () {
    const rawWithoutDetail = '''
Transaksi Berhasil
Total Transaksi
Rp10.000
Tujuan
TOKO DUA BARIS
CABANG UTARA
QRIS Bayar
ID 123456789
Kantor Pusat BRI
''';

    final transaction = QrisParser.parseReceipt(rawWithoutDetail);

    expect(transaction.merchant, 'TOKO DUA BARIS CABANG UTARA');
  });
}
