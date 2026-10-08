/// Calendar-month access limits; stored transactions are never trimmed.
class PlanAccess {
  const PlanAccess({this.isPremium = false});

  final bool isPremium;
  int get monthCount => isPremium ? 12 : 2;

  List<DateTime> months(DateTime now) => List.generate(
    monthCount,
    (offset) => DateTime(now.year, now.month - offset),
  );

  bool includes(DateTime date, DateTime now) {
    final offset = (now.year - date.year) * 12 + now.month - date.month;
    return offset >= 0 && offset < monthCount;
  }
}
