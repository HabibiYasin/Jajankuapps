import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // <-- Diperlukan untuk baca Raw Text

import 'models/transaction_model.dart';
import 'services/ocr_service.dart';
import 'services/database_helper.dart';
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

  final String _userName = "Habibi Yasin";
  final String _userRole = "QA Engineer";
  final double _dailyBudgetLimit = 50000.0;
  final double _weeklyBudgetLimit = 350000.0;
  final double _monthlyBudgetLimit = 1500000.0;

  File? _imageFile;
  List<TransactionModel> _transactionHistory = [];
  final _picker = ImagePicker();
  bool _isLoading = true;

  // Variabel untuk menampung teks mentah OCR (Debug UI)
  String _rawDebugText = "";

  // Stream subscription untuk menangkap intent share dari luar
  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadTransactionsFromDB(); // Muat data dari SQLite saat aplikasi dibuka

    // 1. Mendengarkan intent saat aplikasi berjalan di background/paused dan menerima file share baru
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        String sharedPath = value.first.path;
        _processSharedImageFile(File(sharedPath));
      }
    }, onError: (err) {
      debugPrint("Error get shared media stream: $err");
    });

    // 2. Mendengarkan intent saat aplikasi baru dibuka dari kondisi tertutup (cold start) melalui share file
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        String sharedPath = value.first.path;
        _processSharedImageFile(File(sharedPath));
      }
      // Reset intent setelah diproses agar tidak terpanggil berulang kali
      ReceiveSharingIntent.instance.reset();
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  // Ambil data dari database lokal
  Future<void> _loadTransactionsFromDB() async {
    final data = await DatabaseHelper.instance.fetchTransactions();
    setState(() {
      _transactionHistory = data;
      _isLoading = false;
    });
  }

  // Fungsi khusus untuk memproses file gambar (share intent maupun dari galeri)
  Future<void> _processSharedImageFile(File imageFile) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 1. Ekstraksi Raw Text secara langsung untuk ditampilkan di Debug UI ScannerScreen
      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      setState(() {
        _rawDebugText = recognizedText.text.isNotEmpty ? recognizedText.text : "Tidak ada teks yang terdeteksi.";
      });
      
      await textRecognizer.close();

      // 2. Proses parsing transaksi ke model & SQLite
      final tx = await OcrService.processImage(imageFile);
      
      await DatabaseHelper.instance.insertTransaction(tx);
      await _loadTransactionsFromDB();

      setState(() {
        _imageFile = imageFile;
        _selectedIndex = 1; // Otomatis pindah ke tab Scanner Screen agar kotak debug langsung terlihat
        _isLoading = false;
      });
      
      _checkDailyBudget();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _rawDebugText = "Gagal memproses OCR: $e";
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memproses file: $e")));
      }
    }
  }

  // Fungsi proses gambar manual dari tombol di ScannerScreen (Galeri)
  Future<void> _processImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    await _processSharedImageFile(File(pickedFile.path));
  }

  void _checkDailyBudget() {
    double totalToday = 0;
    DateTime now = DateTime.now();
    for (var tx in _transactionHistory) {
      if (tx.dateTime.year == now.year && tx.dateTime.month == now.month && tx.dateTime.day == now.day) {
        totalToday += tx.numericNominal;
      }
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('QRIS Expense Tracker'), elevation: 0, backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(
            history: _transactionHistory,
            dailyLimit: _dailyBudgetLimit,
            monthlyLimit: _monthlyBudgetLimit,
            onDelete: (index) async {
              await DatabaseHelper.instance.deleteTransaction(_transactionHistory[index]);
              await _loadTransactionsFromDB();
            },
            onUpdateDate: (index, newDate) async {
              final tx = _transactionHistory[index];
              await DatabaseHelper.instance.updateTransactionDate(tx, newDate);
              await _loadTransactionsFromDB();
            },
          ),
          ScannerScreen(
            onProcessImage: _processImage,
            imageFile: _imageFile,
            rawTextDebug: _rawDebugText, // Meneruskan data raw text ke UI Scanner
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