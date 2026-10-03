import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction_model.dart';

class ExportService {
  static Uint8List buildWorkbook(List<TransactionModel> history) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Transaksi');
    final transactions = workbook['Transaksi'];
    final categories = workbook['Kategori'];
    final months = workbook['Bulanan'];

    void header(Sheet sheet, List<String> labels) {
      sheet.appendRow(labels.map(TextCellValue.new).toList());
      for (var column = 0; column < labels.length; column++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
            .cellStyle = CellStyle(
          bold: true,
        );
        sheet.setColumnWidth(column, column == 1 ? 32 : 24);
      }
    }

    header(transactions, [
      'No',
      'Merchant',
      'Kategori',
      'Nominal (Rp)',
      'Tanggal & Waktu',
      'Sumber',
    ]);
    header(categories, ['Kategori', 'Jumlah Transaksi', 'Total (Rp)']);
    header(months, ['Bulan', 'Jumlah Transaksi', 'Total (Rp)']);
    final categoryTotals = <String, double>{};
    final categoryCounts = <String, int>{};
    final monthTotals = <String, double>{};
    final monthCounts = <String, int>{};
    for (var i = 0; i < history.length; i++) {
      final tx = history[i];
      transactions.appendRow([
        IntCellValue(i + 1),
        TextCellValue(tx.merchant),
        TextCellValue(tx.category),
        DoubleCellValue(tx.numericNominal),
        DateTimeCellValue(
          year: tx.dateTime.year,
          month: tx.dateTime.month,
          day: tx.dateTime.day,
          hour: tx.dateTime.hour,
          minute: tx.dateTime.minute,
          second: tx.dateTime.second,
        ),
        TextCellValue(tx.source),
      ]);
      transactions
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1))
          .cellStyle = CellStyle(
        numberFormat: CustomDateTimeNumFormat(formatCode: 'dd/mm/yyyy hh:mm'),
      );
      categoryTotals.update(
        tx.category,
        (value) => value + tx.numericNominal,
        ifAbsent: () => tx.numericNominal,
      );
      categoryCounts.update(
        tx.category,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      final month =
          '${tx.dateTime.year}-${tx.dateTime.month.toString().padLeft(2, '0')}';
      monthTotals.update(
        month,
        (value) => value + tx.numericNominal,
        ifAbsent: () => tx.numericNominal,
      );
      monthCounts.update(month, (value) => value + 1, ifAbsent: () => 1);
    }
    for (final category in categoryTotals.keys.toList()..sort()) {
      categories.appendRow([
        TextCellValue(category),
        IntCellValue(categoryCounts[category]!),
        DoubleCellValue(categoryTotals[category]!),
      ]);
    }
    for (final month in monthTotals.keys.toList()..sort()) {
      months.appendRow([
        TextCellValue(month),
        IntCellValue(monthCounts[month]!),
        DoubleCellValue(monthTotals[month]!),
      ]);
    }
    workbook.setDefaultSheet('Transaksi');
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('Gagal membuat laporan Excel.');
    return Uint8List.fromList(bytes);
  }

  static Future<void> exportTransactionsToExcel(
    List<TransactionModel> history,
  ) async {
    if (history.isEmpty) return;
    final bytes = buildWorkbook(history);
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/laporan_jajanku_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    await File(path).writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([
      XFile(
        path,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    ], text: 'Laporan pengeluaran Jajanku');
  }
}
