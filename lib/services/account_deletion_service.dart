import 'package:cloud_firestore/cloud_firestore.dart';

/// Delete every owned document before deleting Authentication, so interrupted
/// operations can be retried with the same account.
Future<void> deleteAccountData(
  FirebaseFirestore firestore,
  String uid, {
  required void Function() checkOwner,
}) async {
  final user = firestore.collection('users').doc(uid);
  for (final collection in ['transactions', 'settings', 'imports']) {
    while (true) {
      checkOwner();
      final snapshot = await user
          .collection(collection)
          .limit(450)
          .get(const GetOptions(source: Source.server));
      if (snapshot.docs.isEmpty) break;
      checkOwner();
      final batch = firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }
  checkOwner();
  await user.delete();
}
