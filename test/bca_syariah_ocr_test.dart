import 'dart:convert';
import 'dart:io';

import 'package:flutter_application_1/services/ocr_service.dart';
import 'package:flutter_application_1/services/qris_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() {
  test('parses the actual ML Kit output of the BCA Syariah receipt', () {
    // Captured on Android from the reported image. Personal/account identifiers
    // are replaced; OCR spelling, line order and bounding boxes are preserved.
    final rows = jsonDecode(
      File('test/fixtures/bca_syariah_ocr.json').readAsStringSync(),
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

    final text = OcrService.extractSpatialText(recognized);
    final transaction = QrisParser.parseReceipt(text);
    expect(transaction.source, 'BCA Syariah');
    expect(transaction.merchant, 'MECCA QRIS');
    expect(transaction.numericNominal, 2000);
    expect(transaction.paymentMethod, 'QRIS');
    expect(transaction.dateTime, DateTime(2026, 10, 12, 12, 13, 58));
  });
}
