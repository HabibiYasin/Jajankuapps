import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/transaction_model.dart';

class CloudAccountStore {
  final FirebaseFirestore firestore;
  CloudAccountStore(this.firestore);

  CollectionReference<Map<String, dynamic>> transactions(String uid) =>
      firestore.collection('users').doc(uid).collection('transactions');

  DocumentReference<Map<String, dynamic>> budget(String uid) =>
      firestore.doc('users/$uid/settings/budget');

  static Map<String, dynamic> encode(TransactionModel tx) => {
    'type': tx.type,
    'merchant': tx.merchant,
    'nominalStr': tx.nominalStr,
    'dateTime': Timestamp.fromDate(tx.dateTime),
    'category': tx.category,
    'source': tx.source,
    'paymentMethod': tx.paymentMethod,
    'numericNominal': tx.numericNominal,
  };

  static TransactionModel decode(
    String uid,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = doc.data();
    return TransactionModel(
      cloudId: doc.id,
      type: (map['type'] as String?) ?? 'expense',
      ownerUid: uid,
      merchant: map['merchant'] as String,
      nominalStr: map['nominalStr'] as String,
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      category: map['category'] as String,
      source: map['source'] as String,
      paymentMethod: (map['paymentMethod'] as String?) ?? 'QRIS',
      numericNominal: (map['numericNominal'] as num).toDouble(),
    );
  }

  // The marker prevents a retry from overwriting edits or resurrecting a
  // transaction deleted on another device after a successful import.
  Future<void> importOnce(String uid, String id, TransactionModel tx) async {
    final marker = firestore.doc('users/$uid/imports/$id');
    await firestore.runTransaction((batch) async {
      if ((await batch.get(marker)).exists) return;
      batch.set(transactions(uid).doc(id), encode(tx));
      batch.set(marker, {'completed': true});
    });
  }
}
