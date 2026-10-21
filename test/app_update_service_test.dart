import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/app_update_service.dart';

void main() {
  late SharedPreferences prefs;
  Map<String, dynamic>? remote;
  bool offline = false;
  AppUpdateService service({
    int build = 3,
    String package = 'com.jajanku.app',
  }) => AppUpdateService(
    preferences: prefs,
    packageName: package,
    buildNumber: build,
    fetchPolicy: () async {
      if (offline) throw StateError('offline');
      return remote;
    },
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    remote = {'enabled': true, 'minimumBuildNumber': 4};
    offline = false;
  });
  test('Only builds below enabled minimum are blocked', () async {
    expect(await service().check(), isNotNull);
    expect(await service(build: 4).check(), isNull);
    expect(await service(build: 10).check(), isNull);
    remote = {'enabled': false, 'minimumBuildNumber': 4};
    expect(await service().check(), isNull);
  });
  test(
    'Cached enforcement survives offline restart and new build clears gate',
    () async {
      await service().check();
      prefs = await SharedPreferences.getInstance();
      offline = true;
      expect(await service().check(), isNotNull);
      expect(await service(build: 4).check(), isNull);
      expect(await service(package: 'com.jajanku.app.dev').check(), isNull);
    },
  );
  test('Offline first launch remains available', () async {
    offline = true;
    expect(await service().check(), isNull);
  });
  test(
    'Remote deletion or disabling clears a previously cached block',
    () async {
      await service().check();
      remote = null;
      expect(await service().check(), isNull);
      offline = true;
      expect(await service().check(), isNull);
      offline = false;
      remote = {'enabled': true, 'minimumBuildNumber': 4};
      await service().check();
      remote = {'enabled': false, 'minimumBuildNumber': 4};
      expect(await service().check(), isNull);
      offline = true;
      expect(await service().check(), isNull);
    },
  );
  test('Invalid remote values preserve last valid policy', () async {
    await service().check();
    for (final bad in [null, '4', 4.5, -1, 0]) {
      remote = {'enabled': true, 'minimumBuildNumber': bad};
      expect(await service().check(), isNotNull);
    }
  });
}
