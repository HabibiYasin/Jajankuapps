import 'package:excel/excel.dart';

import '../models/transaction_model.dart';
import 'transaction_classifier.dart';

class SheetValidationException implements Exception {
  final List<String> errors;
  SheetValidationException(this.errors);

  @override
  String toString() => errors.join('\n');
}

class TransactionSheetService {
  static const headers = [
    'No',
    'Merchant',
    'Kategori',
    'Nominal (Rp)',
    'Tanggal & Waktu',
    'Sumber Uang',
    'Metode Pembayaran',
    'Jenis Transaksi',
  ];
  static const types = ['Pemasukan', 'Pengeluaran'];
  static const categories = [
    ...TransactionClassifier.categories,
    ...TransactionModel.incomeCategories,
  ];

  static List<TransactionModel> parse(List<int> bytes) {
    final Excel workbook;
    try {
      workbook = Excel.decodeBytes(bytes);
    } catch (_) {
      throw SheetValidationException([
        'File tidak dapat dibaca. Gunakan file .xlsx dari Excel atau unduhan Google Sheets.',
      ]);
    }
    final sheet = workbook.tables['Transaksi'];
    if (sheet == null || sheet.rows.isEmpty) {
      throw SheetValidationException([
        'Sheet "Transaksi" tidak ditemukan atau kosong.',
      ]);
    }
    final rows = sheet.rows;
    String text(CellValue? value) => value?.toString().trim() ?? '';
    CellValue? cell(List<Data?> row, int column) =>
        column < row.length ? row[column]?.value : null;
    final columns = <int>[];
    for (final name in headers) {
      final matches = [
        for (var i = 0; i < rows.first.length; i++)
          if (text(cell(rows.first, i)) == name) i,
      ];
      if (matches.length != 1) {
        throw SheetValidationException([
          'Kolom "$name" harus ada tepat satu kali pada baris pertama. Gunakan template ekspor.',
        ]);
      }
      columns.add(matches.single);
    }
    final errors = <String>[];
    final result = <TransactionModel>[];
    final numbers = <int>{};
    for (var index = 1; index < rows.length; index++) {
      final row = rows[index];
      if (row.every((c) => text(c?.value).isEmpty)) continue;
      final values = columns.map((c) => cell(row, c)).toList();
      final fields = values.map(text).toList();
      final before = errors.length;
      void error(int column, String message) =>
          errors.add('Baris ${index + 1}, ${headers[column]}: $message');
      for (var i = 0; i < headers.length; i++) {
        if (fields[i].isEmpty) error(i, 'wajib diisi.');
        if (values[i] is FormulaCellValue) {
          error(i, 'gunakan nilai langsung, bukan rumus.');
        }
      }
      if (errors.length != before) continue;
      final number = num.tryParse(fields[0]);
      if (number == null ||
          !number.isFinite ||
          number <= 0 ||
          number % 1 != 0) {
        error(0, 'isi nomor bulat positif.');
      } else if (!numbers.add(number.toInt())) {
        error(0, 'nomor tidak boleh berulang.');
      }
      if (fields[1].length > 2000) error(1, 'maksimal 2000 karakter.');
      if (fields[5].length > 200) error(5, 'maksimal 200 karakter.');
      final amount = switch (values[3]) {
        IntCellValue(:final value) => value.toDouble(),
        DoubleCellValue(:final value) => value,
        TextCellValue()
            when RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(fields[3]) =>
          double.tryParse(fields[3].replaceAll(',', '.')),
        _ => null,
      };
      if (amount == null || !amount.isFinite || amount <= 0 || amount > 1e15) {
        error(
          3,
          'isi angka lebih dari 0, maksimal 1000000000000000, tanpa Rp/pemisah ribuan.',
        );
      }
      final date = _date(values[4]);
      if (date == null) {
        error(
          4,
          'tanggal tidak valid. Gunakan dd/mm/yyyy atau dd/mm/yyyy HH:mm (24 jam).',
        );
      }
      if (!TransactionModel.paymentMethods.contains(fields[6])) {
        error(6, 'pilih ${TransactionModel.paymentMethods.join(', ')}.');
      }
      if (!types.contains(fields[7])) {
        error(7, 'pilih Pemasukan atau Pengeluaran.');
      } else {
        final allowed = fields[7] == 'Pemasukan'
            ? TransactionModel.incomeCategories
            : TransactionClassifier.categories;
        if (!allowed.contains(fields[2])) {
          error(2, 'untuk ${fields[7]}, pilih ${allowed.join(', ')}.');
        }
      }
      if (errors.length == before) {
        result.add(
          TransactionModel(
            type: fields[7] == 'Pemasukan' ? 'income' : 'expense',
            merchant: fields[1],
            category: fields[2],
            numericNominal: amount!,
            nominalStr: 'Rp${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}',
            dateTime: date!,
            source: fields[5],
            paymentMethod: fields[6],
          ),
        );
      }
    }
    if (errors.isNotEmpty) throw SheetValidationException(errors);
    if (result.isEmpty) {
      throw SheetValidationException([
        'Isi minimal satu transaksi. File kosong tidak akan menghapus riwayat.',
      ]);
    }
    return result;
  }

  static DateTime? _date(CellValue? value) {
    DateTime? checked(
      int year,
      int month,
      int day,
      int hour,
      int minute,
      int second,
    ) {
      if (year < 1900 || year > 9999) return null;
      final date = DateTime(year, month, day, hour, minute, second);
      return date.year == year &&
              date.month == month &&
              date.day == day &&
              date.hour == hour &&
              date.minute == minute &&
              date.second == second
          ? date
          : null;
    }

    if (value is DateTimeCellValue) {
      return checked(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        value.second,
      );
    }
    if (value is DateCellValue) {
      return checked(value.year, value.month, value.day, 0, 0, 0);
    }
    if (value is! TextCellValue) return null;
    final input = value.toString().trim();
    final local = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:[ ,T]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(input);
    final iso = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(input);
    final match = local ?? iso;
    if (match == null) return null;
    int part(int i) => int.parse(match.group(i) ?? '0');
    return checked(
      part(local != null ? 3 : 1),
      part(2),
      part(local != null ? 1 : 3),
      part(4),
      part(5),
      part(6),
    );
  }
}
