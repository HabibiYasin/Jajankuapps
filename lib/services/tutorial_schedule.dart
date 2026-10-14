import 'package:shared_preferences/shared_preferences.dart';

class TutorialSchedule {
  static DateTime _day(DateTime value) {
    final local = value.toLocal();
    return DateTime.utc(local.year, local.month, local.day);
  }

  static bool shouldShow(
    SharedPreferences preferences, {
    required String uid,
    required DateTime createdAt,
    required DateTime now,
  }) {
    final age = _day(now).difference(_day(createdAt)).inDays;
    if (age < 0 || age >= 3) return false;
    final lastShown = DateTime.tryParse(
      preferences.getString('tutorial_last_shown_at_$uid') ?? '',
    );
    if (lastShown != null && !_day(now).isAfter(_day(lastShown))) {
      return false;
    }
    // Respect today's dismissal from versions using the previous schedule.
    final hidden = DateTime.tryParse(
      preferences.getString('tutorial_hidden_date') ?? '',
    );
    return hidden == null || _day(hidden) != _day(now);
  }

  static Future<bool> recordShown(
    SharedPreferences preferences, {
    required String uid,
    required DateTime now,
  }) => preferences.setString(
    'tutorial_last_shown_at_$uid',
    now.toIso8601String(),
  );
}
