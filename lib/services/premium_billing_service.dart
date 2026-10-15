import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_environment.dart';
import 'auth_service.dart';

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.title,
    required this.billingPeriod,
    this.price = 0,
    this.durationDays = 0,
  });
  final String id;
  final String title;
  final String billingPeriod;
  final int price;
  final int durationDays;
  factory SubscriptionPlan.fromMap(Map<dynamic, dynamic> data) =>
      SubscriptionPlan(
        id: data['id'] as String,
        title: data['title'] as String,
        billingPeriod: data['billingPeriod'] as String,
        price: (data['price'] as num?)?.toInt() ?? 0,
        durationDays: (data['durationDays'] as num?)?.toInt() ?? 0,
      );
}

class PremiumVoucher {
  const PremiumVoucher({
    required this.name,
    required this.title,
    required this.eligibleUntil,
    required this.quotes,
  });
  final String name;
  final String title;
  final DateTime eligibleUntil;
  final Map<String, Map<dynamic, dynamic>> quotes;
  factory PremiumVoucher.fromMap(Map<dynamic, dynamic> data) => PremiumVoucher(
    name: data['name'] as String,
    title: data['title'] as String,
    eligibleUntil: DateTime.fromMillisecondsSinceEpoch(
      (data['eligibleUntil'] as num).toInt(),
    ),
    quotes: (data['quotes'] as Map).map(
      (key, value) => MapEntry(key as String, value as Map),
    ),
  );
  bool get expired => !DateTime.now().isBefore(eligibleUntil);
}

class PremiumOffer {
  const PremiumOffer(this.product, this.details);
  final GooglePlayProductDetails product;
  final SubscriptionOfferDetailsWrapper details;
  bool get discounted => details.offerId != null;
  String get price => details.pricingPhases.first.formattedPrice;
  String get renewalPrice => details.pricingPhases.last.formattedPrice;
}

class PremiumBillingService extends ChangeNotifier {
  PremiumBillingService._();
  static final instance = PremiumBillingService._();
  static const productId = 'jajanku_premium';
  static const defaultPlans = [
    SubscriptionPlan(id: 'monthly', title: '1 bulan', billingPeriod: 'P1M'),
    SubscriptionPlan(id: 'six-monthly', title: '6 bulan', billingPeriod: 'P6M'),
  ];
  List<SubscriptionPlan> plans = [];
  PremiumVoucher? voucher;
  String? _voucherCode; // null: automatic, empty: explicitly removed
  Timer? _voucherExpiry;
  String? voucherMessage;

  Future<void> applyVoucher(String code) async {
    if (loading || busy) return;
    _voucherCode = code.trim().toLowerCase();
    await loadOffers();
  }

  Future<void> removeVoucher() async {
    if (loading || busy) return;
    _voucherCode = '';
    await loadOffers();
  }

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool busy = false;
  bool loading = false;
  bool eligibleForIntro = false;
  String? message;
  Map<String, PremiumOffer> offers = {};
  bool _started = false;
  int _generation = 0;
  String? _owner;
  String? _obfuscatedAccountId;
  Future<void> _processing = Future.value();
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-southeast2');

  // App-lifetime listener: leaving the upgrade screen must not lose a purchase.
  void start() {
    if (_started || !supported || !AuthService.instance.isConfigured) return;
    _started = true;
    InAppPurchase.instance.purchaseStream.listen(
      (purchases) {
        final uid = AuthService.instance.currentUser?.uid;
        _processing = _processing.then((_) => _process(purchases, uid));
      },
      onError: (Object _) {
        busy = false;
        message = 'Google Play belum dapat dihubungi. Coba pulihkan pembelian.';
        notifyListeners();
      },
    );
    AuthService.instance.authStateChanges.listen((user) {
      final uid = AuthService.needsEmailVerification(user) ? null : user?.uid;
      if (_owner == uid) return;
      _owner = uid;
      ++_generation;
      offers = {};
      plans = [];
      voucher = null;
      voucherMessage = null;
      _voucherCode = null;
      _voucherExpiry?.cancel();
      _obfuscatedAccountId = null;
      eligibleForIntro = false;
      busy = false;
      loading = false;
      message = null;
      notifyListeners();
      if (uid != null) unawaited(restore(silent: true));
    });
  }

