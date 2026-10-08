import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction_model.dart';
import 'transaction_sheet_service.dart';

class ExportService {
  static Uint8List buildWorkbook(List<TransactionModel> history) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Transaksi');
    final transactions = workbook['Transaksi'];
    final categories = workbook['Kategori'];
    final months = workbook['Bulanan'];
    final methods = workbook['Metode Pembayaran'];

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

    header(transactions, TransactionSheetService.headers);
    header(categories, ['Kategori', 'Jumlah Transaksi', 'Total (Rp)']);
    header(months, [
      'Bulan',
      'Jumlah Pengeluaran',
      'Pengeluaran (Rp)',
      'Pemasukan (Rp)',
      'Selisih Tercatat (Rp)',
    ]);
    final incomeTotals = <String, double>{};
    header(methods, ['Metode Pembayaran', 'Jumlah Transaksi', 'Total (Rp)']);
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
        TextCellValue(tx.paymentMethod),
        TextCellValue(tx.isIncome ? 'Pemasukan' : 'Pengeluaran'),
      ]);
      transactions
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1))
          .cellStyle = CellStyle(
        numberFormat: CustomDateTimeNumFormat(formatCode: 'dd/mm/yyyy hh:mm'),
      );
      if (tx.isIncome) {
        final month =
            '${tx.dateTime.year}-${tx.dateTime.month.toString().padLeft(2, '0')}';
        incomeTotals.update(
          month,
          (value) => value + tx.numericNominal,
          ifAbsent: () => tx.numericNominal,
        );
        continue;
      }
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
    for (final month in {
      ...monthTotals.keys,
      ...incomeTotals.keys,
    }.toList()..sort()) {
      months.appendRow([
        TextCellValue(month),
        IntCellValue(monthCounts[month] ?? 0),
        DoubleCellValue(monthTotals[month] ?? 0),
        DoubleCellValue(incomeTotals[month] ?? 0),
        DoubleCellValue((incomeTotals[month] ?? 0) - (monthTotals[month] ?? 0)),
      ]);
    }
    workbook.setDefaultSheet('Transaksi');
    for (final method in TransactionModel.paymentMethods) {
      final rows = history
          .where((tx) => !tx.isIncome && tx.paymentMethod == method)
          .toList();
      methods.appendRow([
        TextCellValue(method),
        IntCellValue(rows.length),
        DoubleCellValue(
          rows.fold<double>(0, (total, tx) => total + tx.numericNominal),
        ),
      ]);
    }
    final instructions = workbook['Petunjuk'];
    header(instructions, ['Panduan ekspor/impor']);
    instructions.setColumnWidth(0, 110);
    for (final line in [
      'Edit sheet Transaksi. Impor mengganti SELURUH pemasukan dan pengeluaran dengan isi sheet ini.',
      'Tambahkan baris untuk transaksi baru. Baris yang dihapus tidak akan ada lagi setelah impor.',
      'Semua 8 kolom wajib diisi. No harus angka bulat positif dan unik (bukan ID transaksi).',
      'Tanggal: dd/mm/yyyy atau dd/mm/yyyy HH:mm (24 jam). Tanpa waktu otomatis 00:00.',
      'Nominal: angka lebih dari 0, tanpa Rp/pemisah ribuan. Gunakan sel angka untuk nominal desimal.',
      'Pilih Kategori, Metode Pembayaran, dan Jenis Transaksi melalui dropdown.',
      'Kategori pengeluaran: ${TransactionSheetService.categories.where((c) => !TransactionModel.incomeCategories.contains(c)).join(', ')}.',
      'Kategori pemasukan: ${TransactionModel.incomeCategories.join(', ')}.',
      'Jangan gunakan rumus. Baris yang seluruhnya kosong diabaikan.',
      'Google Sheets: setelah mengedit, pilih File > Download > Microsoft Excel (.xlsx), lalu impor file tersebut.',
      'Sheet ringkasan tidak diimpor; ekspor ulang setelah impor untuk memperbarui ringkasan.',
    ]) {
      instructions.appendRow([TextCellValue(line)]);
    }
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('Gagal membuat laporan Excel.');
    return _addDropdowns(bytes);
  }

  // excel 4.x does not expose data validation. Add standard OOXML list
  // validations after encoding, including unused rows for new transactions.
  static Uint8List _addDropdowns(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    XmlDocument document(String path) => XmlDocument.parse(
      utf8.decode(archive.findFile(path)!.content as List<int>),
    );
    final workbook = document('xl/workbook.xml');
    final sheet = workbook
        .findAllElements('sheet')
        .firstWhere((element) => element.getAttribute('name') == 'Transaksi');
    final relation = document('xl/_rels/workbook.xml.rels')
        .findAllElements('Relationship')
        .firstWhere(
          (element) => element.getAttribute('Id') == sheet.getAttribute('r:id'),
        );
    final target = relation.getAttribute('Target')!;
    final path = target.startsWith('/') ? target.substring(1) : 'xl/$target';
    final worksheet = document(path);
    final builder = XmlBuilder();
    builder.element(
      'dataValidations',
      attributes: {'count': '3'},
      nest: () {
        for (final entry in {
          'C': TransactionSheetService.categories,
          'G': TransactionModel.paymentMethods,
          'H': TransactionSheetService.types,
        }.entries) {
          builder.element(
            'dataValidation',
            attributes: {
              'type': 'list',
              'allowBlank': '0',
              'showDropDown': '0',
              'showErrorMessage': '1',
              'errorStyle': 'stop',
              'errorTitle': 'Pilihan tidak valid',
              'error': 'Pilih nilai dari dropdown.',
              'sqref': '${entry.key}2:${entry.key}1048576',
            },
            nest: () {
              builder.element('formula1', nest: '"${entry.value.join(',')}"');
            },
          );
        }
      },
    );
    final data = worksheet.rootElement.findElements('sheetData').single;
    worksheet.rootElement.children.insert(
      worksheet.rootElement.children.indexOf(data) + 1,
      builder.buildDocument().rootElement.copy(),
    );
    final content = utf8.encode(worksheet.toXmlString());
    archive.addFile(ArchiveFile(path, content.length, content));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static Future<void> exportTransactionsToExcel(
    List<TransactionModel> history,
  ) async {
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
    ], text: 'Data transaksi Jajanku');
  }
}
