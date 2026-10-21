import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/transaction_model.dart';
import 'package:flutter_application_1/screens/manual_expense_screen.dart';
import 'package:flutter_application_1/screens/transaction_history_screen.dart';
import 'package:flutter_application_1/services/manual_tour.dart';
import 'package:flutter_application_1/widgets/expense_floating_menu.dart';

class LiveTourHost extends StatefulWidget {
  const LiveTourHost({super.key});
  @override
  State<LiveTourHost> createState() => _LiveTourHostState();
}

class _LiveTourHostState extends State<LiveTourHost> {
  final tour = ManualTour.instance;
  int tab = 0;
  @override
  void initState() {
    super.initState();
    tour.onStart = () => tab = 0;
    tour.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    tour.removeListener(refresh);
    tour.onStart = null;
    tour.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: tab == 0
        ? Center(
            child: FilledButton(
              onPressed: () => tour.start(context),
              child: const Text('Mulai'),
            ),
          )
        : TransactionHistoryScreen(
            history: [if (tour.example != null) tour.example!],
            onDelete: (_) => tour.stop(),
            onUpdateDate: (_, _) {},
            onUpdateTransaction: (_) => tour.go(ManualTourStep.delete),
          ),
    floatingActionButton: tab == 0
        ? ExpenseFloatingMenu(
            onManualEntry: () async {
              final tx = await Navigator.of(context).push<TransactionModel>(
                MaterialPageRoute(
                  builder: (_) => const ManualExpenseScreen(tutorial: true),
                ),
              );
              if (tx != null && tour.active) {
                tour.example = tx;
                tour.go(ManualTourStep.history);
              }
            },
            onGallery: () async {},
            onCamera: () async {},
          )
        : null,
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) {
        setState(() => tab = value);
        if (value == 1) tour.go(ManualTourStep.transaction);
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          key: tour.key('history'),
          icon: const Icon(Icons.receipt_long),
          label: 'Riwayat',
        ),
      ],
    ),
  );
}

void main() {
  testWidgets(
    'Coach marks use original add menu, form, history, edit and delete controls',
    (tester) async {
      tester.view.physicalSize = const Size(430, 930);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LiveTourHost()));
      Future<void> wait() async {
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> tapKey(String target) async {
        await wait();
        await tester.tap(
          find.byKey(ManualTour.instance.key(target)),
          warnIfMissed: true,
        );
        await wait();
      }

      await tester.tap(find.text('Mulai'));
      await tapKey('add');
      expect(ManualTour.instance.step, ManualTourStep.menu);
      await tapKey('manual');
      expect(find.byType(ManualExpenseScreen), findsOneWidget);
      for (var i = 0; i < 65; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(ManualTour.instance.step, ManualTourStep.save);
      expect(
        find.text(ManualTour.instance.message).hitTestable(),
        findsOneWidget,
      );
      await tapKey('save');
      await tapKey('history');
      expect(find.byType(TransactionHistoryScreen), findsOneWidget);
      await tapKey('transaction');
      await tapKey('edit');
      for (var i = 0; i < 65; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(ManualTour.instance.step, ManualTourStep.saveEdit);
      expect(
        find.text(ManualTour.instance.message).hitTestable(),
        findsOneWidget,
      );
      await tapKey('saveEdit');
      expect(ManualTour.instance.step, ManualTourStep.delete);
      await tapKey('delete');
      expect(ManualTour.instance.active, isFalse);
      expect(ManualTour.instance.example, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Exiting during automatic typing cancels work safely', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LiveTourHost()));
    await tester.tap(find.text('Mulai'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(ManualTour.instance.key('add')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(ManualTour.instance.key('manual')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ManualExpenseScreen), findsOneWidget);
    expect(ManualTour.instance.step, ManualTourStep.filling);
    ManualTour.instance.cancel();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
