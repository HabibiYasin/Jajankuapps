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
    if (preferences.getBool('tutorial_disabled_$uid') ?? false) return false;
    final start =
        DateTime.tryParse(
          preferences.getString('tutorial_started_at_$uid') ?? '',
        ) ??
        now;
    final age = _day(now).difference(_day(start)).inDays;
    if (age < 0 || age >= 5) return false;
    for (final key in ['tutorial_hidden_date_$uid', 'tutorial_hidden_date']) {
      final hidden = DateTime.tryParse(preferences.getString(key) ?? '');
      if (hidden != null && _day(hidden) == _day(now)) return false;
    }
    final last = DateTime.tryParse(
      preferences.getString('tutorial_last_shown_at_$uid') ?? '',
    );
    return last == null ||
        _day(last) != _day(now) ||
        (preferences.getInt('tutorial_daily_count_$uid') ?? 0) < 3;
  }

  static Future<bool> recordShown(
    SharedPreferences preferences, {
    required String uid,
    required DateTime now,
  }) async {
    if (preferences.getString('tutorial_started_at_$uid') == null) {
      if (!await preferences.setString(
        'tutorial_started_at_$uid',
        now.toIso8601String(),
      )) {
        return false;
      }
    }
    final last = DateTime.tryParse(
      preferences.getString('tutorial_last_shown_at_$uid') ?? '',
    );
    final count = last != null && _day(last) == _day(now)
        ? preferences.getInt('tutorial_daily_count_$uid') ?? 0
        : 0;
    if (!await preferences.setInt('tutorial_daily_count_$uid', count + 1)) {
      return false;
    }
    return preferences.setString(
      'tutorial_last_shown_at_$uid',
      now.toIso8601String(),
    );
  }
}
