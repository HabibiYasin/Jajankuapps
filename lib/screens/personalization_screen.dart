import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/account_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tutorial_dialog.dart';
import 'budget_settings_screen.dart';
import 'login_screen.dart';

enum UserTier {
  guest('Jajaners CobaCoba'),
  free('Jajaners Gratisan'),
  premium('Jajaners VIP');

  const UserTier(this.label);

  final String label;
}

class PersonalizationScreen extends StatefulWidget {
  final String userName;
  final double dailyLimit;
  final double weeklyLimit;
  final double monthlyLimit;
  final UserTier loggedInTier;

  const PersonalizationScreen({
    super.key,
    required this.userName,
    required this.dailyLimit,
    required this.weeklyLimit,
    required this.monthlyLimit,
    this.loggedInTier = UserTier.free,
  });

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  bool _loading = false;
  String? _savedName;
  int _nameGeneration = 0;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    final auth = AuthService.instance;
    _loadSavedName(auth.currentUser);
    if (auth.isConfigured) {
      _authSubscription = auth.authStateChanges.listen(_loadSavedName);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  String _nameKey(String? uid) =>
      uid == null ? 'guest_profile_name' : 'profile_name_$uid';

  Future<void> _loadSavedName(User? user) async {
    final generation = ++_nameGeneration;
    if (mounted) setState(() => _savedName = null);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(_nameKey(user?.uid));
      if (mounted &&
          generation == _nameGeneration &&
          AuthService.instance.currentUser?.uid == user?.uid) {
        setState(() => _savedName = savedName);
      }
    } catch (error) {
      debugPrint('Gagal memuat nama: $error');
    }
  }

  Future<void> _editName(User? user) async {
    final formKey = GlobalKey<FormState>();
    var nameInput = _savedName ?? user?.displayName ?? widget.userName;
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit nama'),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: nameInput,
            onChanged: (value) => nameInput = value,
            autofocus: true,
            maxLength: 50,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama',
              hintText: 'Masukkan nama yang ingin ditampilkan',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nama tidak boleh kosong.'
                : null,
            onFieldSubmitted: (value) {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, value.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, nameInput.trim());
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (newName == null || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || AuthService.instance.currentUser?.uid != user?.uid) {
        return;
      }
      final saved = await prefs.setString(_nameKey(user?.uid), newName);
      if (!saved) throw StateError('Penyimpanan nama gagal.');
      if (!mounted || AuthService.instance.currentUser?.uid != user?.uid) {
        return;
      }
      ++_nameGeneration;
      setState(() => _savedName = newName);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nama berhasil disimpan')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama gagal disimpan. Coba lagi.')),
      );
    }
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await Navigator.of(context)
          .push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen()));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Halaman login gagal dibuka.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _loading = true);
    try {
      await AccountDataService.instance.beforeSignOut();
      await AuthService.instance.signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Belum bisa keluar: $error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importLocal() async {
    final data = AccountDataService.instance;
    final owner = data.uid;
    if (owner == null) return;
    setState(() => _loading = true);
    try {
      final count = await data.importCount();
      if (!mounted || data.uid != owner) return;
      if (count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada transaksi lokal untuk dipindahkan.'),
          ),
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pindahkan transaksi lokal?'),
          content: Text(
            '$count transaksi dari HP ini akan dipindahkan ke akun '
            '${AuthService.instance.currentUser?.email ?? ''}. '
            'Setelah tersimpan di cloud, transaksi tersebut tidak lagi tampil di Guest. '
            'Pemindahan memerlukan internet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pindahkan'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final moved = await data.importGuest(owner);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$moved transaksi berhasil dipindahkan ke cloud.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pemindahan belum selesai. Periksa internet dan coba lagi dengan akun yang sama.',
            ),
          ),
        );
      }
      debugPrint('Import transaksi: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _syncCard() => ListenableBuilder(
    listenable: AccountDataService.instance,
    builder: (context, _) {
      final data = AccountDataService.instance;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    data.uid == null
                        ? Icons.phone_android
                        : Icons.cloud_outlined,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(data.status)),
                ],
              ),
              if (data.error != null)
                TextButton(
                  onPressed: () => data.retry(),
                  child: const Text('Coba sinkronkan lagi'),
                ),
              if (data.uid != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loading || data.importing ? null : _importLocal,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    data.importing
                        ? 'Memindahkan…'
                        : 'Pindahkan transaksi dari HP ini',
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Widget _profile(User? user) {
    final photoUrl = user?.photoURL;
    final tier = user == null ? UserTier.guest : widget.loggedInTier;
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
          _savedName ?? user?.displayName ?? widget.userName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          tier.label,
          style: const TextStyle(color: AppColors.mist),
        ),
        trailing: IconButton(
          tooltip: 'Edit nama',
          onPressed: _loading ? null : () => _editName(user),
          icon: const Icon(Icons.edit_rounded, color: Colors.white),
        ),
        onTap: _loading ? null : () => _editName(user),
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
            onTap: () async {
              if (!await requireLogin(context) || !context.mounted) return;
              final limits = AccountDataService.instance.limits;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BudgetSettingsScreen(
                    dailyLimit: limits.daily,
                    weeklyLimit: limits.weekly,
                    monthlyLimit: limits.monthly,
                  ),
                ),
              );
            },
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
          _syncCard(),
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
                      'Login belum tersedia. Silakan coba lagi nanti.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _signIn,
                      icon: const Icon(Icons.login),
                      label: const Text('Login'),
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
                  label: Text(loggedIn ? 'Keluar dari akun' : 'Login'),
                );
              },
            ),
        ],
      ),
    );
  }
}
