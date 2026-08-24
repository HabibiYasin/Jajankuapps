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
      // Oper teks mentah ke kelas Parser
      final transaction = QrisParser.parseReceipt(recognizedText.text);
      textRecognizer.close();
      return transaction;
    } catch (e) {
      textRecognizer.close();
      throw Exception("Gagal memproses gambar: $e");
    }
  }
}