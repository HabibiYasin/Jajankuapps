import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import 'top_categories_widget.dart';
import '../services/export_service.dart';

class DashboardScreen extends StatefulWidget {
  final List<TransactionModel> history;
  final double dailyLimit;
  final double monthlyLimit;
  final Function(int) onDelete;
  final Function(int, DateTime) onUpdateDate;
  final Function(TransactionModel) onUpdateTransaction; // Tambahkan callback ini untuk update data SQLite

  const DashboardScreen({
    super.key, 
    required this.history, 
    required this.dailyLimit, 
    required this.monthlyLimit, 
    required this.onDelete, 
    required this.onUpdateDate,
    required this.onUpdateTransaction, // Wajib ditambahkan di main.dart nanti
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _searchQuery = "";
  String _selectedCategory = "Semua";

  double _calculateTodayTotal() {
    double total = 0; DateTime now = DateTime.now();
    for (var tx in widget.history) { if (tx.dateTime.year == now.year && tx.dateTime.month == now.month && tx.dateTime.day == now.day) total += tx.numericNominal; }
    return total;
  }

  double _calculateMonthlyTotal() {
    double total = 0; DateTime now = DateTime.now();
    for (var tx in widget.history) { if (tx.dateTime.year == now.year && tx.dateTime.month == now.month) total += tx.numericNominal; }
    return total;
  }

  String _getMonthName(int monthNumber) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des']; return months[monthNumber - 1];
  }

  String _getShortDayName(int weekday) {
    switch (weekday) { case 1: return 'Sen'; case 2: return 'Sel'; case 3: return 'Rab'; case 4: return 'Kam'; case 5: return 'Jum'; case 6: return 'Sab'; case 7: return 'Min'; default: return ''; }
  }

  List<Widget> _buildChartBars() {
    List<Widget> bars = []; DateTime now = DateTime.now(); double maxVal = 1.0; List<double> dailyTotals = [];
    for (int i = 6; i >= 0; i--) {
      DateTime targetDay = now.subtract(Duration(days: i)); double dailyTotal = 0;
      for (var tx in widget.history) { if (tx.dateTime.year == targetDay.year && tx.dateTime.month == targetDay.month && tx.dateTime.day == targetDay.day) dailyTotal += tx.numericNominal; }
      dailyTotals.add(dailyTotal); if (dailyTotal > maxVal) maxVal = dailyTotal;
    }
    for (int i = 0; i < 7; i++) {
      DateTime targetDay = now.subtract(Duration(days: 6 - i)); double t = dailyTotals[i]; double barHeight = (t / maxVal) * 90; if (barHeight < 4) barHeight = 4; bool isToday = (i == 6);
      bars.add(
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (t > 0) Text('${(t / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 6),
            Container(width: 24, height: barHeight, decoration: BoxDecoration(color: isToday ? Colors.teal : Colors.teal[200], borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Text(_getShortDayName(targetDay.weekday), style: TextStyle(fontSize: 11, color: isToday ? Colors.teal : Colors.grey, fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      );
    }
    return bars;
  }

  // Fungsi Dialog Edit Transaksi
  void _showEditTransactionDialog(BuildContext context, TransactionModel tx, StateSetter setModalState) {
    final merchantController = TextEditingController(text: tx.merchant);
    final sourceController = TextEditingController(text: tx.source);
    String selectedCategory = tx.category;

    final List<String> availableCategories = [
      'Makanan', 'Minuman', 'Jajan', 'Belanja', 'Tagihan & Pulsa', 'Lifestyle', 'Transportasi', 'Umum'
    ];

    if (!availableCategories.contains(selectedCategory)) {
      selectedCategory = 'Umum';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Detail Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nama Merchant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(controller: merchantController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 12),
                    
                    const Text('Sumber QRIS / Aplikasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(controller: sourceController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, hintText: 'Contoh: ShopeePay, DANA')),
                    const SizedBox(height: 12),
                    
                    const Text('Jenis Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: availableCategories.map((String cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      onChanged: (val) {
                        if (val != null) setStateDialog(() => selectedCategory = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() {
                      tx.merchant = merchantController.text;
                      tx.source = sourceController.text;
                      tx.category = selectedCategory;
                    });
                    widget.onUpdateTransaction(tx); // Panggil fungsi update SQLite
                    setModalState(() {}); // Refresh modal bottom sheet
                    Navigator.pop(context); // Tutup dialog
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTransactionDetailModal(BuildContext context, int index) {
    showModalBottomSheet(
      context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final tx = widget.history[index];
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Detail Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero, 
                    title: Text(tx.merchant, style: const TextStyle(fontSize: 18)), 
                    subtitle: Text('${tx.category} • Sumber: ${tx.source}'), // Menampilkan sumber aplikasi QRIS
                    trailing: Text(tx.nominalStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal))
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today, color: Colors.grey), title: const Text('Tanggal & Waktu'), subtitle: Text(tx.formattedTime),
                  ),
                  const SizedBox(height: 16),
                  
                  // Tombol Edit dan Ubah Tanggal
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16), 
                          label: const Text('Ubah Tanggal'), 
                          onPressed: () async {
                            DateTime? pickedDate = await showDatePicker(context: context, initialDate: tx.dateTime, firstDate: DateTime(2020), lastDate: DateTime(2100));
                            if (pickedDate != null) {
                              TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(tx.dateTime));
                              if (pickedTime != null) {
                                widget.onUpdateDate(index, DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute));
                                setModalState(() {}); setState(() {});
                              }
                            }
                          }
                        )
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.edit, size: 16), 
                          label: const Text('Edit Detail'), 
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                          onPressed: () => _showEditTransactionDialog(context, tx, setModalState),
                        )
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), icon: const Icon(Icons.delete), label: const Text('Hapus Riwayat Ini'), onPressed: () { widget.onDelete(index); Navigator.pop(context); }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double currentDaily = _calculateTodayTotal(); double currentMonthly = _calculateMonthlyTotal();

    List<TransactionModel> filteredHistory = widget.history.where((tx) {
      bool matchesSearch = tx.merchant.toLowerCase().contains(_searchQuery.toLowerCase());
      bool matchesCategory = _selectedCategory == "Semua" || tx.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [const Text('Hari Ini', style: TextStyle(color: Colors.grey, fontSize: 12)), Text('Rp${currentDaily.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), LinearProgressIndicator(value: (currentDaily / widget.dailyLimit).clamp(0.0, 1.0), color: currentDaily >= widget.dailyLimit ? Colors.red : Colors.teal)])))),
              Expanded(child: Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Text('Bulan Ini (${_getMonthName(DateTime.now().month)})', style: const TextStyle(color: Colors.grey, fontSize: 12)), Text('Rp${currentMonthly.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), LinearProgressIndicator(value: (currentMonthly / widget.monthlyLimit).clamp(0.0, 1.0), color: currentMonthly >= widget.monthlyLimit ? Colors.red : Colors.blue)])))),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Statistik Belanja (7 Hari Terakhir)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(height: 190, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: _buildChartBars())),
          const SizedBox(height: 24),
          
          TopCategoriesWidget(history: widget.history),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Export Laporan ke CSV / Sheet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                await ExportService.exportTransactionsToCSV(widget.history);
              },
            ),
          ),
          const SizedBox(height: 24),

          const Text('Riwayat Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),

          TextField(
            decoration: InputDecoration(
              hintText: 'Cari nama merchant...',
              prefixIcon: const Icon(Icons.search, color: Colors.teal),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Semua', 'Makanan', 'Minuman', 'Jajan', 'Belanja', 'Tagihan & Pulsa', 'Lifestyle', 'Transportasi'].map((category) {
                bool isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    selectedColor: Colors.teal,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    backgroundColor: Colors.grey.shade100,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          filteredHistory.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Tidak ada transaksi yang cocok', style: TextStyle(color: Colors.grey))))
              : ListView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: filteredHistory.length,
                  itemBuilder: (context, index) {
                    final tx = filteredHistory[index];
                    final originalIndex = widget.history.indexOf(tx);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8), 
                      child: InkWell(
                        onTap: () => _showTransactionDetailModal(context, originalIndex), 
                        borderRadius: BorderRadius.circular(12), 
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.teal[50], child: const Icon(Icons.receipt_long, color: Colors.teal)), 
                          title: Text(tx.merchant, style: const TextStyle(fontWeight: FontWeight.bold)), 
                          subtitle: Text('${tx.category} • ${tx.source}\n${tx.formattedTime}', style: const TextStyle(fontSize: 12)), 
                          trailing: Text(tx.nominalStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}