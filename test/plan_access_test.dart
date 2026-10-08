import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/models/plan_access.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/screens/dashboard_screen.dart';
import 'package:flutter_application_1/screens/income_screen.dart';
import 'package:flutter_application_1/screens/personalization_screen.dart';
import 'package:flutter_application_1/screens/transaction_history_screen.dart';

void main() {
  test('Calendar access crosses years and includes whole boundary months', () {
    final now = DateTime(2026, 1, 15);
    const free = PlanAccess();
    const premium = PlanAccess(isPremium: true);
    expect(free.months(now), [DateTime(2026, 1), DateTime(2025, 12)]);
    expect(premium.months(now), hasLength(12));
    expect(premium.months(now).last, DateTime(2025, 2));
    expect(free.includes(DateTime(2025, 12), now), isTrue);
    expect(free.includes(DateTime(2025, 11, 30, 23, 59), now), isFalse);
    expect(premium.includes(DateTime(2025, 2), now), isTrue);
    expect(premium.includes(DateTime(2025, 1, 31, 23, 59), now), isFalse);
    expect(premium.includes(DateTime(2026, 2), now), isFalse);
    expect(free.includes(DateTime(2026, 1, 31), now), isTrue);
    expect(UserTier.premium.label, 'Jajaners Sultan');
    expect(UserTier.free.label, 'Jajaners Gratisan');
  });

  for (final income in [false, true]) {
    testWidgets(
      '${income ? 'Income' : 'Expense'} history follows plan without deleting older rows',
      (tester) async {
        final now = DateTime.now();
        final history = [
          for (final offset in [0, 1, 2, 11, 12])
            TransactionModel(
              merchant: 'Month $offset',
              type: income ? 'income' : 'expense',
              category: income ? 'Gaji' : 'Makanan',
              dateTime: DateTime(now.year, now.month - offset, 1),
              nominalStr: 'Rp 100',
              numericNominal: 100,
            ),
        ];
        Widget app(bool premium) => MaterialApp(
          home: Scaffold(
            body: income
                ? IncomeScreen(
                    isPremium: premium,
                    history: history,
                    onAddIncome: () async {},
                    onDelete: (_) {},
                    onUpdateDate: (_, _) {},
                    onUpdateTransaction: (_) {},
                  )
                : TransactionHistoryScreen(
                    isPremium: premium,
                    history: history,
                    onDelete: (_) {},
                    onUpdateDate: (_, _) {},
                    onUpdateTransaction: (_) {},
                  ),
          ),
        );
        await tester.pumpWidget(app(false));
        expect(find.text('Month 0'), findsOneWidget);
        expect(find.text('Month 1'), findsOneWidget);
        expect(find.text('Month 2'), findsNothing);
        expect(find.text('Month 11'), findsNothing);
        var dropdown = tester.widget<DropdownButton<int>>(
          find.byType(DropdownButton<int>),
        );
        expect(dropdown.items, hasLength(3));

        await tester.pumpWidget(app(true));
        await tester.pumpAndSettle();
        expect(find.text('Month 2'), findsOneWidget);
        expect(find.text('Month 11'), findsOneWidget);
        expect(find.text('Month 12'), findsNothing);
        dropdown = tester.widget<DropdownButton<int>>(
          find.byType(DropdownButton<int>),
        );
        expect(dropdown.items, hasLength(13));
        dropdown.onChanged!(11);
        await tester.pumpAndSettle();
        expect(find.text('Month 11'), findsOneWidget);
        expect(find.text('Month 0'), findsNothing);

        await tester.pumpWidget(app(false));
        await tester.pumpAndSettle();
        expect(find.text('Month 11'), findsNothing);
        expect(find.text('Month 0'), findsOneWidget);
        expect(history, hasLength(5));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Report offers 12 or 2 months even without transactions and responds to downgrade',
    (tester) async {
      final premium = ValueNotifier(true);
      addTearDown(premium.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: premium,
              builder: (_, value, _) => TransactionHistoryScreen(
                isPremium: value,
                history: const [],
                onDelete: (_) {},
                onUpdateDate: (_, _) {},
                onUpdateTransaction: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Download Laporan Bulanan PDF'));
      await tester.pumpAndSettle();
      var dropdown = tester.widget<DropdownButton<DateTime>>(
        find.byType(DropdownButton<DateTime>),
      );
      expect(dropdown.items, hasLength(12));
      dropdown.onChanged!(dropdown.items!.last.value);
      await tester.pumpAndSettle();
      premium.value = false;
      await tester.pumpAndSettle();
      dropdown = tester.widget<DropdownButton<DateTime>>(
        find.byType(DropdownButton<DateTime>),
      );
      final now = DateTime.now();
      expect(dropdown.items!.map((item) => item.value), [
        DateTime(now.year, now.month),
        DateTime(now.year, now.month - 1),
      ]);
      expect(dropdown.value, DateTime(now.year, now.month));
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Seven-day chart is blurred for free and clear for premium', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'tutorial_hidden_date': DateTime.now().toIso8601String(),
    });
    Widget app(bool premium) => MaterialApp(
      home: Scaffold(
        body: DashboardScreen(
          isPremium: premium,
          history: const [],
          dailyLimit: 50000,
          monthlyLimit: 1500000,
        ),
      ),
    );
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    expect(find.text('only for premium'), findsOneWidget);
    expect(
      tester.widget<ImageFiltered>(find.byType(ImageFiltered)).enabled,
      isTrue,
    );
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(find.text('only for premium'), findsNothing);
    expect(
      tester.widget<ImageFiltered>(find.byType(ImageFiltered)).enabled,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
