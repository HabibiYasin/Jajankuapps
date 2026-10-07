import 'package:flutter_application_1/data/payment_sources.dart';
import 'package:flutter_application_1/services/parsers/general_parser.dart';
import 'package:flutter_application_1/services/payment_source_detector.dart';
import 'package:flutter_application_1/services/qris_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unknown layout extracts largest purchase, merchant, source and date',
    () {
      final tx = QrisParser.parseReceipt('''
SeaBank
Pembayaran berhasil
Merchant: KOPI KENANGAN
Harga Rp30.000
Biaya Rp1.000
Total Rp31.000
Saldo Rp9.000.000
07 Oktober 2026, 14:35:21 WIB
Metode pembayaran: QRIS
''');
      expect(tx.numericNominal, 31000);
      expect(tx.nominalStr, 'Rp31.000');
      expect(tx.source, 'SeaBank');
      expect(tx.merchant, 'KOPI KENANGAN');
      expect(tx.category, 'Minuman');
      expect(tx.paymentMethod, 'QRIS');
      expect(tx.dateTime, DateTime(2026, 10, 7, 14, 35, 21));
    },
  );

  for (final total in [
    'Total pembayaran',
    'Total',
    'Kamu membayar',
    'Setelah diskon',
  ]) {
    test('discount prefers net $total without subtracting twice', () {
      final tx = QrisParser.parseReceipt('''
LinkAja
Nama merchant
RESTORAN CONTOH
Subtotal Rp100.000
Diskon Rp20.000
$total Rp80.000
Cashback Rp5.000
''');
      expect(tx.numericNominal, 80000);
      expect(tx.merchant, 'RESTORAN CONTOH');
      expect(tx.source, 'LinkAja');
    });
  }

  test('deducts printed discount when no net total exists', () {
    expect(
      QrisParser.parseReceipt('Harga Rp100.000\nDiskon\nRp20.000')
          .numericNominal,
      80000,
    );
    expect(
      QrisParser.parseReceipt('Harga Rp100.000\nCashback Rp20.000')
          .numericNominal,
      100000,
    );
    expect(
      QrisParser.parseReceipt('Harga Rp100.000\nDiskon Rp200.000')
          .numericNominal,
      100000,
    );
    expect(
      QrisParser.parseReceipt(
        'Harga Rp100.000\nDiskon Rp100.000\nTotal bayar Rp0',
      ).numericNominal,
      0,
    );
  });

  test('currency decimals and split OCR do not become account numbers', () {
    for (final amount in ['Rp 123.456,78', 'rp123,456.78', 'IDR 123456.78']) {
      final tx = QrisParser.parseReceipt(
        'No. rekening 9999999999999\nTotal $amount',
      );
      expect(tx.numericNominal, 123456.78);
      expect(tx.nominalStr, 'Rp123.456,78');
    }
    expect(
      QrisParser.parseReceipt('Total\nRp\n25.000,00').numericNominal,
      25000,
    );
    expect(
      QrisParser.parseReceipt('Nomor referensi 1234567890').numericNominal,
      0,
    );
    expect(
      QrisParser.parseReceipt('Rp 10.000 dan Rp 20.000').numericNominal,
      20000,
    );
  });

  test('source comes from sender field, not receiving bank or acquirer', () {
    final tx = QrisParser.parseReceipt('''
Transfer berhasil
Bank tujuan: BCA
Penerima
BUDI SANTOSO
1234567890
Sumber dana
Jenius
Total transaksi Rp250.000
07/10/2026 11:20
''');
    expect(tx.source, 'SMBC Indonesia');
    expect(tx.merchant, 'BUDI SANTOSO');
    expect(tx.paymentMethod, 'Transfer');
    expect(tx.numericNominal, 250000);
  });

  test('transfer destination skips bank and account before recipient', () {
    final tx = QrisParser.parseReceipt('''
BRImo
Transfer berhasil
Tujuan
BCA
1234567890
SITI AMINAH
Sumber dana: BRI
Nominal Rp150.000
''');
    expect(tx.source, 'BRI');
    expect(tx.merchant, 'SITI AMINAH');
    expect(tx.paymentMethod, 'Transfer');
  });

  test('generic labels cannot impersonate Mandiri or BCA Syariah', () {
    for (final name in ['SeaBank', 'Bank Mega Syariah', 'BCA Digital']) {
      final tx = QrisParser.parseReceipt('''
$name
Sumber dana: $name
Tujuan: WARUNG AYAM
Penerima: WARUNG AYAM
Total transaksi Rp25.000
''');
      expect(tx.source, name);
      expect(tx.merchant, 'WARUNG AYAM');
    }
    final tx = QrisParser.parseReceipt(
      'Sumber dana\nTujuan WARUNG AYAM\nTotal transaksi Rp25.000',
    );
    expect(tx.source, 'Tidak Diketahui');
    expect(tx.numericNominal, 25000);
    for (final header in [
      'Pembayaran QR\nRRN 12345',
      'QRIS\nNama Acquirer\nBSI',
    ]) {
      final unknown = QrisParser.parseReceipt(
        '$header\nMerchant: TOKO MAJU\nTotal Rp10.000',
      );
      expect(unknown.source, 'Tidak Diketahui');
      expect(unknown.merchant, 'TOKO MAJU');
      expect(unknown.numericNominal, 10000);
    }
  });

  test(
    'uses workbook source names and specific aliases with word boundaries',
    () {
      expect(paymentSources.length, 126);
      for (final source in paymentSources) {
        expect(
          PaymentSourceDetector.match(source.$1),
          source.$1,
          reason: source.$1,
        );
      }
      for (final entry in {
        'blu by BCA Digital': 'BCA Digital',
        'bank bjb syariah': 'bank bjb syariah',
        'Livin by Mandiri': 'Bank Mandiri',
        'OCTO Mobile': 'CIMB Niaga',
        'MotionPay': 'MotionPay',
        'MotionBank': 'MNC Bank',
        'i.saku': 'i.saku',
        'Go-Pay': 'GoPay',
      }.entries) {
        expect(PaymentSourceDetector.match(entry.key), entry.value);
      }
      expect(
        PaymentSourceDetector.match('Novotel sumber dana pribadi'),
        isNull,
      );
      expect(
        PaymentSourceDetector.detect([
          'Bank tujuan: BCA',
          'Penerima: Budi',
          'Total Rp1.000',
        ]),
        isNull,
      );
      expect(
        PaymentSourceDetector.detect([
          'Nama Acquirer',
          'BNI',
          'Nominal Rp5.000',
        ]),
        isNull,
      );
      expect(
        PaymentSourceDetector.detect(['Metode pembayaran: LinkAja']),
        'LinkAja',
      );
      expect(PaymentSourceDetector.detect(['Dari BCA', 'Ke BNI']), 'BCA');
    },
  );

  test('merchant falls back to existing category keywords', () {
    final tx = QrisParser.parseReceipt('''
Sumber dana: blu
Pembayaran berhasil
Pengirim
KOPI PRIBADI
ALFAMART JAKARTA
Rp25.000
''');
    expect(tx.merchant, 'ALFAMART JAKARTA');
    expect(tx.category, 'Belanja');
    expect(
      QrisParser.parseReceipt('TOKO MAJU Merchant\nRp10.000').merchant,
      'TOKO MAJU',
    );
    expect(
      QrisParser.parseReceipt('Merchant PAN: 12345\nTotal Rp1.000').merchant,
      'Tidak Diketahui',
    );
  });

  for (final entry in {
    'Transfer BI-FAST': 'Transfer',
    'TRF': 'Transfer',
    'Transfer Virtual Account': 'VA',
    'VA': 'VA',
    'QRIS': 'QRIS',
    'QR Code': 'QRIS',
    'SPayLater': 'PayLater',
    'Pay Later': 'PayLater',
    'GoPayLater': 'PayLater',
    'Tunai': 'Cash',
  }.entries) {
    test('method ${entry.key} maps to supported ${entry.value}', () {
      final tx = QrisParser.parseReceipt(
        'Metode pembayaran: ${entry.key}\nMerchant: TOKO MAJU\nRp10.000',
      );
      expect(tx.paymentMethod, entry.value);
      expect(tx.numericNominal, 10000);
    });
  }

  test('explicit method beats promos and does not match VA inside a name', () {
    expect(
      GeneralParser.detectMethod('Metode pembayaran: QRIS\nPromo Pay Later'),
      'QRIS',
    );
    expect(GeneralParser.detectMethod('OVO Cash Terpakai Rp1.000'), 'QRIS');
    expect(GeneralParser.detectMethod('JAVA COFFEE\nRp20.000'), 'QRIS');
    expect(
      GeneralParser.detectMethod('Metode pembayaran\nTransfer\nPromo QRIS'),
      'Transfer',
    );
  });

  for (final stamp in [
    '07/10/2026 14:35:21',
    '07-10-26 14:35:21',
    '2026-10-07T14:35:21',
    '07 Oct 2026, 02:35:21 PM',
    '07 Oktober 2026\nWaktu\n14.35.21 WIB',
  ]) {
    test('reads date and clock $stamp', () {
      expect(
        GeneralParser.extractDateTime(['09:00', ...stamp.split('\n')]),
        DateTime(2026, 10, 7, 14, 35, 21),
      );
    });
  }

  test('validates dates and ignores phone clock when date has no time', () {
    expect(GeneralParser.extractDateTime(['31/02/2026 12:00']), isNull);
    expect(GeneralParser.extractDateTime(['07/10/2026 25:00']), isNull);
    expect(
      GeneralParser.extractDateTime(['09:00', '07/10/2026']),
      DateTime(2026, 10, 7),
    );
  });

  test('fills amount missing from a recognized parser', () {
    final tx = QrisParser.parseReceipt(
      'ShopeePay\nMerchant: KOPI CONTOH\nNominal Rp12.000\n07/10/2026 10:30',
    );
    expect(tx.source, 'ShopeePay');
    expect(tx.numericNominal, 12000);
    expect(tx.dateTime, DateTime(2026, 10, 7, 10, 30));
  });
}
