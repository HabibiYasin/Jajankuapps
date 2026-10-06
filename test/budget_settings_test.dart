import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/budget_limits.dart';
import 'package:flutter_application_1/screens/budget_settings_screen.dart';
import 'package:flutter_application_1/services/account_data_service.dart';
import 'package:flutter_application_1/services/transaction_classifier.dart';

void main() {
  testWidgets('onboarding presets, defaults and save complete account setup', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final data = AccountDataService(
      firestore: firestore,
      currentUid: () => 'new-user',
    );
    addTearDown(data.dispose);
    await data.switchAccount('new-user');
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: data,
          builder: (context, _) => data.limits.isConfigured
              ? const Scaffold(body: Text('Dashboard siap'))
              : BudgetSettingsScreen(
                  onboarding: true,
                  dailyLimit: 50000,
                  weeklyLimit: 350000,
                  monthlyLimit: 1500000,
                  accountData: data,
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Selamat datang! Kamu mau pakai aplikasi ini untuk track apa?'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Jajan aja'));
    await tester.tap(find.text('Jajan aja'));
    await tester.pump();
    for (final category in TransactionClassifier.categories) {
      final checkbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, category),
      );
      expect(checkbox.value, BudgetLimits.snackCategories.contains(category));
    }
    await tester.tap(find.text('Semuanya'));
    await tester.pump();
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .every((tile) => tile.value == true),
      true,
    );
    await tester.tap(find.text('Jajan aja'));
    await tester.ensureVisible(find.text('Lanjut: atur budget'));
    await tester.tap(find.text('Lanjut: atur budget'));
    await tester.pumpAndSettle();
    expect(
      find.text('Berapa budget harian, mingguan, dan bulanan kamu?'),
      findsOneWidget,
    );
    final inputs = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(inputs.map((input) => input.controller!.text), [
      '50000',
      '350000',
      '1500000',
    ]);
    await tester.ensureVisible(find.text('Mulai pakai Jajanku'));
    await tester.tap(find.text('Mulai pakai Jajanku'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard siap'), findsOneWidget);
    expect(data.limits.isConfigured, true);
    expect(
      data.limits.trackedCategories.toSet(),
      BudgetLimits.snackCategories.toSet(),
    );
    final saved = await firestore.doc('users/new-user/settings/budget').get();
    expect(
      (saved.data()!['categories'] as List).toSet(),
      BudgetLimits.snackCategories.toSet(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'onboarding requires a category and preserves budget when going back',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BudgetSettingsScreen(
            onboarding: true,
            dailyLimit: 75000,
            weeklyLimit: 400000,
            monthlyLimit: 2000000,
          ),
        ),
      );
      for (final category in TransactionClassifier.categories) {
        final checkbox = find.widgetWithText(CheckboxListTile, category);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pump();
      }
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Lanjut: atur budget'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Jajan aja'));
      await tester.tap(find.text('Jajan aja'));
      await tester.pump();
      await tester.ensureVisible(find.text('Lanjut: atur budget'));
      await tester.tap(find.text('Lanjut: atur budget'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextFormField).first);
      await tester.enterText(find.byType(TextFormField).first, '85000');
      await tester.ensureVisible(find.text('Kembali ke kategori'));
      await tester.tap(find.text('Kembali ke kategori'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Tagihan & Pulsa'),
            )
            .value,
        false,
      );
      await tester.ensureVisible(find.text('Lanjut: atur budget'));
      await tester.tap(find.text('Lanjut: atur budget'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '85000',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
