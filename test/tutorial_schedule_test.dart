import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/tutorial_schedule.dart';

void main() {
  late SharedPreferences prefs;
  final start = DateTime(2026, 10, 20, 12);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  bool eligible(DateTime now, {String uid = 'user'}) =>
      TutorialSchedule.shouldShow(
        prefs,
        uid: uid,
        createdAt: DateTime(2020),
        now: now,
      );
  Future<bool> record(DateTime now) =>
      TutorialSchedule.recordShown(prefs, uid: 'user', now: now);
  test(
    'Three appearances daily for five calendar days from first appearance',
    () async {
      for (var day = 0; day < 5; day++) {
        final now = start.add(Duration(days: day));
        for (var appearance = 0; appearance < 3; appearance++) {
          expect(eligible(now), isTrue);
          await record(now);
        }
        expect(eligible(now), isFalse);
      }
      expect(eligible(start.add(const Duration(days: 5))), isFalse);
    },
  );
  test(
    'Hide today resets at midnight; forever persists; accounts are isolated',
    () async {
      await record(start);
      await prefs.setString(
        'tutorial_hidden_date_user',
        start.toIso8601String(),
      );
      expect(eligible(start), isFalse);
      expect(eligible(start.add(const Duration(days: 1))), isTrue);
      await prefs.setBool('tutorial_disabled_user', true);
      expect(eligible(start.add(const Duration(days: 1))), isFalse);
      expect(eligible(start, uid: 'other'), isTrue);
    },
  );
  test('Old dismissals respected and malformed dates tolerated', () async {
    await prefs.setString('tutorial_hidden_date', start.toIso8601String());
    expect(eligible(start), isFalse);
    await prefs.setString('tutorial_hidden_date', 'invalid');
    await prefs.setString('tutorial_last_shown_at_user', 'invalid');
    expect(eligible(start), isTrue);
  });
}
