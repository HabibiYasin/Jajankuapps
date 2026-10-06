import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/account_data_service.dart';
import 'email_verification_screen.dart';

Future<bool> requireLogin(BuildContext context) async {
  if (AuthService.instance.currentUser == null) {
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return false;
    final result = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (result != true || !context.mounted) return false;
  }
  final user = AuthService.instance.currentUser;
  if (user == null || AuthService.needsEmailVerification(user)) return false;
  final data = AccountDataService.instance;
  if (data.uid != user.uid) await data.switchAccount(user.uid);
  return context.mounted && AuthService.instance.currentUser?.uid == user.uid;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _loading = false;
  bool _register = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')) {
      return 'Masukkan email yang valid.';
    }
    return null;
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action, {bool login = true}) async {
    setState(() => _loading = true);
    try {
      await action();
      if (!mounted) return;
      if (login && AuthService.instance.currentUser != null) {
        if (AuthService.needsEmailVerification(
          AuthService.instance.currentUser,
        )) {
          final verified = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const EmailVerificationScreen(popOnVerified: true),
            ),
          );
          if (!mounted || verified != true) return;
        }
        if (mounted) Navigator.of(context).pop(true);
      } else if (!login) {
        _message(
          'Permintaan reset diterima. Jika email terdaftar, tautan akan dikirim. Cek kotak masuk dan spam.',
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _message(switch (error.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          login
              ? 'Email atau password salah.'
              : 'Email belum terdaftar. Silakan daftar terlebih dahulu.',
        'email-already-in-use' =>
          'Email sudah terdaftar. Silakan masuk atau reset password.',
        'weak-password' =>
          'Password terlalu lemah. Gunakan password yang lebih kuat.',
        'invalid-email' => 'Format email tidak valid.',
        'operation-not-allowed' =>
          'Login email/password belum diaktifkan di Firebase.',
        'too-many-requests' => 'Terlalu banyak percobaan. Coba lagi nanti.',
        'network-request-failed' => 'Periksa koneksi internet kamu.',
        'user-disabled' => 'Akun ini dinonaktifkan.',
        _ => 'Proses akun gagal. Silakan coba lagi.',
      });
    } catch (_) {
      if (!mounted) return;
      _message(
        'Proses akun gagal. Periksa koneksi dan pengaturan Firebase, lalu coba lagi.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _run(() async {
      final auth = AuthService.instance;
      // Retry profile creation if Authentication succeeded but Firestore failed.
      final user = auth.currentUser;
      if (user != null && user.email == _email.text.trim()) {
        await auth.syncProfile(user);
      } else if (_register) {
        await auth.registerWithEmail(_email.text, _password.text);
      } else {
        await auth.signInWithEmail(_email.text, _password.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_register ? 'Daftar akun' : 'Login')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Kamu harus login dulu sebelum catat',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Masuk atau daftar untuk menyimpan pengeluaran dan anggaran di akun kamu.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _email,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: !_loading,
                  obscureText: _hidePassword,
                  autofillHints: [
                    _register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? 'Tampilkan password'
                          : 'Sembunyikan password',
                      onPressed: _loading
                          ? null
                          : () =>
                                setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Masukkan password.';
                    }
                    if (_register && value.length < 6) {
                      return 'Password minimal 6 karakter.';
                    }
                    return null;
                  },
                ),
                if (_register) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmation,
                    enabled: !_loading,
                    obscureText: _hidePassword,
                    decoration: const InputDecoration(
                      labelText: 'Ulangi password',
                    ),
                    validator: (value) =>
                        value != _password.text ? 'Password tidak sama.' : null,
                  ),
                ],
                if (!_register)
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            final error = _validateEmail(_email.text);
                            if (error != null) {
                              _message(error);
                              return;
                            }
                            _run(
                              () => AuthService.instance.resetPassword(
                                _email.text,
                              ),
                              login: false,
                            );
                          },
                    child: const Text('Lupa password?'),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(
                    _loading
                        ? 'Sedang memproses...'
                        : _register
                        ? 'Daftar'
                        : 'Masuk',
                  ),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                          _register = !_register;
                          _confirmation.clear();
                          _form.currentState?.reset();
                        }),
                  child: Text(
                    _register
                        ? 'Sudah punya akun? Masuk'
                        : 'Belum punya akun? Daftar',
                  ),
                ),
                const Divider(),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _run(() async {
                          await AuthService.instance.signInWithGoogle();
                        }),
                  icon: Image.asset(
                    'assets/icon/google_logo.png',
                    width: 20,
                    height: 20,
                    excludeFromSemantics: true,
                  ),
                  label: const Text('Masuk dengan Google'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
