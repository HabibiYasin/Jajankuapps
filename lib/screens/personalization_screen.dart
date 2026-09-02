import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tutorial_dialog.dart';
import 'budget_settings_screen.dart';

class PersonalizationScreen extends StatefulWidget {
  final String userName;
  final String userRole;
  final double dailyLimit;
  final double weeklyLimit;
  final double monthlyLimit;

  const PersonalizationScreen({
    super.key,
    required this.userName,
    required this.userRole,
    required this.dailyLimit,
    required this.weeklyLimit,
    required this.monthlyLimit,
  });

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login Google gagal: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _loading = true);
    try {
      await AuthService.instance.signOut();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _profile(User? user) {
    final photoUrl = user?.photoURL;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.charcoal, AppColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.aqua,
          backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
          child: photoUrl == null
              ? const Icon(
                  Icons.person_rounded,
                  color: AppColors.charcoal,
                  size: 32,
                )
              : null,
        ),
        title: Text(
          user?.displayName ?? widget.userName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          user?.email ?? widget.userRole,
          style: const TextStyle(color: AppColors.mist),
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: AppColors.aqua.withValues(alpha: 0.25),
          child: Icon(icon, color: AppColors.teal),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final profile = auth.isConfigured
        ? StreamBuilder<User?>(
            stream: auth.authStateChanges,
            initialData: auth.currentUser,
            builder: (_, snapshot) => _profile(snapshot.data),
          )
        : _profile(null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          profile,
          const SizedBox(height: 24),
          Text('Personalisasi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _menuTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Limit Budget',
            subtitle: 'Atur batas harian, mingguan, dan bulanan',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BudgetSettingsScreen(
                  dailyLimit: widget.dailyLimit,
                  weeklyLimit: widget.weeklyLimit,
                  monthlyLimit: widget.monthlyLimit,
                ),
              ),
            ),
          ),
          _menuTile(
            icon: Icons.help_outline,
            title: 'Cara Pakai',
            subtitle: 'Lihat panduan penggunaan aplikasi',
            onTap: () => showTutorialDialog(context),
          ),
          const SizedBox(height: 12),
          Text('Akun', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (!auth.isConfigured)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Firebase belum dikonfigurasi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Jalankan flutterfire configure untuk mengaktifkan Login Google.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _signIn,
                      icon: const Icon(Icons.login),
                      label: const Text('Coba Login Google'),
                    ),
                  ],
                ),
              ),
            )
          else
            StreamBuilder<User?>(
              stream: auth.authStateChanges,
              initialData: auth.currentUser,
              builder: (_, snapshot) {
                final loggedIn = snapshot.data != null;
                return ElevatedButton.icon(
                  onPressed: _loading ? null : (loggedIn ? _signOut : _signIn),
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(loggedIn ? Icons.logout : Icons.login),
                  label: Text(
                    loggedIn ? 'Keluar dari akun' : 'Masuk dengan Google',
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
