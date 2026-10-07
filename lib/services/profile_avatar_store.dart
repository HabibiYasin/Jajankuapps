import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileAvatarStore {
  ProfileAvatarStore(this.firestore);

  final FirebaseFirestore firestore;
  static const labels = [
    'Es Teh',
    'Es Doger',
    'Seblak',
    'Boba',
    'Bakso',
    'Cilok',
  ];

  static bool isValid(Object? code) => code is int && code >= 1 && code <= 6;
  static int normalize(Object? code) => isValid(code) ? code as int : 1;
  static String asset(Object? code) => 'assets/avatars/${normalize(code)}.png';

  Stream<int> watch(String uid) => firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snapshot) => normalize(snapshot.data()?['avatarCode']));

  Future<void> save(String uid, int code) async {
    if (!isValid(code)) throw ArgumentError.value(code, 'code');
    await firestore.collection('users').doc(uid).update({'avatarCode': code});
  }
}
