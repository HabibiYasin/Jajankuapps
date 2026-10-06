import 'account_deletion_service.dart';

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
  Stream<User?> get authStateChanges => FirebaseAuth.instance.userChanges();

  static bool needsEmailVerification(User? user) =>
      user != null &&
      !user.emailVerified &&
      user.providerData.any((p) => p.providerId == 'password') &&
      !user.providerData.any((p) => p.providerId == 'google.com');

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
    if (needsEmailVerification(user)) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    String? savedName;
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      savedName = snapshot.data()?['displayName'] as String?;
      transaction.set(ref, {
        'email': user.email ?? '',
        'displayName': savedName ?? user.displayName ?? '',
        'providers': user.providerData.map((p) => p.providerId).toList(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'plan': 'free',
      }, SetOptions(merge: true));
    });
    if (savedName != null &&
        user.displayName != savedName &&
        currentUser?.uid == user.uid) {
      await user.updateDisplayName(savedName);
    }
  }

  Future<void> updateDisplayName(String uid, String name) async {
    final user = currentUser;
    if (user == null || user.uid != uid) throw StateError('Akun berubah.');
    await user.updateDisplayName(name.trim());
    if (currentUser?.uid != uid) throw StateError('Akun berubah.');
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'displayName': name.trim(),
      'lastLoginAt': FieldValue.serverTimestamp(),
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
    await result.user!.sendEmailVerification();
  }

  Future<void> changePassword({
    required String newPassword,
    String? oldPassword,
  }) async {
    final user = currentUser;
    if (user == null || user.email == null) {
      throw StateError('Login terlebih dahulu.');
    }
    await _reauthenticate(user, oldPassword);
    if (!user.providerData.any(
      (provider) => provider.providerId == 'password',
    )) {
      await user.linkWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: newPassword),
      );
    } else {
      await user.updatePassword(newPassword);
    }
    await user.reload();
  }

  Future<void> _reauthenticate(User user, String? oldPassword) async {
    final google = user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
    if (google) {
      if (!_googleInitialized) {
        await _googleSignIn.initialize();
        _googleInitialized = true;
      }
      final account = await _googleSignIn.authenticate();
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: account.authentication.idToken),
      );
    } else {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: oldPassword ?? '',
        ),
      );
    }
    if (currentUser?.uid != user.uid) {
      throw StateError('Akun berubah. Silakan coba lagi.');
    }
  }

  Future<void> deleteAccount(String uid, {String? password}) async {
    final user = currentUser;
    if (user == null || user.uid != uid) throw StateError('Akun berubah.');
    await _reauthenticate(user, password);
    await deleteAccountData(
      FirebaseFirestore.instance,
      uid,
      checkOwner: () {
        if (currentUser?.uid != uid) throw StateError('Akun berubah.');
      },
    );
    await user.delete();
    if (_googleInitialized) await _googleSignIn.signOut();
  }

  Future<void> resetPassword(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() async {
    if (!isConfigured) return;
    await FirebaseAuth.instance.signOut();
    if (_googleInitialized) await _googleSignIn.signOut();
  }
}
