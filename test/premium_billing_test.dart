import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/premium_billing_service.dart';

import 'profile_name_test.dart' show profileApp;

PricingPhaseWrapper phase(
  int price, {
  bool intro = false,
  String period = 'P1M',
}) => PricingPhaseWrapper(
  billingCycleCount: intro ? 1 : 0,
  billingPeriod: period,
  formattedPrice: 'Rp$price',
  priceAmountMicros: price * 1000000,
  priceCurrencyCode: 'IDR',
  recurrenceMode: intro
      ? RecurrenceMode.finiteRecurring
      : RecurrenceMode.infiniteRecurring,
);

List<GooglePlayProductDetails> products({int discountPrice = 10000}) =>
    GooglePlayProductDetails.fromProductDetails(
      ProductDetailsWrapper(
        description: 'Premium',
        name: 'Premium',
        productId: 'jajanku_premium',
        productType: ProductType.subs,
        title: 'Premium',
        subscriptionOfferDetails: [
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerTags: [],
            offerIdToken: 'normal-token',
            pricingPhases: [phase(20000)],
          ),
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerId: 'first-month-half',
            offerTags: [],
            offerIdToken: 'intro-token',
            pricingPhases: [phase(discountPrice, intro: true), phase(20000)],
          ),
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'six-monthly',
            offerTags: [],
            offerIdToken: 'six-token',
            pricingPhases: [phase(100000, period: 'P6M')],
          ),
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'six-monthly',
            offerId: 'first-six-months-half',
            offerTags: [],
            offerIdToken: 'six-intro-token',
            pricingPhases: [
              phase(50000, intro: true, period: 'P6M'),
              phase(100000, period: 'P6M'),
            ],
          ),
        ],
      ),
    );

void main() {
  test('first-time account selects exact 50% Play offers for both plans', () {
    final offers = PremiumBillingService.selectOffers(
      products(),
      eligibleForIntro: true,
    );
    expect(offers['monthly']!.details.offerIdToken, 'intro-token');
    expect(offers['monthly']!.price, 'Rp10000');
    expect(offers['monthly']!.renewalPrice, 'Rp20000');
    expect(offers['six-monthly']!.details.offerIdToken, 'six-intro-token');
    expect(offers['six-monthly']!.renewalPrice, 'Rp100000');
  });
  test('former VIP can only select normal prices, independent of returned product order', () {
    final offers = PremiumBillingService.selectOffers(
      products().reversed.toList(),
      eligibleForIntro: false,
    );
    expect(offers['monthly']!.details.offerIdToken, 'normal-token');
    expect(offers['six-monthly']!.details.offerIdToken, 'six-token');
  });
  test('misconfigured discount and missing products never become advertised half-price offers', () {
    final offers = PremiumBillingService.selectOffers(
      products(discountPrice: 15000),
      eligibleForIntro: true,
    );
    expect(offers['monthly']!.discounted, isFalse);
    expect(
      PremiumBillingService.selectOffers([], eligibleForIntro: true),
      isEmpty,
    );
  });
  testWidgets('Personalisasi opens Upgrade Akun and Guest must sign in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(profileApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upgrade Akun'));
    await tester.pumpAndSettle();
    expect(find.text('Status akun'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Masuk / Daftar'), findsOneWidget);
    expect(find.text('Langganan 1 bulan'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
