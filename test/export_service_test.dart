import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/services/export_service.dart';

void main() {
  test(
    'Excel preserves separate cells, numeric amounts and summary sheets',
    () {
      TransactionModel transaction(
        String merchant,
        String category,
        double amount,
        DateTime date,
      ) => TransactionModel(
        merchant: merchant,
        nominalStr: 'Rp $amount',
        dateTime: date,
        category: category,
        numericNominal: amount,
        source: 'DANA',
      );
      final workbook = Excel.decodeBytes(
        ExportService.buildWorkbook([
          transaction(
            'Warung; "Enak",\nJakarta',
            'Makanan',
            12500.5,
            DateTime(2026, 9, 30, 18, 45),
          ),
          transaction('=SUM(A1:A2)', 'Makanan', 7500, DateTime(2026, 10, 1)),
          transaction('Bus', 'Transport', 5000, DateTime(2026, 10, 2)),
        ]),
      );
      expect(workbook.tables.keys, ['Transaksi', 'Kategori', 'Bulanan']);
      final rows = workbook['Transaksi'].rows;
      expect(rows.length, 4);
      expect(rows[1].length, 6);
      expect(rows[1][1]!.value, TextCellValue('Warung; "Enak",\nJakarta'));
      expect(rows[1][3]!.value, DoubleCellValue(12500.5));
      expect(rows[2][1]!.value, TextCellValue('=SUM(A1:A2)'));
      expect(rows[1][4]!.value, isA<DateTimeCellValue>());
      final categories = workbook['Kategori'].rows;
      expect(categories[1][0]!.value, TextCellValue('Makanan'));
      expect(categories[1][1]!.value, IntCellValue(2));
      expect(categories[1][2]!.value, DoubleCellValue(20000.5));
      final months = workbook['Bulanan'].rows;
      expect(months[1][0]!.value, TextCellValue('2026-09'));
      expect(months[2][1]!.value, IntCellValue(2));
      expect(months[2][2]!.value, IntCellValue(12500));
    },
  );
}

