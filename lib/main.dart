import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() => runApp(const MaterialApp(
      home: QrisTrackerApp(),
      debugShowCheckedModeBanner: false,
    ));

class TransactionModel {
  final String merchant;
  final String nominalStr;
  final String timeStr;
  final String category;
  final double numericNominal;

  TransactionModel({
    required this.merchant,
    required this.nominalStr,
    required this.timeStr,
    required this.category,
    required this.numericNominal,
  });
}

class QrisTrackerApp extends StatefulWidget {
  const QrisTrackerApp({super.key});
  @override
  State<QrisTrackerApp> createState() => _QrisTrackerAppState();
}

class _QrisTrackerAppState extends State<QrisTrackerApp> {
  // Navigasi Tab
  int _selectedIndex = 0;

  // State Pengaturan Budget & Profil
  final String _userName = "Habibi Yasin";
  final String _userRole = "QA Engineer";
  double _dailyBudgetLimit = 50000.0;
  double _weeklyBudgetLimit = 350000.0;
  double _monthlyBudgetLimit = 1500000.0;

  // State Scanner
  File? _imageFile;
  TransactionModel? _latestTransaction;
  final List<TransactionModel> _transactionHistory = [];

  final _picker = ImagePicker();
  final _textRecognizer = TextRecognizer();

