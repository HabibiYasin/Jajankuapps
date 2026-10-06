import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final User user;
  const ChangePasswordScreen({super.key, required this.user});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  String? _error;
  bool get _google =>
      widget.user.providerData.any((p) => p.providerId == 'google.com');

  @override
  void dispose() {
    _old.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (AuthService.instance.currentUser?.uid != widget.user.uid) {
        throw StateError('Akun berubah. Buka kembali pengaturan akun.');
      }
      await AuthService.instance.changePassword(
        newPassword: _password.text,
        oldPassword: _old.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password Jajanku berhasil disimpan.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is FirebaseAuthException
            ? switch (error.code) {
                'wrong-password' || 'invalid-credential' =>
                  'Password lama salah atau verifikasi gagal.',
                'user-mismatch' =>
                  'Pilih akun Google yang sama dengan akun Jajanku ini.',
                'weak-password' => 'Password belum memenuhi persyaratan keamanan. Gunakan password yang lebih kuat.',
                'network-request-failed' =>
                  'Periksa koneksi internet, lalu coba lagi.',
                'too-many-requests' =>
                  'Terlalu banyak percobaan. Coba lagi nanti.',
                'requires-recent-login' =>
                  'Silakan login kembali, lalu ulangi perubahan password.',
                _ => 'Password gagal disimpan. Silakan coba lagi.',
              }
            : error is StateError
            ? error.message.toString()
            : 'Verifikasi belum selesai. Silakan coba lagi.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ganti password')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _google
                ? 'Verifikasi lewat Google tanpa password lama. Password ini untuk login email di Jajanku; password akun Google tetap sama.'
                : 'Masukkan password lama dan password baru untuk akun Jajanku.',
          ),
          const SizedBox(height: 24),
          if (!_google) ...[
            TextFormField(
              controller: _old,
              obscureText: true,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Password lama'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Masukkan password lama.' : null,
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _password,
            obscureText: true,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Password baru'),
            validator: (v) => v == null || v.length < 6
                ? 'Gunakan minimal 6 karakter.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmation,
            obscureText: true,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Ulangi password baru',
            ),
            validator: (v) =>
                v != _password.text ? 'Password tidak sama.' : null,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? 'Menyimpan...'
                  : _google
                  ? 'Verifikasi Google dan simpan'
                  : 'Simpan password',
            ),
          ),
        ],
      ),
    ),
  );
}
