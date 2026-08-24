import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// Mengimpor file model, service, dan screens yang sudah kita pecah
import 'models/transaction_model.dart';
import 'services/ocr_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/settings_screen.dart';

void main() => runApp(const MaterialApp(home: QrisTrackerApp(), debugShowCheckedModeBanner: false));

class QrisTrackerApp extends StatefulWidget {
  const QrisTrackerApp({super.key});
  @override
  State<QrisTrackerApp> createState() => _QrisTrackerAppState();
}

class _QrisTrackerAppState extends State<QrisTrackerApp> {
  int _selectedIndex = 0;

  // Global State
  final String _userName = "Habibi Yasin";
  final String _userRole = "QA Engineer";
  final double _dailyBudgetLimit = 50000.0;
  final double _weeklyBudgetLimit = 350000.0;
  final double _monthlyBudgetLimit = 1500000.0;

  File? _imageFile;
  final List<TransactionModel> _transactionHistory = [];
  final _picker = ImagePicker();

  Future<void> _processImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    try {
      final tx = await OcrService.processImage(File(pickedFile.path));
      setState(() {
        _imageFile = File(pickedFile.path);
        _transactionHistory.insert(0, tx);
        _selectedIndex = 0; 
      });
      _checkDailyBudget();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _checkDailyBudget() {
    double totalToday = 0;
    DateTime now = DateTime.now();
    for (var tx in _transactionHistory) {
      if (tx.dateTime.year == now.year && tx.dateTime.month == now.month && tx.dateTime.day == now.day) totalToday += tx.numericNominal;
    }
    if (totalToday > _dailyBudgetLimit) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text('Budget Habis!')]),
          content: Text('Pengeluaran harian mencapai Rp${totalToday.toStringAsFixed(0)}.\nBatas: Rp${_dailyBudgetLimit.toStringAsFixed(0)}'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QRIS Expense Tracker'), elevation: 0, backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Panggil Widget Eksternal dan oper data (State Lifting)
          DashboardScreen(
            history: _transactionHistory,
            dailyLimit: _dailyBudgetLimit,
            monthlyLimit: _monthlyBudgetLimit,
            onDelete: (index) => setState(() => _transactionHistory.removeAt(index)),
            onUpdateDate: (index, newDate) => setState(() => _transactionHistory[index].dateTime = newDate),
          ),
          ScannerScreen(
            onProcessImage: _processImage,
            imageFile: _imageFile,
          ),
          SettingsScreen(
            userName: _userName,
            userRole: _userRole,
            dailyLimit: _dailyBudgetLimit,
            weeklyLimit: _weeklyBudgetLimit,
            monthlyLimit: _monthlyBudgetLimit,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.document_scanner), label: 'Scan Struk'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Pengaturan'),
        ],
      ),
    );
  }
}