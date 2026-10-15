import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/premium_status.dart';
import '../services/auth_service.dart';
import '../services/premium_billing_service.dart';
import '../services/profile_plan_store.dart';
import '../widgets/premium_access_details.dart';
import '../widgets/premium_voucher_field.dart';
import 'login_screen.dart';

class UpgradeAccountScreen extends StatefulWidget {
  const UpgradeAccountScreen({super.key});

  @override
  State<UpgradeAccountScreen> createState() => _UpgradeAccountScreenState();
}

class _UpgradeAccountScreenState extends State<UpgradeAccountScreen>
    with WidgetsBindingObserver {
  final _billing = PremiumBillingService.instance;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<PremiumStatus>? _profileSubscription;
  PremiumStatus? _status;
  String? _uid;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _billing.start();
    if (AuthService.instance.isConfigured) {
      _authSubscription = AuthService.instance.authStateChanges.listen(
        _watchUser,
      );
    }
  }

  void _watchUser(User? user) {
    final uid = AuthService.needsEmailVerification(user) ? null : user?.uid;
    if (uid == _uid) return;
    _profileSubscription?.cancel();
    setState(() {
      _uid = uid;
      _status = null;
      _profileError = null;
    });
    if (uid == null) return;
    _profileSubscription = ProfilePlanStore(FirebaseFirestore.instance)
        .watch(uid)
        .listen(
          (status) {
            if (mounted && _uid == uid) {
              final loadOffers = !status.isActive && _status?.isActive != false;
              setState(() {
                _status = status;
                _profileError = null;
              });
              if (loadOffers) unawaited(_billing.loadOffers());
            }
          },
          onError: (Object _) {
            if (mounted && _uid == uid) {
              setState(
                () => _profileError =
                    'Status akun belum dapat dimuat. Periksa koneksi.',
              );
            }
          },
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      unawaited(_billing.restore(silent: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }

  Widget _plan(SubscriptionPlan plan) {
    final id = plan.id;
    final duration = plan.title;
    const normalPrice = 'Harga tersedia setelah terhubung ke Google Play';
    final offer = _billing.offers[id];
    final discount = offer?.discounted == true;
    final available = offer != null;
    final voucherApplies = _billing.voucher?.quotes.containsKey(id) == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Premium $duration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            if (voucherApplies) Text(_billing.voucher!.title),
            if (discount)
              Text(
                offer!.renewalPrice,
                style: const TextStyle(decoration: TextDecoration.lineThrough),
              ),
            if (voucherApplies && !available)
              const Text('Harga voucher belum tersedia untuk paket ini.'),
            Text(
              offer?.price ?? normalPrice,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              discount
                  ? 'Untuk $duration pertama, lalu ${offer!.renewalPrice} setiap $duration.'
                  : '${offer?.renewalPrice ?? normalPrice} setiap $duration.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  !available ||
                      _billing.busy ||
                      _billing.loading ||
                      _status == null ||
                      _profileError != null
                  ? null
                  : () => _billing.buy(id),
              child: Text(available ? 'Langganan $duration' : 'Belum tersedia'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Upgrade Akun')),
    body: ListenableBuilder(
      listenable: _billing,
      builder: (context, _) {
        final premium = _status?.isActive == true;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status akun',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _uid == null
                          ? 'Guest'
                          : _status == null
                          ? 'Memuat status...'
                          : premium
                          ? 'Premium · Jajaners Sultan'
                          : 'Gratis · Jajaners Gratisan',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (premium) ...[
                      const SizedBox(height: 12),
                      PremiumAccessDetails(status: _status!),
                    ],
                    if (_profileError != null) Text(_profileError!),
                  ],
                ),
              ),
            ),
            if (_uid == null) ...[
              const SizedBox(height: 12),
              const Text(
                'Masuk dan verifikasi akun untuk membeli atau memulihkan premium.',
              ),
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Masuk / Daftar'),
              ),
            ] else ...[
              if (!premium) ...[
                const SizedBox(height: 16),
                const Text(
                  'Nikmati riwayat dan laporan hingga 12 bulan, grafik 7 hari, serta personalisasi kartu pengeluaran.',
                ),
                const SizedBox(height: 12),
                PremiumVoucherField(
                  key: ValueKey(_uid),
                  appliedCode: _billing.voucher?.name,
                  message: _billing.voucherMessage,
                  busy: _billing.loading || _billing.busy,
                  onApply: (code) => unawaited(_billing.applyVoucher(code)),
                  onRemove: () => unawaited(_billing.removeVoucher()),
                ),
                ..._billing.plans.map(_plan),
                const Text(
                  'Langganan diperpanjang otomatis dengan harga normal sampai dibatalkan. Batalkan kapan saja melalui Google Play; akses tetap tersedia hingga periode aktif berakhir. Harga final ditampilkan pada pembayaran Google Play.',
                ),
                TextButton(
                  onPressed: _billing.loading || _billing.busy
                      ? null
                      : _billing.loadOffers,
                  child: const Text('Muat ulang paket'),
                ),
              ],
              if (_billing.loading || _billing.busy)
                const LinearProgressIndicator(),
              if (_billing.message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _billing.message!,
                    semanticsLabel: _billing.message,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _billing.busy ? null : _billing.manageSubscription,
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Kelola langganan di Google Play'),
              ),
              TextButton(
                onPressed: _billing.busy ? null : () => _billing.restore(),
                child: const Text('Pulihkan pembelian'),
              ),
            ],
          ],
        );
      },
    ),
  );
}
