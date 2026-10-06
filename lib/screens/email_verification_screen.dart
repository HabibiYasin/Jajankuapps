import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final bool popOnVerified;
  const EmailVerificationScreen({super.key, this.popOnVerified = false});
  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _busy = false;
  String? _message;
  int _cooldown = 0;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _run({bool resend = false}) async {
    setState(() => _busy = true);
    try {
      final auth = AuthService.instance;
      final user = auth.currentUser;
      if (user == null) {
        if (mounted && widget.popOnVerified) Navigator.pop(context, false);
        return;
      }
      if (resend) {
        await user.sendEmailVerification();
        if (!mounted) return;
        setState(() {
          _message = 'Email verifikasi dikirim. Cek juga folder spam.';
          _cooldown = 60;
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() => _cooldown--);
          if (_cooldown <= 0) timer.cancel();
        });
      } else {
        await user.reload();
        final refreshed = auth.currentUser;
        if (refreshed == null || refreshed.uid != user.uid) return;
        if (refreshed.emailVerified) {
          await refreshed.getIdToken(true);
          await auth.syncProfile(refreshed);
          if (mounted && widget.popOnVerified) Navigator.pop(context, true);
        } else if (mounted) {
          setState(
            () => _message = 'Email belum terverifikasi. Klik tautan di email terlebih dahulu.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Proses belum berhasil. Periksa internet atau coba lagi nanti.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verifikasi email')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 64),
            const SizedBox(height: 20),
            Text(
              'Verifikasi ${AuthService.instance.currentUser?.email ?? 'email kamu'}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Klik tautan verifikasi di email sebelum menggunakan akun. Setelah itu, tekan tombol di bawah.',
              textAlign: TextAlign.center,
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_message!, textAlign: TextAlign.center),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : () => _run(),
              child: Text(_busy ? 'Memproses...' : 'Saya sudah verifikasi'),
            ),
            TextButton(
              onPressed: _busy || _cooldown > 0
                  ? null
                  : () => _run(resend: true),
              child: Text(
                _cooldown > 0
                    ? 'Kirim ulang dalam $_cooldown detik'
                    : 'Kirim ulang email verifikasi',
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await AuthService.instance.signOut();
                      if (context.mounted && widget.popOnVerified) {
                        Navigator.pop(context, false);
                      }
                    },
              child: const Text('Keluar / gunakan akun lain'),
            ),
          ],
        ),
      ),
    ),
  );
}
