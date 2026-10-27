/// Calendar-month access limits; stored transactions are never trimmed.
class PlanAccess {
  const PlanAccess({this.isPremium = false});

  // Open access during the one-year usage evaluation launched October 2026.
  // Re-enable limits only after reviewing usage; do not expire access on-device.
  static const freeFeaturesOpen = true;

  final bool isPremium;
  bool get hasFullFeatureAccess => freeFeaturesOpen || isPremium;
  int get monthCount => hasFullFeatureAccess ? 12 : 2;

  List<DateTime> months(DateTime now) => List.generate(
    monthCount,
    (offset) => DateTime(now.year, now.month - offset),
  );

  bool includes(DateTime date, DateTime now) {
    final offset = (now.year - date.year) * 12 + now.month - date.month;
    return offset >= 0 && offset < monthCount;
  }
}