  // --- FUNGSI PEMROSESAN GAMBAR ---
  Future<void> _processImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _imageFile = File(pickedFile.path);
      _latestTransaction = null;
    });

    final inputImage = InputImage.fromFile(_imageFile!);
    try {
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final tx = _parseQrisReceipt(recognizedText.text);

      setState(() {
        _latestTransaction = tx;
        _transactionHistory.insert(0, tx);
        // Otomatis pindah ke tab Dashboard (index 0) setelah berhasil
        _selectedIndex = 0; 
      });

      _checkDailyBudget(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _checkDailyBudget(BuildContext context) {
    double totalToday = _calculateTodayTotal();
    if (totalToday > _dailyBudgetLimit) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Peringatan Budget!'),
            ],
          ),
          content: Text(
            'Total pengeluaran Anda telah mencapai Rp${totalToday.toStringAsFixed(0)}.\n\n'
            'Batas harian yang Anda tentukan adalah Rp${_dailyBudgetLimit.toStringAsFixed(0)}.\n'
            'Kurangi jajan dulu ya supaya dompet aman!',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Siap, Mengerti'),
            ),
          ],
        ),
      );
    }
  }

  TransactionModel _parseQrisReceipt(String rawText) {
    String merchantName = "Tidak Diketahui";
    String nominal = "Rp0";
    double numericVal = 0;

    DateTime now = DateTime.now();
    String timeStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    String category = "Umum";

    List<String> lines = rawText.split('\n');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      if (line.toLowerCase().contains("terbayar ke") || line.toLowerCase().contains("kamu membayar")) {
        if (i + 1 < lines.length) {
          merchantName = lines[i + 1].trim();
          String lowerMerchant = merchantName.toLowerCase();

          if (lowerMerchant.contains("cilok") || lowerMerchant.contains("siomay") || lowerMerchant.contains("dimsum") || lowerMerchant.contains("snack") || lowerMerchant.contains("cilor") || lowerMerchant.contains("es krim") || lowerMerchant.contains("martabak") || lowerMerchant.contains("batagor") || lowerMerchant.contains("pentol")) {
            category = "Jajan";
          } else if (lowerMerchant.contains("kopi") || lowerMerchant.contains("teh") || lowerMerchant.contains("boba") || lowerMerchant.contains("jus") || lowerMerchant.contains("es ") || lowerMerchant.contains("drink") || lowerMerchant.contains("cafe")) {
            category = "Minuman";
          } else if (lowerMerchant.contains("roti") || lowerMerchant.contains("nasi") || lowerMerchant.contains("bakso") || lowerMerchant.contains("mie") || lowerMerchant.contains("ayam") || lowerMerchant.contains("soto") || lowerMerchant.contains("sate") || lowerMerchant.contains("gulung") || lowerMerchant.contains("makan") || lowerMerchant.contains("resto") || lowerMerchant.contains("warung")) {
            category = "Makanan";
          } else if (lowerMerchant.contains("toko") || lowerMerchant.contains("store") || lowerMerchant.contains("shop") || lowerMerchant.contains("mart") || lowerMerchant.contains("supermarket") || lowerMerchant.contains("grosir")) {
            category = "Belanja";
          } else {
            category = "Lifestyle";
          }
        }
      }

      if (line.startsWith("Rp") && nominal == "Rp0") {
        if (i > 2) {
          nominal = line;
          String cleanNum = nominal.replaceAll(RegExp(r'[^0-9]'), '');
          numericVal = double.tryParse(cleanNum) ?? 0;
        }
      }
    }

    return TransactionModel(
      merchant: merchantName,
      nominalStr: nominal,
      timeStr: timeStr,
      category: category,
      numericNominal: numericVal,
    );
  }

  double _calculateTodayTotal() {
    double total = 0;
    for (var tx in _transactionHistory) {
      total += tx.numericNominal;
    }
    return total;
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  // --- HALAMAN 1: DASHBOARD ---
  Widget _buildDashboard() {
    double currentTotal = _calculateTodayTotal();
    double progress = (currentTotal / _dailyBudgetLimit).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Ringkasan Harian
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Total Belanja Hari Ini', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('Rp${currentTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    color: progress >= 1.0 ? Colors.red : Colors.teal,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text('Batas Harian: Rp${_dailyBudgetLimit.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Simulasi Chart Mingguan (Native Flutter)
          const Text('Statistik Belanja (7 Hari)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            height: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                // Hari ini (index 6) menggunakan data asli, sisanya dummy
                double barHeight = index == 6 ? (currentTotal / _dailyBudgetLimit) * 100 : (20 + (index * 10)).toDouble();
                barHeight = barHeight.clamp(0, 100);
                List<String> days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 20,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: index == 6 ? Colors.teal : Colors.teal[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(days[index], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 24),

          // Riwayat Transaksi
          const Text('Riwayat Transaksi Sesi Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _transactionHistory.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Belum ada transaksi', style: TextStyle(color: Colors.grey))))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _transactionHistory.length,
                  itemBuilder: (context, index) {
                    final tx = _transactionHistory[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal[50],
                          child: const Icon(Icons.receipt_long, color: Colors.teal),
                        ),
                        title: Text(tx.merchant, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${tx.category} • ${tx.timeStr}', style: const TextStyle(fontSize: 12)),
                        trailing: Text(tx.nominalStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  // --- HALAMAN 2: UPLOAD/SCAN ---
  Widget _buildScanner() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: Colors.teal),
            const SizedBox(height: 24),
            const Text(
              'Upload Screenshot Bukti Transfer\nQRIS / Dompet Digital',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _processImage,
                icon: const Icon(Icons.upload_file),
                label: const Text('Pilih dari Galeri', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            if (_imageFile != null) ...[
              const SizedBox(height: 24),
              const Text('Gambar terakhir diproses:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_imageFile!, height: 200, fit: BoxFit.cover),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // --- HALAMAN 3: PENGATURAN ---
  Widget _buildSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profil Pengguna
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              leading: const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.teal,
                child: Icon(Icons.person, color: Colors.white, size: 32),
              ),
              title: Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text(_userRole),
            ),
          ),
          const SizedBox(height: 24),

          const Text('Pengaturan Limit Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),

          // Form Pengaturan (Untuk MVP, ini hanya visual display state awal)
          _buildBudgetInput('Maksimal Belanja Harian', _dailyBudgetLimit),
          _buildBudgetInput('Maksimal Belanja Mingguan', _weeklyBudgetLimit),
          _buildBudgetInput('Maksimal Belanja Bulanan', _monthlyBudgetLimit),
        ],
      ),
    );
  }

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
        onSubmitted: (val) {
          // Logika untuk menyimpan update limit bisa ditambahkan di sini nanti
        },
      ),
    );
  }

  // --- ROOT WIDGET ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QRIS Expense Tracker'),
        elevation: 0,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      // IndexedStack menahan state halaman agar gambar/data tidak hilang saat ganti tab
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(),
          _buildScanner(),
          _buildSettings(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
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