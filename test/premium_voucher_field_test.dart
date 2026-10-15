import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/premium_voucher_field.dart';

void main() {
  testWidgets('automatic code, manual input, remove and busy state', (
    tester,
  ) async {
    String? applied;
    var removed = false;
    Widget app({String? code, bool busy = false}) => MaterialApp(
      home: Scaffold(
        body: PremiumVoucherField(
          appliedCode: code,
          busy: busy,
          onApply: (v) => applied = v,
          onRemove: () => removed = true,
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpWidget(app(code: 'cobapremium'));
    expect(find.text('cobapremium'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  COBApremium ');
    await tester.tap(find.text('Terapkan'));
    expect(applied, 'cobapremium');
    await tester.tap(find.text('Hapus voucher'));
    expect(removed, isTrue);
    expect(find.text('cobapremium'), findsNothing);
    await tester.pumpWidget(app(busy: true));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
