import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePlanStore {
  ProfilePlanStore(this.firestore);

  final FirebaseFirestore firestore;

  Stream<bool> watchVip(String uid) => firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snapshot) => snapshot.data()?['plan'] == 'premium');
}
