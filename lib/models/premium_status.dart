import 'package:cloud_firestore/cloud_firestore.dart';

class PremiumStatus {
  const PremiumStatus({
    this.plan = 'free',
    this.startedAt,
    this.endedAt,
    this.hasEverBeenPremium = false,
    this.autoRenewing = false,
    this.isLifetime = false,
  });

  factory PremiumStatus.fromMap(Map<String, dynamic>? data) {
    DateTime? date(String key) =>
        data?[key] is Timestamp ? (data![key] as Timestamp).toDate() : null;
    final plan = data?['plan'] as String? ?? 'free';
    return PremiumStatus(
      plan: plan,
      startedAt: date('PremiumStartedAt'),
      endedAt: date('PremiumEndedAt'),
      hasEverBeenPremium:
          data?['hasEverBeenPremium'] == true ||
          data?['premiumLifetime'] == true ||
          plan == 'premium' ||
          plan == 'vip' ||
          date('PremiumStartedAt') != null ||
          date('PremiumEndedAt') != null,
      autoRenewing: data?['premiumAutoRenewing'] == true,
      isLifetime: data?['premiumLifetime'] == true,
    );
  }

  final String plan;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final bool hasEverBeenPremium;
  final bool autoRenewing;
  final bool isLifetime;

  bool isActiveAt(DateTime now) =>
      isLifetime ||
      ((plan == 'premium' || plan == 'vip') &&
          startedAt != null &&
          !startedAt!.isAfter(now) &&
          endedAt != null &&
          endedAt!.isAfter(now));

  bool get isActive => isActiveAt(DateTime.now());
}
