import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/profile_avatar_store.dart';
import '../services/account_data_service.dart';
import '../services/budget_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tutorial_dialog.dart';
import 'budget_settings_screen.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'delete_account_screen.dart';
import 'privacy_policy_screen.dart';
import 'notification_settings_screen.dart';

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
  int _avatarCode = 1;
  StreamSubscription<int>? _avatarSubscription;
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
    _avatarSubscription?.cancel();
    super.dispose();
  }

  String _nameKey(String? uid) =>
      uid == null ? 'guest_profile_name' : 'profile_name_$uid';

  Future<void> _loadSavedName(User? user) async {
    final generation = ++_nameGeneration;
    _avatarSubscription?.cancel();
    _avatarSubscription = null;
    if (user != null) {
      _avatarSubscription = ProfileAvatarStore(FirebaseFirestore.instance)
          .watch(user.uid)
          .listen(
            (code) {
              if (mounted &&
                  AuthService.instance.currentUser?.uid == user.uid) {
                setState(() => _avatarCode = code);
              }
            },
            onError: (Object error) {
              debugPrint('Gagal memuat foto profil: $error');
            },
          );
    }
    if (mounted) {
      setState(() {
        _savedName = null;
        _avatarCode = 1;
      });
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(_nameKey(user?.uid));
      if (mounted &&
          generation == _nameGeneration &&
          AuthService.instance.currentUser?.uid == user?.uid) {
        setState(() {
          _savedName = user?.displayName ?? savedName;
          if (user == null) {
            _avatarCode = ProfileAvatarStore.normalize(
              prefs.getInt('guest_avatar_code'),
            );
          }
        });
      }
    } catch (error) {
      debugPrint('Gagal memuat nama: $error');
    }
  }

  Future<void> _accountSettings(User? user) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Pengaturan akun',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit nama'),
              onTap: () => Navigator.pop(sheetContext, 'name'),
            ),
            ListTile(
              leading: const Icon(Icons.face_rounded),
              title: const Text('Ganti foto profil'),
              onTap: () => Navigator.pop(sheetContext, 'avatar'),
            ),
            if (user != null)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: const Text('Hapus akun'),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            if (user != null)
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Ganti password'),
                onTap: () => Navigator.pop(sheetContext, 'password'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || AuthService.instance.currentUser?.uid != user?.uid) return;
    if (action == 'name') await _editName(user);
    if (action == 'avatar') await _editAvatar(user);
    if (action == 'delete' && user != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DeleteAccountScreen(user: user),
        ),
      );
    }
    if (action == 'password' && user != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChangePasswordScreen(user: user),
        ),
      );
    }
  }

  Future<void> _editAvatar(User? user) async {
    var selected = _avatarCode;
    final code = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Pilih foto profil'),
          content: SizedBox(
            width: 320,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (_, index) {
                final avatar = index + 1;
                return Semantics(
                  selected: selected == avatar,
                  button: true,
                  child: InkWell(
                    onTap: () => updateDialog(() => selected = avatar),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected == avatar
                              ? AppColors.teal
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipOval(
                              child: Image.asset(
                                ProfileAvatarStore.asset(avatar),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ProfileAvatarStore.labels[index],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (code == null ||
        !mounted ||
        AuthService.instance.currentUser?.uid != user?.uid) {
      return;
    }
    setState(() => _loading = true);
    try {
      if (user != null) {
        await AuthService.instance.updateAvatar(user.uid, code);
      } else {
        final prefs = await SharedPreferences.getInstance();
        if (AuthService.instance.currentUser != null) return;
        if (!await prefs.setInt('guest_avatar_code', code)) {
          throw StateError('Penyimpanan foto profil gagal.');
        }
      }
      if (!mounted || AuthService.instance.currentUser?.uid != user?.uid) {
        return;
      }
      setState(() => _avatarCode = code);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil disimpan')),
      );
    } catch (error) {
      if (!mounted || AuthService.instance.currentUser?.uid != user?.uid) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Foto profil gagal disimpan. Periksa internet dan coba lagi.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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

    setState(() => _loading = true);
    try {
      if (user != null) {
        await AuthService.instance.updateDisplayName(user.uid, newName);
      }
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
        const SnackBar(
          content: Text('Nama gagal disimpan. Periksa internet dan coba lagi.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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
        leading: Semantics(
          label: 'Foto profil ${ProfileAvatarStore.labels[_avatarCode - 1]}',
          child: CircleAvatar(
            radius: 30,
            backgroundImage: AssetImage(ProfileAvatarStore.asset(_avatarCode)),
          ),
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
          tooltip: 'Pengaturan akun',
          onPressed: _loading ? null : () => _accountSettings(user),
          icon: const Icon(Icons.edit_rounded, color: Colors.white),
        ),
        onTap: _loading ? null : () => _accountSettings(user),
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
            subtitle: 'Atur kategori dan batas harian, mingguan, bulanan',
            onTap: () async {
              final limits = AccountDataService.instance.limits;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BudgetSettingsScreen(
                    dailyLimit: limits.daily,
                    weeklyLimit: limits.weekly,
                    monthlyLimit: limits.monthly,
                    categories: limits.trackedCategories,
                  ),
                ),
              );
            },
          ),
          _menuTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Kebijakan Privasi',
            subtitle: 'Cara Jajanku menggunakan dan menyimpan data',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyPolicyScreen(),
              ),
            ),
          ),
          _menuTile(
            icon: Icons.help_outline,
            title: 'Cara Pakai',
            subtitle: 'Lihat panduan penggunaan aplikasi',
            onTap: () => showTutorialDialog(context),
          ),
          if (BudgetNotificationService.isSupported)
            _menuTile(
              icon: Icons.notifications_outlined,
              title: 'Notifikasi',
              subtitle: 'Atur notifikasi persistent dan pengingat jam 12 siang',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              ),
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
