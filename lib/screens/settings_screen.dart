import 'package:flutter/material.dart';

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
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              leading: const CircleAvatar(radius: 30, backgroundColor: Colors.teal, child: Icon(Icons.person, color: Colors.white, size: 32)),
              title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text(userRole),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Pengaturan Limit Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _buildBudgetInput('Maksimal Belanja Harian', dailyLimit),
          _buildBudgetInput('Maksimal Belanja Mingguan', weeklyLimit),
          _buildBudgetInput('Maksimal Belanja Bulanan', monthlyLimit),
        ],
      ),
    );
  }
}