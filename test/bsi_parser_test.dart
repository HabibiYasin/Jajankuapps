import 'package:flutter_application_1/services/ocr_service.dart';
import 'package:flutter_application_1/services/parsers/bsi_parser.dart';
import 'package:flutter_application_1/services/qris_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Nama merchant contoh menggantikan nama yang ditutup pada gambar pengguna.
  const byond = '''
BYOND by BSI
Transaksi Pembayaran
QRIS MPM kamu Berhasil
14 Feb 2025 - 16:21:37
Nominal Transaksi Rp 2.000
Rekening Sumber
Nama Merchant TOKO CONTOH BYOND
Lokasi Merchant JAKARTA SELATAN, Indonesia
MPAN 123456789
Nama Acquirer Bank BRI
Terminal ID Acquirer CONTOH
CPAN 123456789
Nominal Transaksi Rp 2.000
Total Rp 2.000
RRN 123456789
Nomor Struk 123456789
Nomor Transaksi CONTOH
Terminal 1234
Terima kasih telah menggunakan layanan BYOND.
''';
  const mobile = '''
BSI BANK SYARIAH INDONESIA
QRIS
QRIS Payment
Status: BERHASIL
No. Transaksi: CONTOH
Referensi: 123456789
Tanggal Transaksi: 2021-04-20 19:16:39
No. Struk: CONTOH
Nama Acquirer: LinkAja
Merchant PAN: 123456789
Terminal ID Acquiring:
CONTOH
Merchant: TOKO CONTOH MOBILE
Alamat: Jakarta Selatan, 12190, ID
Jumlah: Rp 200.000
Tips: Rp 0
Total: Rp 200.000
Terima kasih telah menggunakan BSI mobile
''';

  test('router membaca BYOND tanpa mengambil bank acquirer', () {
    final tx = QrisParser.parseReceipt(byond);
    expect(tx.source, 'BYOND by BSI');
    expect(tx.merchant, 'TOKO CONTOH BYOND');
    expect(tx.nominalStr, 'Rp2.000');
    expect(tx.numericNominal, 2000);
    expect(tx.dateTime, DateTime(2025, 2, 14, 16, 21, 37));
  });
  test('router membaca BSI Mobile dan tanggal ISO', () {
    final tx = QrisParser.parseReceipt(mobile);
    expect(tx.source, 'BSI Mobile');
    expect(tx.merchant, 'TOKO CONTOH MOBILE');
    expect(tx.nominalStr, 'Rp200.000');
    expect(tx.numericNominal, 200000);
    expect(tx.dateTime, DateTime(2021, 4, 20, 19, 16, 39));
  });
  test('kolom dipisahkan OCR dan merchant terbungkus dua baris', () {
    final tx = QrisParser.parseReceipt(
      byond
          .replaceAll(
            'Nama Merchant TOKO CONTOH BYOND',
            'Nama Merchant\nTOKO CONTOH\nBYOND',
          )
          .replaceAll('Total Rp 2.000', 'Total\nRp\n2.000'),
    );
    expect(tx.merchant, 'TOKO CONTOH BYOND');
    expect(tx.numericNominal, 2000);
  });
  test('mengutamakan total yang termasuk tips', () {
    final tx = QrisParser.parseReceipt(
      mobile
          .replaceAll('Tips: Rp 0', 'Tips: Rp 5.000')
          .replaceAll('Total: Rp 200.000', 'Total: Rp 205.000,00'),
    );
    expect(tx.numericNominal, 205000);
    expect(tx.nominalStr, 'Rp205.000,00');
  });
  test('merchant tertutup tidak berubah menjadi alamat atau Merchant PAN', () {
    for (final raw in [
      mobile.replaceAll('TOKO CONTOH MOBILE', ''),
      byond.replaceAll('TOKO CONTOH BYOND', ''),
    ]) {
      expect(QrisParser.parseReceipt(raw).merchant, 'Tidak Diketahui');
    }
  });
  test('nama acquirer BSI tidak dianggap aplikasi BSI', () {
    expect(
      BsiParser.isMatch(
        'Pembayaran QRIS\nNama Acquirer Bank BSI\nNama Issuer Bank BNI',
      ),
      isFalse,
    );
  });
  test(
    'menolak gagal, pending, total tidak terbaca, dan tanggal tidak valid',
    () {
      for (final raw in [
        mobile.replaceAll('Status: BERHASIL', 'Status: GAGAL'),
        mobile.replaceAll('Status: BERHASIL', 'Status: PENDING'),
        byond.replaceAll(
          'QRIS MPM kamu Berhasil',
          'QRIS MPM kamu belum berhasil',
        ),
        byond.replaceAll('QRIS MPM kamu Berhasil', 'QRIS MPM kamu Gagal'),
        mobile.replaceAll('Rp 200.000', 'tidak terbaca'),
        mobile.replaceAll('2021-04-20', '2021-02-31'),
      ]) {
        expect(() => QrisParser.parseReceipt(raw), throwsFormatException);
      }
    },
  );
  test('OCR mempertahankan tanggal ISO BSI dan format bank lainnya', () {
    expect(
      OcrService.extractDateTimeFromOCR(mobile),
      DateTime(2021, 4, 20, 19, 16, 39),
    );
    expect(
      OcrService.extractDateTimeFromOCR(byond),
      DateTime(2025, 2, 14, 16, 21, 37),
    );
    expect(
      OcrService.extractDateTimeFromOCR('03/10/2026 - 14:08:07 WIB'),
      DateTime(2026, 10, 3, 14, 8, 7),
    );
    expect(
      OcrService.extractDateTimeFromOCR('05-09-2023\n11:59:59 WIB'),
      DateTime(2023, 9, 5, 11, 59, 59),
    );
  });
}
