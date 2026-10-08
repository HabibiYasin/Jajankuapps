import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/services/export_service.dart';
import 'package:flutter_application_1/services/transaction_sheet_service.dart';

List<CellValue?> validRow() => [
  IntCellValue(1),
  TextCellValue('Warung'),
  TextCellValue('Makanan'),
  DoubleCellValue(12500.50),
  TextCellValue('08/10/2026'),
  TextCellValue('DANA'),
  TextCellValue('QRIS'),
  TextCellValue('Pengeluaran'),
];

List<int> sheetBytes(List<List<CellValue?>> rows, {List<String>? headers}) {
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', 'Transaksi');
  workbook['Transaksi'].appendRow(
    (headers ?? TransactionSheetService.headers)
        .map(TextCellValue.new)
        .toList(),
  );
  for (final row in rows) {
    workbook['Transaksi'].appendRow(row);
  }
  return workbook.encode()!;
}

void main() {
  test('export includes strict dropdowns on existing and future rows', () {
    final archive = ZipDecoder().decodeBytes(ExportService.buildWorkbook([]));
    final validationSheets = archive.files
        .where(
          (f) => f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml'),
        )
        .map((f) => XmlDocument.parse(utf8.decode(f.content as List<int>)))
        .where((d) => d.findAllElements('dataValidation').isNotEmpty);
    expect(validationSheets, hasLength(1));
    final validations = validationSheets.single
        .findAllElements('dataValidation')
        .toList();
    expect(validations.map((v) => v.getAttribute('sqref')), [
      'C2:C1048576',
      'G2:G1048576',
      'H2:H1048576',
    ]);
    for (final validation in validations) {
      expect(validation.getAttribute('showDropDown'), '0');
      expect(validation.getAttribute('showErrorMessage'), '1');
      expect(validation.getAttribute('allowBlank'), '0');
    }
    expect(validations[0].innerText, contains('Tagihan & Pulsa'));
    expect(validations[0].innerText, contains('Gaji'));
    expect(validations[1].innerText, contains('PayLater'));
    expect(validations[2].innerText, '"Pemasukan,Pengeluaran"');
  });

  test(
    'export/import preserves all editable values for both transaction types',
    () {
      final source = [
        TransactionModel(
          merchant: '=SUM(A1:A2)',
          nominalStr: 'Rp12.5',
          dateTime: DateTime(2026, 10, 8, 13, 24, 45),
          category: 'Makanan',
          numericNominal: 12.5,
          source: 'DANA',
          paymentMethod: 'PayLater',
        ),
        TransactionModel(
          type: 'income',
          merchant: 'Kantor',
          nominalStr: 'Rp5000',
          dateTime: DateTime(2026, 9, 1),
          category: 'Gaji',
          numericNominal: 5000,
          source: 'BCA',
          paymentMethod: 'Transfer',
        ),
      ];
      final imported = TransactionSheetService.parse(
        ExportService.buildWorkbook(source),
      );
      for (var i = 0; i < source.length; i++) {
        expect(imported[i].merchant, source[i].merchant);
        expect(imported[i].numericNominal, source[i].numericNominal);
        expect(imported[i].dateTime, source[i].dateTime);
        expect(imported[i].category, source[i].category);
        expect(imported[i].source, source[i].source);
        expect(imported[i].paymentMethod, source[i].paymentMethod);
        expect(imported[i].type, source[i].type);
      }
    },
  );

  for (final date in [
    TextCellValue('08/10/2026'),
    TextCellValue('2026-10-08'),
    DateCellValue(year: 2026, month: 10, day: 8),
  ]) {
    test('missing time defaults to midnight for $date', () {
      final row = validRow()..[4] = date;
      expect(
        TransactionSheetService.parse(sheetBytes([row])).single.dateTime,
        DateTime(2026, 10, 8),
      );
    });
  }
  test('text time and fractional amounts are preserved', () {
    final row = validRow()
      ..[4] = TextCellValue('08/10/2026 23:59')
      ..[3] = TextCellValue('12500,50');
    final imported = TransactionSheetService.parse(sheetBytes([row])).single;
    expect(imported.dateTime, DateTime(2026, 10, 8, 23, 59));
    expect(imported.numericNominal, 12500.5);
  });
  for (var column = 0; column < 8; column++) {
    test('missing required column value $column rejects entire file', () {
      final row = validRow()..[column] = null;
      expect(
        () => TransactionSheetService.parse(sheetBytes([validRow(), row])),
        throwsA(
          isA<SheetValidationException>().having(
            (e) => e.errors.join(),
            'error',
            contains('Baris 3, ${TransactionSheetService.headers[column]}'),
          ),
        ),
      );
    });
  }
  for (final date in [
    '31/02/2026',
    '08/10/2026 24:00',
    '08/10/2026 12:60',
    '00/10/2026',
    '12:00',
    'hello',
  ]) {
    test('rejects invalid date $date', () {
      final row = validRow()..[4] = TextCellValue(date);
      expect(
        () => TransactionSheetService.parse(sheetBytes([row])),
        throwsA(isA<SheetValidationException>()),
      );
    });
  }
  test('reports all invalid fields and rows before any import', () {
    final row = validRow()
      ..[2] = TextCellValue('Gaji')
      ..[3] = IntCellValue(-10)
      ..[6] = TextCellValue('Unknown');
    final second = validRow()..[7] = TextCellValue('Other');
    expect(
      () => TransactionSheetService.parse(sheetBytes([row, second])),
      throwsA(
        isA<SheetValidationException>().having(
          (e) => e.errors.length,
          'five errors including duplicate No',
          5,
        ),
      ),
    );
  });
  test('formulas are rejected even when a cached value might exist', () {
    final row = validRow()..[3] = FormulaCellValue('100+200');
    expect(
      () => TransactionSheetService.parse(sheetBytes([row])),
      throwsA(isA<SheetValidationException>()),
    );
  });
  test(
    'blank rows ignored, empty/malformed files and missing headers rejected',
    () {
      expect(
        TransactionSheetService.parse(sheetBytes([[], validRow(), []])),
        hasLength(1),
      );
      for (final bytes in [
        sheetBytes([]),
        [1, 2, 3],
        sheetBytes([validRow()], headers: ['Wrong']),
      ]) {
        expect(
          () => TransactionSheetService.parse(bytes),
          throwsA(isA<SheetValidationException>()),
        );
      }
    },
  );
  test('headers can be reordered without corrupting fields', () {
    final imported = TransactionSheetService.parse(
      sheetBytes([
        validRow().reversed.toList(),
      ], headers: TransactionSheetService.headers.reversed.toList()),
    );
    expect(imported.single.merchant, 'Warung');
    expect(imported.single.numericNominal, 12500.5);
  });
}
