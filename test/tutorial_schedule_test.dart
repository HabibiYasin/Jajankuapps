import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/tutorial_schedule.dart';

void main() {
  late SharedPreferences preferences;
  final createdAt = DateTime(2026, 10, 14, 23, 50);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  bool shouldShow(DateTime now, {String uid = 'new-user'}) =>
      TutorialSchedule.shouldShow(
        preferences,
        uid: uid,
        createdAt: createdAt,
        now: now,
      );

  test('Shows once per calendar day for the first three days only', () async {
    for (var day = 14; day <= 16; day++) {
      final now = DateTime(2026, 10, day, 23, 55);
      expect(shouldShow(now), isTrue);
      await TutorialSchedule.recordShown(
        preferences,
        uid: 'new-user',
        now: now,
      );
      expect(shouldShow(DateTime(2026, 10, day, 23, 59)), isFalse);
    }
    expect(shouldShow(DateTime(2026, 10, 17)), isFalse);
    expect(shouldShow(DateTime(2027, 1, 1)), isFalse);
  });

  test(
    'A new calendar day is eligible even less than 24 hours later',
    () async {
      await TutorialSchedule.recordShown(
        preferences,
        uid: 'new-user',
        now: createdAt,
      );
      expect(shouldShow(DateTime(2026, 10, 15, 0, 1)), isTrue);
    },
  );

  test(
    'History survives reopening preferences and is separate per account',
    () async {
      await TutorialSchedule.recordShown(
        preferences,
        uid: 'new-user',
        now: createdAt,
      );
      preferences = await SharedPreferences.getInstance();
      expect(shouldShow(createdAt), isFalse);
      expect(shouldShow(createdAt, uid: 'other-user'), isTrue);
    },
  );

  test('An older account gets no popup even without saved history', () {
    expect(shouldShow(DateTime(2026, 10, 20)), isFalse);
    expect(shouldShow(DateTime(2026, 10, 13)), isFalse);
  });

  test(
    'Respects a dismissal from the old version and ignores malformed dates',
    () async {
      await preferences.setString(
        'tutorial_hidden_date',
        createdAt.toIso8601String(),
      );
      expect(shouldShow(createdAt), isFalse);
      await preferences.setString('tutorial_hidden_date', 'invalid');
      await preferences.setString('tutorial_last_shown_at_new-user', 'invalid');
      expect(shouldShow(createdAt), isTrue);
    },
  );
}
