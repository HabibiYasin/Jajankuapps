import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/budget_limits.dart';
import '../services/account_data_service.dart';

class BudgetSettingsScreen extends StatefulWidget {
  final double dailyLimit, weeklyLimit, monthlyLimit;
  const BudgetSettingsScreen({
    super.key,
    required this.dailyLimit,
    required this.weeklyLimit,
    required this.monthlyLimit,
  });

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final _daily = TextEditingController(
    text: widget.dailyLimit.toStringAsFixed(0),
  );
  late final _weekly = TextEditingController(
    text: widget.weeklyLimit.toStringAsFixed(0),
  );
  late final _monthly = TextEditingController(
    text: widget.monthlyLimit.toStringAsFixed(0),
  );
  late final String? _owner;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _owner = AccountDataService.instance.uid;
  }

  @override
  void dispose() {
    _daily.dispose();
    _weekly.dispose();
    _monthly.dispose();
    super.dispose();
  }

  Widget _input(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
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
    setState(() => _saving = true);
    try {
      await AccountDataService.instance.saveBudget(
        BudgetLimits(
          daily: double.parse(_daily.text),
          weekly: double.parse(_weekly.text),
          monthly: double.parse(_monthly.text),
        ),
        expectedUid: _owner,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _owner == null ? 'Budget disimpan di HP ini.' : 'Perubahan budget diterima. Lihat status sinkronisasi di Personalisasi.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Budget gagal disimpan: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Limit Budget')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Atur batas pengeluaran',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _owner == null
                  ? 'Budget Guest disimpan di HP ini.'
                  : 'Budget mengikuti akun yang sedang login.',
            ),
            const SizedBox(height: 24),
            _input('Maksimal Belanja Harian', _daily),
            _input('Maksimal Belanja Mingguan', _weekly),
            _input('Maksimal Belanja Bulanan', _monthly),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Menyimpan…' : 'Simpan Pengaturan'),
            ),
          ],
        ),
      ),
    ),
  );
}
