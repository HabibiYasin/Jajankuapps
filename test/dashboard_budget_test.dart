import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/models/budget_limits.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/screens/dashboard_screen.dart';

void main() {
  testWidgets(
    'dashboard separates other spending from selected budget categories',
    (tester) async {
      final today = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'tutorial_hidden_date': today.toIso8601String(),
      });
      TransactionModel tx(String category, double amount) => TransactionModel(
        merchant: 'Toko',
        nominalStr: '$amount',
        dateTime: today,
        category: category,
        numericNominal: amount,
      );
      final history = [tx('Jajan', 25000), tx('Tagihan & Pulsa', 100000)];
      Widget dashboard(List<String> categories) => MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            history: history,
            dailyLimit: 50000,
            monthlyLimit: 1500000,
            budgetCategories: categories,
          ),
        ),
      );
      await tester.pumpWidget(dashboard(BudgetLimits.snackCategories));
      await tester.pumpAndSettle();
      expect(find.text('Rp25K'), findsNWidgets(2));
      expect(find.text('Budget lainnya hari ini: Rp100K'), findsOneWidget);
      expect(find.text('Budget lainnya bulan ini: Rp100K'), findsOneWidget);
      await tester.pumpWidget(dashboard(['Jajan', 'Tagihan & Pulsa']));
      await tester.pumpAndSettle();
      expect(find.text('Rp125K'), findsNWidgets(2));
      expect(find.text('Budget lainnya hari ini: Rp0'), findsOneWidget);
      expect(history, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
