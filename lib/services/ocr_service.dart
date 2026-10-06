import 'dart:io';
import 'dart:math'; // <-- PENTING: Tambahkan import math untuk fungsi min() & max()

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/transaction_model.dart';
import 'qris_parser.dart';

class OcrService {
  static Future<TransactionModel> processImage(File imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(imageFile);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);

      // Menggabungkan teks menggunakan Intersection / Tumpang Tindih
      String formattedText = extractSpatialText(recognizedText);

      final transaction = QrisParser.parseReceipt(formattedText);
      DateTime receiptDateTime = extractDateTimeFromOCR(formattedText);

      textRecognizer.close();

      return TransactionModel(
        merchant: transaction.merchant,
        category: transaction.category,
        nominalStr: transaction.nominalStr,
        numericNominal: transaction.numericNominal,
        dateTime: receiptDateTime,
        source: transaction.source,
      );
    } catch (e) {
      textRecognizer.close();
      throw Exception("Gagal memproses gambar: $e");
    }
  }

  // FUNGSI SPASIAL INTERSECTION (Paling Akurat):
  // Menyatukan teks kiri dan kanan berdasarkan tumpang tindih jalur horizontal
  static String extractSpatialText(RecognizedText recognizedText) {
    List<TextLine> allLines = [];

    for (TextBlock block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }

    if (allLines.isEmpty) return "";

    List<List<TextLine>> rows = [];

    for (TextLine line in allLines) {
      bool addedToRow = false;

      final lineHeight = line.boundingBox.height;
      final lineCenterY = line.boundingBox.center.dy;

      for (List<TextLine> row in rows) {
        final rowCenterY =
            row.map((e) => e.boundingBox.center.dy).reduce((a, b) => a + b) /
            row.length;
        final rowAverageHeight =
            row.map((e) => e.boundingBox.height).reduce((a, b) => a + b) /
            row.length;

        // Bandingkan pusat vertikal, bukan tinggi gabungan row. Tinggi gabungan
        // dapat membesar dan menyebabkan teks dari baris tetangga ikut tertarik.
        final tolerance = min(lineHeight, rowAverageHeight) * 0.45;
        if ((lineCenterY - rowCenterY).abs() <= tolerance) {
          row.add(line);
          addedToRow = true;
          break;
        }
      }

      // Buat baris baru jika teks tidak sejajar dengan baris manapun
      if (!addedToRow) {
        rows.add([line]);
      }
    }

    // Urutkan baris dari atas ke bawah layar
    rows.sort((a, b) {
      double aTop = a.map((e) => e.boundingBox.top).reduce(min);
      double bTop = b.map((e) => e.boundingBox.top).reduce(min);
      return aTop.compareTo(bTop);
    });

    // Urutkan teks di dalam baris dari kiri ke kanan, lalu gabungkan dengan spasi
    List<String> combinedText = [];
    for (List<TextLine> row in rows) {
      row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      combinedText.add(row.map((e) => e.text).join(' '));
    }

    return _normalizeReceiptRows(combinedText).join('\n');
  }

  static List<String> _normalizeReceiptRows(List<String> rows) {
    final normalized = List<String>.from(rows);

    for (int i = 0; i < normalized.length; i++) {
      // Logo Jago dapat dikenali sebagai "Uago" atau karakter beraksen lain.
      // Field Jago memang tersusun vertikal, sehingga baris label dan nilainya
      // sengaja tidak digabung di tahap OCR.
      normalized[i] = normalized[i].replaceFirst(
        RegExp(r'^\S*ago\s+Syariah$', caseSensitive: false),
        'Jago Syariah',
      );

      // Watermark BCA Syariah kadang terbaca sebagai "Aarnah" tepat di
      // antara label Tujuan dan nama merchant.
      normalized[i] = normalized[i].replaceFirst(
        RegExp(r'^(Tujuan)\s+Aarnah\s+', caseSensitive: false),
        r'$1 ',
      );

      final sourceMatch = RegExp(
        r'^Sumber\s+Dana(?:\s+(.*))?$',
        caseSensitive: false,
      ).firstMatch(normalized[i]);
      if (sourceMatch == null || i == 0) continue;

      final previous = normalized[i - 1].trim();
      var accountNumber = (sourceMatch.group(1) ?? '').trim();
      final looksLikeAccountName = RegExp(r'^[A-Z][A-Z\s.]{3,}$')
          .hasMatch(previous);
      var accountIsOnNextRow = false;

      if (!RegExp(r'\d{3,}\*+\d+').hasMatch(accountNumber) &&
          i + 1 < normalized.length &&
          RegExp(r'^\d{3,}\*+\d+$').hasMatch(normalized[i + 1].trim())) {
        accountNumber = normalized[i + 1].trim();
        accountIsOnNextRow = true;
      }

      final hasMaskedAccount = RegExp(r'\d{3,}\*+\d+').hasMatch(accountNumber);

      // Pada layout BCA Syariah, nama dan nomor sumber dana berada pada dua
      // baris kanan. OCR dapat menaruh nama satu baris sebelum labelnya.
      if (looksLikeAccountName && hasMaskedAccount) {
        normalized[i] = 'Sumber Dana $previous $accountNumber';
        if (accountIsOnNextRow) normalized.removeAt(i + 1);
        normalized.removeAt(i - 1);
        i--;
      }
    }

    return normalized;
  }

  static DateTime extractDateTimeFromOCR(String recognizedText) {
    final dateRegexIso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');
    final dateRegexNumeric = RegExp(
      r'\b(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})\b',
    );
    // Gunakan spasi horizontal, bukan \s, supaya regex tidak menyeberang
    // newline (misalnya "18:16\nTanggal 26" menjadi "16 Tanggal 26").
    final dateRegexText = RegExp(
      r'\b(\d{1,2})[ \t]+([A-Za-z]{3,9})[ \t]+(\d{2,4})\b',
    );
    final timeRegex = RegExp(
      r'\b([0-1]?[0-9]|2[0-3]):([0-5][0-9])(?::([0-5][0-9]))?\s*([APap][Mm])?\b',
    );

    int? day, month, year;
    int hour = 0, minute = 0, second = 0;

    for (final textMatch in dateRegexText.allMatches(recognizedText)) {
      final parsedMonth = _parseIndonesianMonth(textMatch.group(2)!);
      if (parsedMonth == null) continue;

      day = int.parse(textMatch.group(1)!);
      month = parsedMonth;
      final parsedYear = int.parse(textMatch.group(3)!);
      year = parsedYear < 100 ? 2000 + parsedYear : parsedYear;
      break;
    }

    if (day == null) {
      final isoMatch = dateRegexIso.firstMatch(recognizedText);
      final numericMatch = dateRegexNumeric.firstMatch(recognizedText);
      if (isoMatch != null) {
        year = int.parse(isoMatch.group(1)!);
        month = int.parse(isoMatch.group(2)!);
        day = int.parse(isoMatch.group(3)!);
      } else if (numericMatch != null) {
        day = int.parse(numericMatch.group(1)!);
        month = int.parse(numericMatch.group(2)!);
        int parsedYear = int.parse(numericMatch.group(3)!);
        year = parsedYear < 100 ? 2000 + parsedYear : parsedYear;
      }
    }

    final timeMatch = timeRegex.firstMatch(recognizedText);
    if (timeMatch != null) {
      hour = int.parse(timeMatch.group(1)!);
      minute = int.parse(timeMatch.group(2)!);
      if (timeMatch.group(3) != null) {
        second = int.parse(timeMatch.group(3)!);
      }

      String? amPm = timeMatch.group(4);
      if (amPm != null) {
        if (amPm.toUpperCase() == 'PM' && hour < 12) hour += 12;
        if (amPm.toUpperCase() == 'AM' && hour == 12) hour = 0;
      }
    }

    if (day != null && month != null && year != null) {
      return DateTime(year, month, day, hour, minute, second);
    }

    return DateTime.now();
  }

  static int? _parseIndonesianMonth(String monthStr) {
    String sanitized = monthStr
        .toLowerCase()
        .replaceAll('1', 'i')
        .replaceAll('l', 'i')
        .replaceAll('q', 'g')
        .replaceAll('0', 'o')
        .replaceAll('5', 's');

    const months = {
      'jan': 1,
      'januari': 1,
      'feb': 2,
      'februari': 2,
      'mar': 3,
      'maret': 3,
      'apr': 4,
      'april': 4,
      'mei': 5,
      'may': 5,
      'mel': 5,
      'jun': 6,
      'juni': 6,
      'jul': 7,
      'juli': 7,
      'jui': 7,
      'agu': 8,
      'agust': 8,
      'agustus': 8,
      'aug': 8,
      'ags': 8,
      'sep': 9,
      'september': 9,
      'okt': 10,
      'oktober': 10,
      'oct': 10,
      'nov': 11,
      'november': 11,
      'des': 12,
      'desember': 12,
      'dec': 12,
    };

    // Bulan yang tidak dikenal tidak boleh diam-diam dianggap Januari.
    return months[sanitized];
  }
}
