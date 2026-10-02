import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../services/transaction_classifier.dart';
import '../services/export_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final List<TransactionModel> history;
  final Function(TransactionModel) onDelete;
  final Function(TransactionModel, DateTime) onUpdateDate;
  final Function(TransactionModel) onUpdateTransaction;

  const TransactionHistoryScreen({
    super.key,
    required this.history,
    required this.onDelete,
    required this.onUpdateDate,
    required this.onUpdateTransaction,
  });

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _searchQuery = "";
  String _selectedCategory = "Semua";

  void _showEditTransactionDialog(
    BuildContext context,
    TransactionModel tx,
    StateSetter setModalState,
  ) {
    final merchantController = TextEditingController(text: tx.merchant);
    final sourceController = TextEditingController(text: tx.source);
    String selectedCategory = tx.category;

    final availableCategories = TransactionClassifier.categories;

    if (!availableCategories.contains(selectedCategory)) {
      selectedCategory = 'Umum';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                'Edit Detail Transaksi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nama Merchant',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: merchantController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Sumber QRIS / Aplikasi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: sourceController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: 'Contoh: ShopeePay, DANA',
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Jenis Transaksi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        helperText: 'Sesuaikan kategori dengan pembelian.',
                      ),
                      items: availableCategories
                          .map(
                            (String cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() => selectedCategory = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      tx.merchant = merchantController.text;
                      tx.source = sourceController.text;
                      tx.category = selectedCategory;
                    });
                    widget.onUpdateTransaction(tx);
                    setModalState(() {});
                    Navigator.pop(context);
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
    final tx = widget.history[index];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detail Transaksi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tx.merchant,
                      style: const TextStyle(fontSize: 18),
                    ),
                    subtitle: Text('${tx.category} • Sumber: ${tx.source}'),
                    trailing: Text(
                      tx.nominalStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Colors.grey,
                    ),
                    title: const Text('Tanggal & Waktu'),
                    subtitle: Text(tx.formattedTime),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: const Text('Ubah Tanggal'),
                          onPressed: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: tx.dateTime,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (!context.mounted) return;
                            if (pickedDate != null) {
                              TimeOfDay? pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(
                                  tx.dateTime,
                                ),
                              );
                              if (!context.mounted) return;
                              if (pickedTime != null) {
                                widget.onUpdateDate(
                                  tx,
                                  DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  ),
                                );
                                setModalState(() {});
                                setState(() {});
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit Detail'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _showEditTransactionDialog(
                            context,
                            tx,
                            setModalState,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      icon: const Icon(Icons.delete),
                      label: const Text('Hapus Riwayat Ini'),
                      onPressed: () {
                        widget.onDelete(tx);
                        Navigator.pop(context);
                      },
                    ),
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
    List<TransactionModel> filteredHistory = widget.history.where((tx) {
      bool matchesSearch = tx.merchant.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      bool matchesCategory =
          _selectedCategory == "Semua" || tx.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Export Laporan ke CSV / Sheet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                await ExportService.exportTransactionsToCSV(widget.history);
              },
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Riwayat Transaksi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

          TextField(
            decoration: InputDecoration(
              hintText: 'Cari nama merchant...',
              prefixIcon: const Icon(Icons.search, color: Colors.teal),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
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
              children: ['Semua', ...TransactionClassifier.categories].map((
                category,
              ) {
                bool isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    selectedColor: Colors.teal,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
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
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Tidak ada transaksi yang cocok',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredHistory.length,
                  itemBuilder: (context, index) {
                    final tx = filteredHistory[index];
                    final originalIndex = widget.history.indexOf(tx);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () =>
                            _showTransactionDetailModal(context, originalIndex),
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal[50],
                            child: const Icon(
                              Icons.receipt_long,
                              color: Colors.teal,
                            ),
                          ),
                          title: Text(
                            tx.merchant,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${tx.category} • ${tx.source}\n${tx.formattedTime}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            tx.nominalStr,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
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
