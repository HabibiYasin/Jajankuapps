import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/budget_limits.dart';
import '../models/spending_progress.dart';
import '../services/account_data_service.dart';
import '../services/transaction_classifier.dart';

class BudgetSettingsScreen extends StatefulWidget {
  final double dailyLimit, weeklyLimit, monthlyLimit;
  final bool onboarding;
  final List<String>? categories;
  final AccountDataService? accountData;
  final BudgetMode mode;
  const BudgetSettingsScreen({
    super.key,
    required this.dailyLimit,
    required this.weeklyLimit,
    required this.monthlyLimit,
    this.onboarding = false,
    this.categories,
    this.accountData,
    this.mode = BudgetMode.flat,
  });

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final _form = GlobalKey<FormState>();
  late BudgetMode _mode = widget.mode;
  late final _monthly = TextEditingController(
    text: widget.monthlyLimit.toStringAsFixed(0),
  );
  late final String? _owner;
  bool _saving = false;
  int _step = 0;
  AccountDataService get _data =>
      widget.accountData ?? AccountDataService.instance;
  late final Set<String> _categories = {
    ...widget.categories ?? TransactionClassifier.categories,
  };

  @override
  void initState() {
    super.initState();
    _owner = _data.uid;
  }

  @override
  void dispose() {
    _monthly.dispose();
    super.dispose();
  }

