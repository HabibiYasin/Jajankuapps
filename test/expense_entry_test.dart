import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/screens/manual_expense_screen.dart';
import 'package:flutter_application_1/screens/scanner_screen.dart';

void main() {
  testWidgets('Expense options call their respective actions', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScannerScreen(
            onManualEntry: () async {
              calls.add('manual');
            },
            onProcessImage: () async {
              calls.add('gallery');
            },
            onTakePhoto: () async {
              calls.add('camera');
            },
            imageFile: null,
            rawTextDebug: '',
          ),
        ),
      ),
    );
    for (final label in [
      '1. Catat Manual',
      '2. Unggah Screenshot dari Galeri',
      '3. Foto Struk',
    ]) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(calls, ['manual', 'gallery', 'camera']);
  });

  testWidgets('Manual entry validates and returns a transaction', (
    tester,
  ) async {
    TransactionModel? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await Navigator.of(context).push<TransactionModel>(
                    MaterialPageRoute(
                      builder: (_) => const ManualExpenseScreen(),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan Pengeluaran'));
    await tester.tap(find.text('Simpan Pengeluaran'));
    await tester.pumpAndSettle();
    expect(find.text('Isi nama pengeluaran.'), findsOneWidget);
    expect(find.text('Isi nominal lebih dari 0.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Makan siang');
    await tester.enterText(find.byType(TextFormField).at(1), '25000');
    await tester.ensureVisible(find.text('Simpan Pengeluaran'));
    await tester.tap(find.text('Simpan Pengeluaran'));
    await tester.pumpAndSettle();
    expect(saved?.merchant, 'Makan siang');
    expect(saved?.numericNominal, 25000);
    expect(saved?.source, 'Tunai');
    expect(saved?.paymentMethod, 'Cash');
  });
}
