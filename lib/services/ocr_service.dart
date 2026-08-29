import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/transaction_model.dart';
import 'qris_parser.dart';

class OcrService {
  static Future<TransactionModel> processImage(File imageFile) async {
    final textRecognizer = TextRecognizer();
    final inputImage = InputImage.fromFile(imageFile);
    
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      
      // 1. Ambil data dasar dari parser QRIS (merchant, nominal, kategori)
      final transaction = QrisParser.parseReceipt(recognizedText.text);
      
      // 2. Ekstrak tanggal & jam dari teks screenshot (mendukung format angka & teks bulan)
      DateTime receiptDateTime = _extractDateTimeFromOCR(recognizedText.text);
      
      textRecognizer.close();

      // 3. Kembalikan TransactionModel dengan tanggal yang diperbarui dari OCR
      return TransactionModel(
        merchant: transaction.merchant,
        category: transaction.category,
        nominalStr: transaction.nominalStr,
        numericNominal: transaction.numericNominal,
        dateTime: receiptDateTime, // Menggunakan waktu dari screenshot
        source: transaction.source,
      );
    } catch (e) {
      textRecognizer.close();
      throw Exception("Gagal memproses gambar: $e");
    }
  }

  // Helper untuk mendeteksi tanggal & jam dari teks OCR secara presisi (Angka & Teks Bulan)
  static DateTime _extractDateTimeFromOCR(String recognizedText) {
    // 1. Format angka (misal: 20/08/2026 atau 20-08-2026)
    final dateRegexNumeric = RegExp(r'\b(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})\b');
    
    // 2. Format teks dengan nama bulan Indonesia/Inggris (misal: 20 Ags 2026)
    final dateRegexText = RegExp(r'\b(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{2,4})\b');

    // 3. Format jam (HH:MM atau HH:MM:SS, mendukung AM/PM)
    final timeRegex = RegExp(r'\b([0-1]?[0-9]|2[0-3]):([0-5][0-9])(?::([0-5][0-9]))?\s*([APap][Mm])?\b');

    int? day, month, year;
    int hour = 0, minute = 0, second = 0;

    // Cek format teks bulan terlebih dahulu (untuk struk seperti "20 Ags 2026")
    final textMatch = dateRegexText.firstMatch(recognizedText);
    if (textMatch != null) {
      day = int.parse(textMatch.group(1)!);
      String monthStr = textMatch.group(2)!.toLowerCase();
      month = _parseIndonesianMonth(monthStr);
      int parsedYear = int.parse(textMatch.group(3)!);
      year = parsedYear < 100 ? 2000 + parsedYear : parsedYear;
    } else {
      // Jika tidak ketemu, coba format angka biasa
      final numericMatch = dateRegexNumeric.firstMatch(recognizedText);
      if (numericMatch != null) {
        day = int.parse(numericMatch.group(1)!);
        month = int.parse(numericMatch.group(2)!);
        int parsedYear = int.parse(numericMatch.group(3)!);
        year = parsedYear < 100 ? 2000 + parsedYear : parsedYear;
      }
    }

    // Parsing Jam & AM/PM
    final timeMatch = timeRegex.firstMatch(recognizedText);
    if (timeMatch != null) {
      hour = int.parse(timeMatch.group(1)!);
      minute = int.parse(timeMatch.group(2)!);
      if (timeMatch.group(3) != null) {
        second = int.parse(timeMatch.group(3)!);
      }
      
      // Penyesuaian AM/PM
      String? amPm = timeMatch.group(4);
      if (amPm != null) {
        if (amPm.toUpperCase() == 'PM' && hour < 12) hour += 12;
        if (amPm.toUpperCase() == 'AM' && hour == 12) hour = 0;
      }
    }

    // Jika tanggal lengkap ditemukan, gunakan tanggal tersebut
    if (day != null && month != null && year != null) {
      return DateTime(year, month, day, hour, minute, second);
    }

    return DateTime.now(); // Fallback jika tidak ada tanggal yang terdeteksi
  }

  // Helper untuk konversi nama bulan teks ke angka
  static int _parseIndonesianMonth(String monthStr) {
    // Normalisasi teks: Ubah ke huruf kecil dan koreksi typo OCR umum
    // - Mengubah 'l' atau '1' menjadi 'i'
    // - Mengubah 'q' menjadi 'g'
    // - Mengubah '0' menjadi 'o' (mengantisipasi angka nol tertukar huruf o)
    String sanitized = monthStr.toLowerCase()
        .replaceAll('1', 'i')
        .replaceAll('l', 'i') 
        .replaceAll('q', 'g')
        .replaceAll('0', 'o')
        .replaceAll('5', 's'); // Ubah huruf S jadi angka 5 (jika dalam konteks angka);

    const months = {
      'jan': 1, 'januari': 1,
      'feb': 2, 'februari': 2,
      'mar': 3, 'maret': 3,
      'apr': 4, 'april': 4,
      'mei': 5, 'may': 5, 'mel': 5,
      'jun': 6, 'juni': 6,
      'jul': 7, 'juli': 7, 'jui': 7,
      'agu': 8, 'agust': 8, 'agustus': 8, 'aug': 8, 'ags': 8,
      'sep': 9, 'september': 9,
      'okt': 10, 'oktober': 10, 'oct': 10,
      'nov': 11, 'november': 11,
      'des': 12, 'desember': 12, 'dec': 12,
    };

    return months[sanitized] ?? 1; // Default ke Januari (1) jika benar-benar tidak dikenali
  }
}