  Widget _input(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      onChanged: (_) => setState(() {}),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, prefixText: 'Rp '),
      validator: (text) {
        final amount = double.tryParse(text ?? '');
        return amount == null ||
                !amount.isFinite ||
                amount <= 0 ||
                amount > 1e15
            ? 'Masukkan angka lebih dari 0, maksimal 1.000 triliun'
            : null;
      },
    ),
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu kategori untuk budget kamu.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final monthly = double.parse(_monthly.text);
      final daily = monthly / BudgetLimits.daysInMonth(DateTime.now());
      await _data.saveBudget(
        BudgetLimits(
          daily: daily,
          weekly: daily * 7,
          monthly: monthly,
          mode: _mode,
          categories: TransactionClassifier.categories
              .where(_categories.contains)
              .toList(),
        ),
        expectedUid: _owner,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pengaturan budget berhasil disimpan.')),
      );
      if (!widget.onboarding) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        final message =
            error is FirebaseException && error.code == 'permission-denied'
            ? 'Budget belum tersimpan karena izin penyimpanan akun ditolak. Pilihanmu tetap di sini; coba lagi setelah izin diperbaiki.'
            : error is TimeoutException
            ? 'Penyimpanan belum terkonfirmasi. Periksa koneksi internet lalu coba lagi.'
            : 'Budget gagal disimpan. Pilihanmu tetap di sini; coba lagi.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _budgetOptions() {
    final now = DateTime.now();
    final monthly = double.tryParse(_monthly.text) ?? 0;
    final limits = BudgetLimits(
      monthly: monthly,
      mode: _mode,
      categories: _categories.toList(),
    );
    final valid = monthly.isFinite && monthly > 0 && monthly <= 1e15;
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mode budget',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SegmentedButton<BudgetMode>(
          segments: const [
            ButtonSegment(value: BudgetMode.flat, label: Text('Flat budget')),
            ButtonSegment(
              value: BudgetMode.flexible,
              label: Text('Flexible budget'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: _saving
              ? null
              : (values) => setState(() => _mode = values.single),
        ),
        const SizedBox(height: 12),
        Text(
          _mode == BudgetMode.flat
              ? 'Jatah uangmu tiap hari tetap sama. Kalau hari ini belanja lebih banyak, jatah besok tidak berubah.'
              : 'Kalau hari ini belanja lebih dari jatah, jatah untuk hari-hari berikutnya jadi lebih kecil. Kalau belanja lebih sedikit, jatah tidak bertambah. Jatah paling kecil Rp0. Bulan depan, jatah kembali seperti awal.',
        ),
        const SizedBox(height: 12),
        Text(
          'Uang sebulan dibagi rata untuk ${BudgetLimits.daysInMonth(now)} hari. Jatah seminggu adalah jatah untuk 7 hari.',
        ),
        if (valid) ...[
          const SizedBox(height: 12),
          Text(
            'Budget harian hari ini: ${SpendingProgress.rupiah(limits.dailyFor(now, _data.history))}',
          ),
          Text(
            'Budget mingguan saat ini: ${SpendingProgress.rupiah(limits.weeklyFor(now, _data.history))}',
          ),
          if (_mode == BudgetMode.flexible) ...[
            Text(
              'Budget harian besok: ${SpendingProgress.rupiah(limits.dailyFor(tomorrow, _data.history))}',
            ),
            Text(
              'Budget mingguan besok: ${SpendingProgress.rupiah(limits.weeklyFor(tomorrow, _data.history))}',
            ),
          ],
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _categoryPicker() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Kategori yang mengurangi budget',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      for (final category in TransactionClassifier.categories)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(category),
          value: _categories.contains(category),
          onChanged: _saving
              ? null
              : (selected) => setState(() {
                  if (selected == true) {
                    _categories.add(category);
                  } else {
                    _categories.remove(category);
                  }
                }),
        ),
      Wrap(
        spacing: 12,
        children: [
          OutlinedButton(
            onPressed: _saving
                ? null
                : () => setState(() {
                    _categories
                      ..clear()
                      ..addAll(BudgetLimits.snackCategories);
                  }),
            child: const Text('Jajan aja'),
          ),
          OutlinedButton(
            onPressed: _saving
                ? null
                : () => setState(() {
                    _categories
                      ..clear()
                      ..addAll(TransactionClassifier.categories);
                  }),
            child: const Text('Semuanya'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_categories.isEmpty)
        const Text(
          'Pilih minimal satu kategori.',
          style: TextStyle(color: Colors.red),
        ),
      const Text(
        'Transaksi di luar pilihanmu tetap dicatat, tetapi tidak mengurangi budget.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: !widget.onboarding,
      title: Text(widget.onboarding ? 'Kenalan dulu, yuk!' : 'Limit Budget'),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.onboarding) ...[
              Image.asset(
                'assets/mascot/jajanku_mascot.png',
                height: 180,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _step == 0
                      ? 'Selamat datang! Kamu mau pakai aplikasi ini untuk track apa?'
                      : 'Berapa budget bulanan kamu?',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (!widget.onboarding)
              Text(
                'Atur batas pengeluaran',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            if (!widget.onboarding) ...[
              const SizedBox(height: 24),
              _input('Budget Bulanan', _monthly),
            ],
            if (widget.onboarding && _owner == null) ...[
              const SizedBox(height: 8),
              const Text('Budget Guest disimpan di HP ini.'),
            ],
            if (!widget.onboarding || _step == 0) ...[
              const SizedBox(height: 24),
              _categoryPicker(),
            ],
            if (!widget.onboarding || _step == 1) ...[
              const SizedBox(height: 24),
              if (widget.onboarding) _input('Budget Bulanan', _monthly),
              _budgetOptions(),
              const Text(
                'Semua ini nanti bisa diubah di Personalisasi → Limit Budget, termasuk pilihan kategori kamu.',
              ),
            ],
            const SizedBox(height: 24),
            if (widget.onboarding && _step == 0)
              FilledButton(
                onPressed: _categories.isEmpty
                    ? null
                    : () => setState(() => _step = 1),
                child: const Text('Lanjut: atur budget'),
              )
            else ...[
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  _saving
                      ? 'Menyimpan…'
                      : widget.onboarding
                      ? 'Mulai pakai Jajanku'
                      : 'Simpan Pengaturan',
                ),
              ),
              if (widget.onboarding)
                TextButton(
                  onPressed: _saving ? null : () => setState(() => _step = 0),
                  child: const Text('Kembali ke kategori'),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
