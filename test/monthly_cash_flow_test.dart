import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/screens/dashboard_screen.dart';
import 'package:flutter_application_1/services/monthly_report_service.dart';
import 'package:flutter_application_1/screens/spending_progress_screen.dart';

void main() {
  for (final offset in [0, 1]) {
    testWidgets(
      'Monthly card opens both periods and shares period $offset with correct budget spending',
      (tester) async {
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'tutorial_hidden_date': now.toIso8601String(),
        });
        TransactionModel row(
          int monthOffset,
          String type,
          String category,
          double amount,
        ) => TransactionModel(
          merchant: 'Toko',
          nominalStr: '$amount',
          dateTime: DateTime(now.year, now.month - monthOffset, 1),
          category: category,
          numericNominal: amount,
          type: type,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DashboardScreen(
                history: [
                  row(0, 'income', 'Gaji', 3000000),
                  row(0, 'expense', 'Makanan', 50000),
                  row(0, 'expense', 'Tagihan & Pulsa', 100000),
                  row(1, 'expense', 'Makanan', 25000),
                ],
                dailyLimit: 50000,
                monthlyLimit: 1500000,
                budgetCategories: const ['Makanan'],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            MonthlyReportService.monthLabel(DateTime(now.year, now.month - 1)),
          ),
          findsNothing,
        );
        expect(find.textContaining('Selisih tercatat:'), findsNothing);
        await tester.tap(
          find.text('Arus uang ${MonthlyReportService.months[now.month - 1]}'),
        );
        await tester.pumpAndSettle();
        final current = find.text(MonthlyReportService.monthLabel(now));
        final previous = find.text(
          MonthlyReportService.monthLabel(DateTime(now.year, now.month - 1)),
        );
        expect(current, findsOneWidget);
        expect(previous, findsOneWidget);
        final target = offset == 0 ? current : previous;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final screen = tester.widget<SpendingProgressScreen>(
          find.byType(SpendingProgressScreen),
        );
        expect(screen.progress.monthly, true);
        expect(screen.progress.spent, offset == 0 ? 50000 : 25000);
        expect(
          screen.progress.date.month,
          DateTime(now.year, now.month - offset).month,
        );
        expect(screen.progress.budget, 1500000);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
