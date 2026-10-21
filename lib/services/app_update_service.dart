import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdatePolicy {
  const AppUpdatePolicy({
    required this.enabled,
    required this.minimumBuildNumber,
  });
  final bool enabled;
  final int minimumBuildNumber;

  factory AppUpdatePolicy.fromMap(Map<String, dynamic> data) {
    final enabled = data['enabled'];
    final minimum = data['minimumBuildNumber'];
    if (enabled is! bool || minimum is! int || minimum < 1) {
      throw const FormatException('Invalid update policy');
    }
    return AppUpdatePolicy(enabled: enabled, minimumBuildNumber: minimum);
  }

  bool requiresUpdate(int build) => enabled && build < minimumBuildNumber;
  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'minimumBuildNumber': minimumBuildNumber,
  };
}

class AppUpdateService {
  AppUpdateService({
    required this.preferences,
    required this.packageName,
    required this.buildNumber,
    required this.fetchPolicy,
  });
  final SharedPreferences preferences;
  final String packageName;
  final int buildNumber;
  final Future<Map<String, dynamic>?> Function() fetchPolicy;
  String get _cacheKey => 'app_update_policy_$packageName';

  /// Missing documents disable enforcement; failures preserve the last valid policy.
  Future<AppUpdatePolicy?> check() async {
    AppUpdatePolicy? policy;
    try {
      final cached = preferences.getString(_cacheKey);
      if (cached != null) {
        policy = AppUpdatePolicy.fromMap(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Ignore a malformed local cache.
    }
    try {
      final data = await fetchPolicy().timeout(const Duration(seconds: 6));
      final fresh = data == null ? null : AppUpdatePolicy.fromMap(data);
      policy = fresh;
      if (fresh == null) {
        await preferences.remove(_cacheKey);
      } else {
        await preferences.setString(_cacheKey, jsonEncode(fresh.toMap()));
      }
    } catch (_) {
      // Offline, denied reads, and invalid remote settings retain the cached rule.
    }
    return policy != null && policy.requiresUpdate(buildNumber) ? policy : null;
  }

  static Future<AppUpdatePolicy?> checkCurrent(
    SharedPreferences preferences,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final info = await PackageInfo.fromPlatform().timeout(
        const Duration(seconds: 3),
      );
      final build = int.tryParse(info.buildNumber);
      if (build == null ||
          build < 1 ||
          ![
            'com.jajanku.app',
            'com.jajanku.app.dev',
          ].contains(info.packageName)) {
        return null;
      }
      return await AppUpdateService(
        preferences: preferences,
        packageName: info.packageName,
        buildNumber: build,
        fetchPolicy: () async {
          if (Firebase.apps.isEmpty) throw StateError('Firebase unavailable');
          final document = await FirebaseFirestore.instance
              .doc('app_config/android_update')
              .get(const GetOptions(source: Source.server));
          return document.data();
        },
      ).check();
    } catch (_) {
      return null;
    }
  }
}
