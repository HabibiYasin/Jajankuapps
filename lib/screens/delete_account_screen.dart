import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/account_data_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  final User user;
  const DeleteAccountScreen({super.key, required this.user});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _confirmed = false, _busy = false;
  String? _error;
  bool get _google =>
      widget.user.providerData.any((p) => p.providerId == 'google.com');
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_confirmed) return;
    if (!_google && _password.text.isEmpty) {
      setState(() => _error = 'Masukkan password akun terlebih dahulu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AccountDataService.instance.beforeSignOut();
      await AuthService.instance.deleteAccount(
        widget.user.uid,
        password: _password.text,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_name_${widget.user.uid}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun dan data cloud berhasil dihapus.')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Penghapusan belum selesai. Periksa internet dan verifikasi akun, lalu coba lagi. Sebagian data mungkin sudah terhapus.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Hapus akun')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Akun, profil, transaksi, pengaturan budget, dan riwayat import di cloud akan dihapus permanen. Data Guest di HP ini tetap ada. Penghapusan memerlukan internet.',
          ),
          const SizedBox(height: 20),
          if (_google)
            const Text('Verifikasi akun Google yang sama sebelum menghapus.')
          else
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Password akun'),
            ),
          CheckboxListTile(
            value: _confirmed,
            onChanged: _busy
                ? null
                : (value) => setState(() => _confirmed = value ?? false),
            title: const Text('Saya memahami penghapusan ini permanen.'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _busy || !_confirmed ? null : _delete,
            child: Text(_busy ? 'Menghapus...' : 'Hapus akun dan data'),
          ),
        ],
      ),
    ),
  );
}
