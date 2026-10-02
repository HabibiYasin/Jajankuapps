import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  AuthService._();

  static final instance = AuthService._();
  final _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  bool get isConfigured => Firebase.apps.isNotEmpty;
  User? get currentUser =>
      isConfigured ? FirebaseAuth.instance.currentUser : null;
  Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();

  Future<UserCredential> signInWithGoogle() async {
    if (!isConfigured) {
      throw StateError(
        'Firebase belum dikonfigurasi. Jalankan flutterfire configure terlebih dahulu.',
      );
    }
    if (!_googleInitialized) {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    }
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    await syncProfile(result.user!);
    return result;
  }

  Future<void> syncProfile(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      transaction.set(ref, {
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'providers': user.providerData.map((p) => p.providerId).toList(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'plan': 'free',
      }, SetOptions(merge: true));
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await syncProfile(result.user!);
  }

  Future<void> registerWithEmail(String email, String password) async {
    final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await syncProfile(result.user!);
  }

  Future<void> resetPassword(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() async {
    if (!isConfigured) return;
    await FirebaseAuth.instance.signOut();
    if (_googleInitialized) await _googleSignIn.signOut();
  }
}
