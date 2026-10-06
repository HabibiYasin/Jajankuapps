import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/screens/personalization_screen.dart';
import 'package:flutter_application_1/services/budget_notification_service.dart';

const channel = MethodChannel('com.jajanku.app/budget_notification');
const settings = MaterialApp(
  home: Scaffold(
    body: PersonalizationScreen(
      userName: 'Guest',
      dailyLimit: 50000,
      weeklyLimit: 350000,
      monthlyLimit: 1500000,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'persistent switch saves both states and reloads disabled preference',
    (tester) async {
      var enabled = true;
      final changes = <bool>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getEnabled') return enabled;
            if (call.method == 'setEnabled') {
              enabled = (call.arguments as Map)['enabled'] as bool;
              changes.add(enabled);
            }
            return null;
          });
      await tester.pumpWidget(settings);
      await tester.pumpAndSettle();
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Notifikasi persistent',
      );
      expect(tester.widget<SwitchListTile>(toggle).value, true);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(enabled, false);
      expect(tester.widget<SwitchListTile>(toggle).value, false);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(settings);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, false);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(enabled, true);
      expect(changes, [false, true]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('failed toggle keeps previous switch value and allows retry', (
    tester,
  ) async {
    var shouldFail = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getEnabled') return true;
          if (call.method == 'setEnabled' && shouldFail) {
            throw PlatformException(code: 'BUDGET_NOTIFICATION');
          }
          return null;
        });
    await tester.pumpWidget(settings);
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(SwitchListTile, 'Notifikasi persistent');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, true);
    expect(
      find.text('Pengaturan notifikasi gagal disimpan. Coba lagi.'),
      findsOneWidget,
    );
    shouldFail = false;
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, false);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'budget synchronization does not overwrite persistent notification preference',
    (tester) async {
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return null;
          });
      await BudgetNotificationService.sync([], 50000);
      expect(received!.method, 'sync');
      expect((received!.arguments as Map).containsKey('enabled'), false);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'noon reminders can be enabled independently of persistent notifications',
    (tester) async {
      var persistent = false;
      var noon = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getEnabled':
                return persistent;
              case 'getNoonEnabled':
                return noon;
              case 'setNoonEnabled':
                noon = (call.arguments as Map)['enabled'] as bool;
              case 'setEnabled':
                persistent = (call.arguments as Map)['enabled'] as bool;
            }
            return null;
          });
      await tester.pumpWidget(settings);
      await tester.pumpAndSettle();
      final noonToggle = find.widgetWithText(
        SwitchListTile,
        'Pengingat jam 12 siang',
      );
      final persistentToggle = find.widgetWithText(
        SwitchListTile,
        'Notifikasi persistent',
      );
      expect(tester.widget<SwitchListTile>(persistentToggle).value, false);
      expect(tester.widget<SwitchListTile>(noonToggle).value, true);
      await tester.ensureVisible(noonToggle);
      await tester.tap(noonToggle);
      await tester.pumpAndSettle();
      expect(noon, false);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(settings);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(noonToggle).value, false);
      await tester.ensureVisible(noonToggle);
      await tester.tap(noonToggle);
      await tester.pumpAndSettle();
      expect(noon, true);
      expect(persistent, false);
      expect(tester.widget<SwitchListTile>(persistentToggle).value, false);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
