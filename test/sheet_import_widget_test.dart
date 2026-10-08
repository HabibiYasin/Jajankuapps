import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/screens/transaction_history_screen.dart';
import 'package:flutter_application_1/services/export_service.dart';

class SheetPicker extends FilePicker {
  final Uint8List? bytes;
  SheetPicker(this.bytes);

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    expect(allowedExtensions, ['xlsx']);
    expect(withData, true);
    return bytes == null
        ? null
        : FilePickerResult([
            PlatformFile(
              name: 'transaksi.xlsx',
              size: bytes!.length,
              bytes: bytes,
            ),
          ]);
  }
}

void main() {
  Future<void> openImport(WidgetTester tester) async {
    await tester.tap(find.text('Ekspor/Impor Data Excel/Sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Impor Excel/Sheet (.xlsx)'));
    // compute() parses on a real isolate; allow it to finish outside fake time.
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.byType(AlertDialog).evaluate().isNotEmpty) break;
      }
    });
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> mount(
    WidgetTester tester,
    Future<void> Function(List<TransactionModel>, String) onImport,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionHistoryScreen(
            history: const [],
            importRevision: 'original-revision',
            onDelete: (_) {},
            onUpdateDate: (_, _) {},
            onUpdateTransaction: (_) {},
            onImportTransactions: onImport,
          ),
        ),
      ),
    );
  }

  testWidgets('empty history exposes template export and import', (
    tester,
  ) async {
    await mount(tester, (_, _) async {});
    await tester.tap(find.text('Ekspor/Impor Data Excel/Sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Ekspor template kosong'), findsOneWidget);
    expect(find.text('Impor Excel/Sheet (.xlsx)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid file requires confirmation before replacing history', (
    tester,
  ) async {
    final row = TransactionModel(
      merchant: 'Warung',
      nominalStr: 'Rp1000',
      numericNominal: 1000,
      dateTime: DateTime(2026, 10, 8),
      category: 'Makanan',
    );
    FilePicker.platform = SheetPicker(ExportService.buildWorkbook([row]));
    var calls = 0;
    await mount(tester, (rows, revision) async {
      calls++;
      expect(rows.single.merchant, 'Warung');
      expect(revision, 'original-revision');
    });
    await openImport(tester);
    expect(find.text('Verifikasi impor'), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await openImport(tester);
    await tester.tap(find.text('Ganti seluruh transaksi'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('1 transaksi berhasil diimpor.'), findsOneWidget);
  });

  testWidgets('invalid file displays validation errors without writing', (
    tester,
  ) async {
    FilePicker.platform = SheetPicker(ExportService.buildWorkbook([]));
    var calls = 0;
    await mount(tester, (_, _) async {
      calls++;
    });
    await openImport(tester);
    expect(find.text('Perbaiki isi sheet'), findsOneWidget);
    expect(find.textContaining('Isi minimal satu transaksi'), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('Ekspor/Impor Data Excel/Sheet'), findsOneWidget);
  });
}
