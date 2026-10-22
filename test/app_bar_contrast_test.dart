import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/manual_expense_screen.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Page title and back icon remain legible in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        final theme = dark ? AppTheme.dark : AppTheme.light;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ManualExpenseScreen(isIncome: true),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final title = DefaultTextStyle.of(
          tester.element(find.text('Catat Pemasukan')),
        ).style.color!;
        final back = IconTheme.of(tester.element(find.byType(BackButton)))
            .color!;
        double contrast(Color foreground) {
          final a = foreground.computeLuminance();
          final b = theme.scaffoldBackgroundColor.computeLuminance();
          return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        }

        expect(contrast(title), greaterThanOrEqualTo(4.5));
        expect(contrast(back), greaterThanOrEqualTo(4.5));
        expect(
          theme.appBarTheme.systemOverlayStyle!.statusBarIconBrightness,
          dark ? Brightness.light : Brightness.dark,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Open'), findsOneWidget);
      },
    );
  }
}
