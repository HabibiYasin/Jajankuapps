import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_application_1/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('google_mlkit_text_recognizer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  for (final method in ['Transfer', 'VA', 'Pay Later']) {
    test(
      'image OCR preserves $method and receipt time through the full pipeline',
      () async {
        var closed = false;
        final lines = [
          '09:00', // Phone status bar must not override transaction time.
          'SeaBank',
          'Metode pembayaran: $method',
          'Penerima: TOKO MAJU',
          'Nominal Rp50.000',
          '07 Oktober 2026 14:35:21',
        ];
        Map<String, double> rect(int index) => {
          'left': 0,
          'top': index * 30.0,
          'right': 300,
          'bottom': index * 30.0 + 20,
        };
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'vision#closeTextRecognizer') {
            closed = true;
            return null;
          }
          return {
            'text': lines.join('\n'),
            'blocks': [
              {
                'text': lines.join('\n'),
                'rect': rect(0),
                'recognizedLanguages': <String>[],
                'points': <Object>[],
                'lines': [
                  for (var i = 0; i < lines.length; i++)
                    {
                      'text': lines[i],
                      'rect': rect(i),
                      'recognizedLanguages': <String>[],
                      'points': <Object>[],
                      'elements': <Object>[],
                    },
                ],
              },
            ],
          };
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final tx = await OcrService.processImage(File('mock-receipt.png'));
        expect(tx.paymentMethod, method == 'Pay Later' ? 'PayLater' : method);
        expect(tx.source, 'SeaBank');
        expect(tx.merchant, 'TOKO MAJU');
        expect(tx.numericNominal, 50000);
        expect(tx.dateTime, DateTime(2026, 10, 7, 14, 35, 21));
        expect(closed, isTrue);
      },
    );
  }
}
