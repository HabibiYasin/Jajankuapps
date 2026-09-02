import 'package:flutter/material.dart';

class BudgetSettingsScreen extends StatelessWidget {
  final double dailyLimit;
  final double weeklyLimit;
  final double monthlyLimit;

  const BudgetSettingsScreen({
    super.key,
    required this.dailyLimit,
    required this.weeklyLimit,
    required this.monthlyLimit,
  });

  Widget _budgetInput(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: value.toStringAsFixed(0),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, prefixText: 'Rp '),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Limit Budget'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Atur batas pengeluaran',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tentukan batas agar pengeluaran lebih terkontrol.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _budgetInput('Maksimal Belanja Harian', dailyLimit),
            _budgetInput('Maksimal Belanja Mingguan', weeklyLimit),
            _budgetInput('Maksimal Belanja Bulanan', monthlyLimit),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Penyimpanan budget akan dihubungkan berikutnya.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan Pengaturan'),
            ),
          ],
        ),
      ),
    );
  }
}
