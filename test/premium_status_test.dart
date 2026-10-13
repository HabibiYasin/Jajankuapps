import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/premium_status.dart';
import 'package:flutter_application_1/services/profile_plan_store.dart';
import 'package:flutter_application_1/widgets/premium_access_details.dart';

void main() {
  final now = DateTime(2026, 10, 13);
  test('Lifetime overrides missing/expired billing dates, and revocation restores paid eligibility', () {
    final data = <String, dynamic>{
      'plan': 'free',
      'premiumLifetime': true,
      'hasEverBeenPremium': true,
    };
    final lifetime = PremiumStatus.fromMap(data);
    expect(lifetime.isActiveAt(DateTime(2200)), isTrue);
    expect(lifetime.hasEverBeenPremium, isTrue);
    expect(
      PremiumStatus.fromMap({'premiumLifetime': true}).hasEverBeenPremium,
      isTrue,
    );
    expect(
      PremiumStatus.fromMap({...data, 'premiumLifetime': false})
          .isActiveAt(now),
      isFalse,
    );
    expect(
      PremiumStatus.fromMap({...data, 'premiumLifetime': 'true'})
          .isActiveAt(now),
      isFalse,
    );
    final paid = {
      ...data,
      'plan': 'premium',
      'premiumLifetime': false,
      'PremiumStartedAt': Timestamp.fromDate(
        now.subtract(const Duration(days: 1)),
      ),
      'PremiumEndedAt': Timestamp.fromDate(now.add(const Duration(days: 1))),
    };
    expect(PremiumStatus.fromMap(paid).isActiveAt(now), isTrue);
    expect(PremiumStatus.fromMap(paid).isActiveAt(DateTime(2200)), isFalse);
    expect(
      PremiumStatus.fromMap({...paid, 'premiumLifetime': true})
          .isActiveAt(DateTime(2200)),
      isTrue,
    );
  });

  test('Lifetime stream handles null end date and admin revocation without a timer', () async {
    final db = FakeFirebaseFirestore();
    final profile = db.collection('users').doc('tester');
    await profile.set({
      'plan': 'free',
      'premiumLifetime': true,
      'hasEverBeenPremium': true,
    });
    final states = <bool>[];
    final subscription = ProfilePlanStore(db)
        .watchVip('tester')
        .listen(states.add);
    await pumpEventQueue();
    await profile.update({'premiumLifetime': false});
    await pumpEventQueue();
    expect(states, [true, false]);
    expect((await profile.get()).data()!['hasEverBeenPremium'], isTrue);
    await subscription.cancel();
  });

  testWidgets(
    'Lifetime shows no expiry or renewal claim even with old paid dates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PremiumAccessDetails(
              status: PremiumStatus(
                isLifetime: true,
                endedAt: DateTime(2020),
                autoRenewing: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Premium seumur hidup'), findsOneWidget);
      expect(find.textContaining('Periode premium berakhir'), findsNothing);
      expect(find.text('Perpanjangan otomatis aktif.'), findsNothing);
      expect(find.textContaining('batalkan langganan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('Premium needs valid dates; expiration never resets VIP history', () {
    final data = {
      'plan': 'premium',
      'PremiumStartedAt': Timestamp.fromDate(
        now.subtract(const Duration(days: 1)),
      ),
      'PremiumEndedAt': Timestamp.fromDate(now.add(const Duration(days: 1))),
    };
    final status = PremiumStatus.fromMap(data);
    expect(status.isActiveAt(now), isTrue);
    expect(status.isActiveAt(now.add(const Duration(days: 1))), isFalse);
    expect(status.hasEverBeenPremium, isTrue);
    expect(
      PremiumStatus.fromMap({...data, 'plan': 'free'}).hasEverBeenPremium,
      isTrue,
    );
    expect(PremiumStatus.fromMap({'plan': 'vip'}).hasEverBeenPremium, isTrue);
    expect(PremiumStatus.fromMap({'plan': 'premium'}).isActiveAt(now), isFalse);
    expect(PremiumStatus.fromMap(null).isActiveAt(now), isFalse);
    expect(
      PremiumStatus.fromMap({'hasEverBeenPremium': true}).hasEverBeenPremium,
      isTrue,
    );
  });

  test(
    'VIP stream expires without another Firestore write and isolates users',
    () async {
      final db = FakeFirebaseFirestore();
      final expiry = DateTime.now().add(const Duration(milliseconds: 250));
      await db.collection('users').doc('alice').set({
        'plan': 'premium',
        'PremiumStartedAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
        'PremiumEndedAt': Timestamp.fromDate(expiry),
      });
      final result = ProfilePlanStore(db).watch('alice').take(2).toList();
      await db.collection('users').doc('bob').set({'plan': 'free'});
      final states = await result.timeout(const Duration(seconds: 5));
      expect(states, hasLength(2));
      expect(states.last.isActiveAt(expiry), isFalse);
    },
  );
}
