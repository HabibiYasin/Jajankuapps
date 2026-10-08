import 'dart:ui' as ui;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/spending_card_style.dart';
import 'package:flutter_application_1/models/spending_progress.dart';
import 'package:flutter_application_1/services/profile_plan_store.dart';
import 'package:flutter_application_1/services/spending_card_renderer.dart';
import 'package:flutter_application_1/widgets/spending_card_customizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('VIP follows the account plan and revocation', () async {
    final firestore = FakeFirebaseFirestore();
    final profile = firestore.collection('users').doc('vip-user');
    final store = ProfilePlanStore(firestore);
    expect(await store.watchVip('missing-user').first, isFalse);
    await profile.set({'plan': 'free'});
    final states = <bool>[];
    final subscription = store.watchVip('vip-user').listen(states.add);
    await pumpEventQueue();
    await profile.update({'plan': 'premium'});
    await pumpEventQueue();
    await profile.update({'plan': 'free'});
    await pumpEventQueue();
    await profile.update({'plan': 'unknown'});
    await pumpEventQueue();
    expect(states, [false, true, false, false]);
    await subscription.cancel();
  });

  testWidgets(
    'Six colors and all characters can be selected on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var character = SpendingCardCharacter.jajanku;
      SpendingCardColor? color;
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return SpendingCardCustomizer(
                    character: character,
                    cardColor: color,
                    enabled: enabled,
                    onCharacterChanged: (value) =>
                        setState(() => character = value),
                    onColorChanged: (value) => setState(() => color = value),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(6));
      for (final option in SpendingCardCharacter.values) {
        final label = find.text(option.label);
        await tester.ensureVisible(label);
        await tester.tap(label);
        await tester.pumpAndSettle();
        expect(character, option);
      }
      for (final option in SpendingCardColor.values) {
        await tester.ensureVisible(find.text(option.label));
        await tester.tap(find.text(option.label));
        await tester.pumpAndSettle();
        expect(color, option);
      }
      update(() => enabled = false);
      await tester.pump();
      await tester.tap(find.text('Oranye'));
      expect(color, SpendingCardColor.green);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Every VIP mascot exports with six backgrounds and a neutral report panel',
    () async {
      final data = SpendingProgress(
        period: 'Bulan Ini',
        date: DateTime(2026, 10, 8),
        spent: 60000,
        budget: 100000,
        monthly: true,
      );
      Future<ui.Image> render(
        SpendingCardCharacter character,
        SpendingCardColor color,
      ) async {
        final bytes = await SpendingCardRenderer.render(
          data,
          character: character,
          cardColor: color,
          hideAmounts: true,
        );
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        expect(image.width, 1080);
        expect(image.height, 1920);
        return image;
      }

      final mascotPixels = <String>{};
      for (final character in SpendingCardCharacter.values) {
        final image = await render(character, SpendingCardColor.turquoise);
        final pixels = (await image.toByteData())!.buffer.asUint8List();
        // Compare the character region, excluding the surrounding text.
        final region = <int>[];
        for (var y = 530; y < 890; y += 12) {
          for (var x = 490; x < 950; x += 12) {
            final offset = (y * 1080 + x) * 4;
            region.addAll(pixels.sublist(offset, offset + 4));
          }
        }
        mascotPixels.add(region.join(','));
        image.dispose();
      }
      expect(mascotPixels.length, 7);

      final backgrounds = <int>{};
      final reportPanels = <int>{};
      for (final color in SpendingCardColor.values) {
        final image = await render(SpendingCardCharacter.esDoger, color);
        final pixels = (await image.toByteData())!;
        backgrounds.add(pixels.getUint32((50 * 1080 + 50) * 4));
        reportPanels.add(pixels.getUint32((1400 * 1080 + 90) * 4));
        image.dispose();
      }
      expect(backgrounds.length, 6);
      expect(reportPanels.length, 1);
    },
  );
}
