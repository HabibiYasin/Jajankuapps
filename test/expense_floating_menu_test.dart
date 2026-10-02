import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/expense_floating_menu.dart';

void main() {
  testWidgets('Floating menu opens, runs each action, and closes', (
    tester,
  ) async {
    final actions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: ExpenseFloatingMenu(
            onManualEntry: () async => actions.add('manual'),
            onGallery: () async => actions.add('gallery'),
            onCamera: () async => actions.add('camera'),
          ),
        ),
      ),
    );

    for (final entry in {
      'Catat Manual': 'manual',
      'Unggah dari Galeri': 'gallery',
      'Foto Struk': 'camera',
    }.entries) {
      expect(find.byTooltip(entry.key).hitTestable(), findsNothing);
      await tester.tap(find.byTooltip('Catat Pengeluaran'));
      await tester.pumpAndSettle();
      expect(find.byTooltip(entry.key).hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip(entry.key));
      await tester.pumpAndSettle();
      expect(actions.last, entry.value);
      expect(find.byTooltip(entry.key).hitTestable(), findsNothing);
    }
    expect(actions, ['manual', 'gallery', 'camera']);
  });
}
