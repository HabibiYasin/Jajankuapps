import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/config/app_environment.dart';
import 'package:flutter_application_1/firebase_options.dart';

void main() {
  test('Build flavor selects environment independently of build mode', () {
    expect(AppEnvironment.resolve('dev'), AppEnvironment.dev);
    expect(AppEnvironment.resolve('prod'), AppEnvironment.prod);
    expect(() => AppEnvironment.resolve(null), throwsStateError);
    expect(() => AppEnvironment.resolve('debug'), throwsStateError);
    expect(() => AppEnvironment.resolve('release'), throwsStateError);
  });

  test('Prod preserves the existing Android Firebase configuration', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(AppEnvironment.prod.firebaseOptions, DefaultFirebaseOptions.android);
  });
}
