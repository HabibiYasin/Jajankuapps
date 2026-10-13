import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/premium_status.dart';

class ProfilePlanStore {
  ProfilePlanStore(this.firestore);

  final FirebaseFirestore firestore;

  // Re-emit at expiry even when Firestore has not received an update yet.
  Stream<PremiumStatus> watch(String uid) {
    late StreamController<PremiumStatus> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;
    Timer? expiry;
    controller = StreamController<PremiumStatus>(
      onListen: () {
        subscription = firestore
            .collection('users')
            .doc(uid)
            .snapshots()
            .listen((snapshot) {
              expiry?.cancel();
              final status = PremiumStatus.fromMap(snapshot.data());
              controller.add(status);
              if (status.isActive && !status.isLifetime) {
                expiry = Timer(status.endedAt!.difference(DateTime.now()), () {
                  controller.add(status);
                });
              }
            }, onError: controller.addError);
      },
      onCancel: () async {
        expiry?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  Stream<bool> watchVip(String uid) =>
      watch(uid).map((status) => status.isActive).distinct();
}
