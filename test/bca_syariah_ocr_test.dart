import 'dart:convert';
import 'dart:io';

import 'package:flutter_application_1/services/ocr_service.dart';
import 'package:flutter_application_1/services/qris_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() {
  for (final receipt in [
    (
      file: 'bca_syariah_ocr.json',
      merchant: 'MECCA QRIS',
      amount: 2000,
      date: DateTime(2026, 10, 12, 12, 13, 58),
    ),
    (
      file: 'bca_syariah_kantin_ocr.json',
      merchant: 'Kantin Kejujuran LNSW',
      amount: 5500,
      date: DateTime(2026, 10, 12, 14, 13, 50),
    ),
  ]) {
    test('parses actual ML Kit output: ${receipt.file}', () {
      // Captured on Android from the reported image. Personal/account identifiers
      // are replaced; OCR spelling, line order and bounding boxes are preserved.
      final rows = jsonDecode(
        File('test/fixtures/${receipt.file}').readAsStringSync(),
      ) as List<dynamic>;
      final recognized = RecognizedText.fromJson({
        'text': '',
        'blocks': [
          {
            'text': '',
            'rect': {'left': 0.0, 'top': 0.0, 'right': 831.0, 'bottom': 1600.0},
            'recognizedLanguages': <String>[],
            'points': <Object>[],
            'lines': [
              for (final row in rows)
                {
                  'text': row['text'],
                  'rect': {
                    for (final key in ['left', 'top', 'right', 'bottom'])
                      key: (row[key] as num).toDouble(),
                  },
                  'recognizedLanguages': <String>[],
                  'points': <Object>[],
                  'elements': <Object>[],
                },
            ],
          },
        ],
      });

      // Simulate the logo disappearing while retaining the actual spatial rows.
      final withoutLogo = OcrService.extractSpatialText(recognized)
          .split('\n')
          .where(
            (line) =>
                !RegExp(r'bca|8cas|syar', caseSensitive: false).hasMatch(line),
          )
          .join('\n');
      final fallback = QrisParser.parseReceipt(withoutLogo);
      expect(fallback.source, 'BCA Syariah');
      expect(fallback.merchant, receipt.merchant);
      expect(fallback.numericNominal, receipt.amount);

      final text = OcrService.extractSpatialText(recognized);
      final transaction = QrisParser.parseReceipt(text);
      expect(transaction.source, 'BCA Syariah');
      expect(transaction.merchant, receipt.merchant);
      expect(transaction.numericNominal, receipt.amount);
      expect(transaction.paymentMethod, 'QRIS');
      expect(transaction.dateTime, receipt.date);
    });
  }
}
