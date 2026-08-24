import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';

class ExportService {
  static Future<void> exportTransactionsToCSV(List<TransactionModel> history) async {
    if (history.isEmpty) return;

    // Gunakan pemisah titik koma (;) agar Excel otomatis memecahnya ke kolom berbeda
    StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln('No;Merchant;Kategori;Nominal (Rp);Tanggal & Waktu');

    for (int i = 0; i < history.length; i++) {
      var tx = history[i];
      // Format angka tanpa desimal .0 agar terlihat lebih bersih
      String cleanNominal = tx.numericNominal.toStringAsFixed(0);
      
      csvBuffer.writeln(
        '${i + 1};"${tx.merchant}";"${tx.category}";$cleanNominal;"${tx.formattedTime}"',
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/laporan_pengeluaran_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csvBuffer.toString());

    await Share.shareXFiles(
      [XFile(path)],
      text: 'Berikut adalah laporan data pengeluaran QRIS Expense Tracker saya.',
    );
  }
}