  static Map<String, PremiumOffer> selectOffers(
    List<ProductDetails> products, {
    required bool eligibleForIntro,
    List<SubscriptionPlan> plans = defaultPlans,
    PremiumVoucher? voucher,
  }) {
    final result = <String, PremiumOffer>{};
    for (final product in products.whereType<GooglePlayProductDetails>()) {
      if (product.id != productId || product.subscriptionIndex == null) {
        continue;
      }
      final details = product
          .productDetails
          .subscriptionOfferDetails![product.subscriptionIndex!];
      final matches = plans.where((p) => p.id == details.basePlanId);
      if (matches.isEmpty) continue;
      final plan = matches.first;
      final phases = details.pricingPhases;
      final period = plan.billingPeriod;
      if (phases.isEmpty ||
          phases.last.billingPeriod != period ||
          phases.last.recurrenceMode != RecurrenceMode.infiniteRecurring) {
        continue;
      }
      final quote = voucher?.quotes[plan.id];
      if (quote != null) {
        if (voucher!.expired ||
            details.offerId != voucher.name ||
            phases.length != 2 ||
            phases.first.billingPeriod != period ||
            phases.first.billingCycleCount != 1 ||
            phases.first.recurrenceMode != RecurrenceMode.finiteRecurring ||
            phases.first.priceCurrencyCode != 'IDR' ||
            phases.last.priceCurrencyCode != 'IDR' ||
            phases.first.priceAmountMicros !=
                (quote['total'] as num) * 1000000 ||
            phases.last.priceAmountMicros !=
                (quote['price'] as num) * 1000000) {
          continue;
        }
      } else if (details.offerId != null || phases.length != 1) {
        continue;
      }
      if (result[details.basePlanId]?.discounted != true) {
        result[details.basePlanId] = PremiumOffer(product, details);
      }
    }
    return result;
  }

