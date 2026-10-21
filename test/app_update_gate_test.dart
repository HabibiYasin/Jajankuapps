import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/app_update_service.dart';
import 'package:flutter_application_1/widgets/app_update_gate.dart';

void main() {
  const requiredUpdate = AppUpdatePolicy(enabled: true, minimumBuildNumber: 4);
  testWidgets(
    'Initial check blocks interaction; store failure offers retry; policy rollback unlocks',
    (tester) async {
      final pending = Completer<AppUpdatePolicy?>();
      var checks = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => AppUpdateGate(
            checkForUpdate: () =>
                checks++ == 0 ? pending.future : Future.value(null),
            openStore: () async => false,
            child: child!,
          ),
          home: const Scaffold(body: Text('App content')),
        ),
      );
      expect(find.text('App content'), findsNothing);
      pending.complete(requiredUpdate);
      await tester.pumpAndSettle();
      expect(find.text('Update diperlukan'), findsOneWidget);
      expect(find.text('App content'), findsNothing);
      await tester.tap(find.text('Update sekarang'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Tidak bisa membuka Play Store'),
        findsOneWidget,
      );
      await tester.tap(find.text('Periksa lagi'));
      await tester.pumpAndSettle();
      expect(find.text('App content'), findsOneWidget);
      expect(find.text('Update diperlukan'), findsNothing);
    },
  );
  testWidgets('Resume blocks existing routes and dialogs above the navigator', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    AppUpdatePolicy? policy;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) =>
            AppUpdateGate(checkForUpdate: () async => policy, child: child!),
        home: const Scaffold(body: Text('Home content')),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(title: Text('Existing dialog')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Existing dialog'), findsOneWidget);
    policy = requiredUpdate;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Existing dialog'), findsNothing);
    expect(find.text('Update diperlukan'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Update diperlukan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
