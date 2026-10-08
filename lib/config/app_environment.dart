import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show appFlavor;

import '../firebase_options.dart' as prod_config;
import '../firebase_options_dev.dart' as dev_config;

enum AppEnvironment {
  dev,
  prod;

  static AppEnvironment resolve(String? flavor) => switch (flavor) {
    'dev' => AppEnvironment.dev,
    'prod' => AppEnvironment.prod,
    _ => throw StateError(
      'Pilih flavor dev atau prod saat menjalankan aplikasi.',
    ),
  };

  static AppEnvironment get current => resolve(appFlavor);

  FirebaseOptions get firebaseOptions {
    if (this == AppEnvironment.prod) {
      return prod_config.DefaultFirebaseOptions.currentPlatform;
    }
    final options = dev_config.DefaultFirebaseOptions.currentPlatform;
    if (options.projectId ==
        prod_config.DefaultFirebaseOptions.currentPlatform.projectId) {
      throw StateError(
        'Firebase dev harus menggunakan project berbeda dari prod.',
      );
    }
    return options;
  }
}