  Future<void> loadOffers() async {
    if (loading || busy) return;
    if (!supported) {
      message =
          'Pembelian premium tersedia melalui aplikasi Android di Google Play.';
      notifyListeners();
      return;
    }
    final user = AuthService.instance.currentUser;
    if (user == null || AuthService.needsEmailVerification(user)) return;
    final generation = ++_generation;
    loading = true;
    message = null;
    offers = {};
    voucher = null;
    voucherMessage = null;
    _voucherExpiry?.cancel();
    notifyListeners();
    try {
      if (!await InAppPurchase.instance.isAvailable()) {
        throw StateError(
          'Google Play Billing tidak tersedia. Gunakan perangkat Android dengan Play Store dan akun Google yang aktif.',
        );
      }
      final eligibility = await _functions
          .httpsCallable('preparePremiumPurchase')
          .call({'voucherCode': _voucherCode});
      final response = await InAppPurchase.instance.queryProductDetails({
        productId,
      });
      if (generation != _generation ||
          AuthService.instance.currentUser?.uid != user.uid) {
        return;
      }
      if (response.error != null) {
        throw StateError(
          'Google Play gagal memuat produk (${response.error!.code}).',
        );
      }
      voucher = eligibility.data['voucher'] == null
          ? null
          : PremiumVoucher.fromMap(eligibility.data['voucher'] as Map);
      plans = (eligibility.data['plans'] as List)
          .map((data) => SubscriptionPlan.fromMap(data as Map))
          .toList();
      eligibleForIntro = eligibility.data['eligibleForIntro'] == true;
      _obfuscatedAccountId = eligibility.data['obfuscatedAccountId'] as String;
      offers = selectOffers(
        response.productDetails,
        eligibleForIntro: eligibleForIntro,
        plans: plans,
        voucher: voucher,
      );
      if (voucher != null) {
        final ready = voucher!.quotes.keys.any(
          (id) => offers[id]?.discounted == true,
        );
        voucherMessage = ready
            ? '${voucher!.title} diterapkan pada paket yang memenuhi syarat.'
            : '${voucher!.title} memenuhi syarat, tetapi harga promo belum tersedia di Google Play. Hapus voucher untuk memakai harga normal.';
        final remaining = voucher!.eligibleUntil.difference(DateTime.now());
        _voucherExpiry = Timer(
          remaining.isNegative ? Duration.zero : remaining,
          () {
            offers = {};
            voucher = null;
            voucherMessage = 'Voucher sudah kedaluwarsa. Muat ulang paket.';
            notifyListeners();
          },
        );
      }
      if (offers.length != plans.length) {
        message = 'Paket belum tersedia di Google Play. Pastikan base plan aktif, wilayah tersedia, dan aplikasi terpasang melalui jalur pengujian Play.';
      }
    } on FirebaseFunctionsException catch (error) {
      if (generation != _generation) return;
      message = error.code == 'failed-precondition'
          ? error.message
          : 'Server pembelian belum dapat dihubungi (${error.code}). Periksa deployment Functions dan koneksi.';
    } catch (error) {
      if (generation != _generation) return;
      message = error is StateError ? error.message.toString() : 'Paket premium belum dapat dimuat. Periksa koneksi dan konfigurasi langganan.';
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> buy(String basePlanId) async {
    final user = AuthService.instance.currentUser;
    final offer = offers[basePlanId];
    if (busy ||
        loading ||
        user == null ||
        offer == null ||
        _obfuscatedAccountId == null) {
      return;
    }
    final generation = _generation;
    busy = true;
    message = null;
    notifyListeners();
    try {
      // Recheck account history immediately before opening Google's payment sheet.
      final eligibility = await _functions
          .httpsCallable('preparePremiumPurchase')
          .call({'voucherCode': _voucherCode});
      if (AuthService.instance.currentUser?.uid != user.uid ||
          generation != _generation) {
        return;
      }
      final currentPlans = (eligibility.data['plans'] as List)
          .map((data) => SubscriptionPlan.fromMap(data as Map))
          .toList();
      final currentOffers = selectOffers(
        [offer.product],
        eligibleForIntro: eligibility.data['eligibleForIntro'] == true,
        plans: currentPlans,
        voucher: eligibility.data['voucher'] == null
            ? null
            : PremiumVoucher.fromMap(eligibility.data['voucher'] as Map),
      );
      if (currentOffers[basePlanId]?.details.offerIdToken !=
          offer.details.offerIdToken) {
        offers = {};
        throw StateError('Catalog changed');
      }

      final opened = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(
          productDetails: offer.product,
          applicationUserName:
              eligibility.data['obfuscatedAccountId'] as String,
          offerToken: offer.details.offerIdToken,
        ),
      );
      if (!opened) throw StateError('Billing not opened');
    } catch (_) {
      if (generation == _generation) {
        busy = false;
        message =
            'Pembelian belum bisa dimulai. Muat ulang paket dan coba lagi.';
        notifyListeners();
      }
    }
  }

  Future<void> _process(List<PurchaseDetails> purchases, String? uid) async {
    for (final purchase in purchases) {
      if (purchase.productID != productId ||
          uid == null ||
          AuthService.instance.currentUser?.uid != uid) {
        continue;
      }
      try {
        switch (purchase.status) {
          case PurchaseStatus.pending:
            busy = false;
            message = 'Menunggu pembayaran Google Play. Premium aktif setelah pembayaran terverifikasi.';
          case PurchaseStatus.canceled:
            busy = false;
            message = 'Pembelian dibatalkan.';
          case PurchaseStatus.error:
            busy = false;
            message = 'Pembelian gagal. Periksa Google Play, lalu coba lagi.';
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            final result = await _functions
                .httpsCallable('verifyPremiumPurchase')
                .call({
                  'purchaseToken':
                      purchase.verificationData.serverVerificationData,
                });
            // Server grants entitlement and acknowledges before the client finishes.
            if (result.data['pending'] != true &&
                purchase.pendingCompletePurchase) {
              await InAppPurchase.instance.completePurchase(purchase);
            }
            if (AuthService.instance.currentUser?.uid != uid) continue;
            busy = false;
            offers = {};
            message = result.data['active'] == true
                ? 'Premium aktif. Terima kasih sudah berlangganan!'
                : 'Status pembelian sudah diperbarui.';
        }
      } on FirebaseFunctionsException catch (error) {
        if (AuthService.instance.currentUser?.uid != uid) continue;
        busy = false;
        message = error.code == 'permission-denied'
            ? 'Pembelian terhubung ke akun Jajanku lain. Masuk dengan akun saat membeli.'
            : error.code == 'failed-precondition'
            ? error.message
            : 'Verifikasi belum selesai. Ketuk Pulihkan pembelian untuk mencoba lagi.';
      } catch (_) {
        if (AuthService.instance.currentUser?.uid != uid) continue;
        busy = false;
        message = 'Verifikasi belum selesai. Ketuk Pulihkan pembelian untuk mencoba lagi.';
      }
      notifyListeners();
    }
  }

  Future<void> restore({bool silent = false}) async {
    if (!supported || AuthService.instance.currentUser == null || busy) return;
    final uid = AuthService.instance.currentUser!.uid;
    try {
      await InAppPurchase.instance.restorePurchases();
      if (!silent && AuthService.instance.currentUser?.uid == uid) {
        message =
            'Pemulihan diminta. Pembelian yang ditemukan akan diverifikasi.';
        notifyListeners();
      }
    } catch (_) {
      if (!silent && AuthService.instance.currentUser?.uid == uid) {
        message = 'Pembelian belum bisa dipulihkan. Periksa koneksi dan akun Google Play.';
        notifyListeners();
      }
    }
  }

  Future<void> manageSubscription() async {
    final package = AppEnvironment.current == AppEnvironment.prod
        ? 'com.jajanku.app'
        : 'com.jajanku.app.dev';
    try {
      final opened = await launchUrl(
        Uri.https('play.google.com', '/store/account/subscriptions', {
          'sku': productId,
          'package': package,
        }),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Cannot open Play');
    } catch (_) {
      message = 'Buka Google Play > Pembayaran & langganan > Langganan untuk mengelola premium.';
      notifyListeners();
    }
  }
}
