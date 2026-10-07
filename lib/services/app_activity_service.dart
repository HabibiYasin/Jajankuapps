import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First observed app launch, not the operating system's installation time.
class AppActivityService {
  static const installedKey = 'app_first_opened_at';
  static const openedKey = 'app_last_opened_at';

  static Future<DateTime> recordLocalOpen(
    SharedPreferences preferences, {
    DateTime? now,
  }) async {
    final opened = (now ?? DateTime.now()).toUtc();
    final saved = DateTime.tryParse(preferences.getString(installedKey) ?? '');
    final installed = saved ?? opened;
    if (saved == null) {
      await preferences.setString(installedKey, installed.toIso8601String());
    }
    await preferences.setString(openedKey, opened.toIso8601String());
    return installed;
  }

  static Future<Map<String, dynamic>> profileFields(
    Map<String, dynamic>? existing,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final installed = await recordLocalOpen(preferences);
    return {
      if (existing?['installedAt'] == null)
        'installedAt': Timestamp.fromDate(installed),
      'lastOpenedAt': FieldValue.serverTimestamp(),
      if (existing == null || !existing.containsKey('deletedAt'))
        'deletedAt': null,
    };
  }

  static Future<void> recordCloudOpen(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    await firestore.collection('users').doc(uid).update({
      'lastOpenedAt': FieldValue.serverTimestamp(),
    });
    await recordInstallation(firestore, uid);
  }

  static Future<void> recordInstallation(
    FirebaseFirestore firestore,
    String uid,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final installed = await recordLocalOpen(preferences);
    var id = preferences.getString('app_installation_id');
    if (id == null) {
      final random = Random.secure();
      id = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await preferences.setString('app_installation_id', id);
    }
    final ref = firestore
        .collection('users')
        .doc(uid)
        .collection('installations')
        .doc(id);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.exists) {
        transaction.update(ref, {'lastOpenedAt': FieldValue.serverTimestamp()});
      } else {
        transaction.set(ref, {
          'installedAt': Timestamp.fromDate(installed),
          'deletedAt': null,
          'lastOpenedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
