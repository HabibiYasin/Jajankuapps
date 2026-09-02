import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    await FirebaseAuth.instance.signOut();
    if (_googleInitialized) await _googleSignIn.signOut();
  }
}
