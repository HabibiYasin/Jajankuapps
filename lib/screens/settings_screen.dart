import 'package:flutter/material.dart';

import '../widgets/tutorial_dialog.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  final String userName;
  final String userRole;
  final double dailyLimit;
  final double weeklyLimit;
  final double monthlyLimit;

  const SettingsScreen({
    super.key,
    required this.userName,
    required this.userRole,
    required this.dailyLimit,
    required this.weeklyLimit,
    required this.monthlyLimit,
  });

  Widget _buildBudgetInput(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: TextEditingController(text: value.toStringAsFixed(0)),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixText: 'Rp ',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.charcoal, AppColors.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              leading: const CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.aqua,
                child: Icon(
                  Icons.person_rounded,
                  color: AppColors.charcoal,
                  size: 32,
                ),
              ),
              title: Text(
                userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                userRole,
                style: const TextStyle(color: AppColors.mist),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Pengaturan Limit Budget',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _buildBudgetInput('Maksimal Belanja Harian', dailyLimit),
          _buildBudgetInput('Maksimal Belanja Mingguan', weeklyLimit),
          _buildBudgetInput('Maksimal Belanja Bulanan', monthlyLimit),
          const SizedBox(height: 8),
          const Text(
            'Bantuan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.pink,
                child: Icon(Icons.help_outline, color: Colors.white),
              ),
              title: const Text(
                'Cara Pakai',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Lihat panduan penggunaan aplikasi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showTutorialDialog(context),
            ),
          ),
        ],
      ),
    );
  }
}
