import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../services/transaction_classifier.dart';
import '../services/export_service.dart';
import '../models/budget_limits.dart';
import '../services/monthly_report_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final List<TransactionModel> history;
  final BudgetLimits budgetLimits;
  final String userName;
  final Function(TransactionModel) onDelete;
  final Function(TransactionModel, DateTime) onUpdateDate;
  final Function(TransactionModel) onUpdateTransaction;

  const TransactionHistoryScreen({
    super.key,
    required this.history,
    this.budgetLimits = const BudgetLimits(),
    this.userName = 'Pengguna Jajanku',
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
  int _selectedMonthOffset = -1;
  String _sortOrder = 'Paling baru';
  String _selectedType = 'Semua';
  bool _exportingPdf = false;

  Future<void> _downloadMonthlyReport() async {
    final now = DateTime.now();
    final available = <DateTime>{
      DateTime(now.year, now.month),
      ...widget.history.map((t) => DateTime(t.dateTime.year, t.dateTime.month)),
    }.toList()..sort((a, b) => b.compareTo(a));
    var selected = available.first;
    final nameController = TextEditingController(text: widget.userName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Laporan bulanan PDF'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Nama pada laporan',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DateTime>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Bulan laporan'),
                  items: available
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(MonthlyReportService.monthLabel(m)),
                        ),
                      )
                      .toList(),
                  onChanged: (m) {
                    if (m != null) update(() => selected = m);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'PDF berisi ringkasan budget, grafik, perbandingan, rekap harian, dan rincian transaksi. Simpan PDF melalui menu berbagi.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Buat PDF'),
            ),
          ],
        ),
      ),
    );
    final name = nameController.text.trim();
    nameController.dispose();
    if (confirmed != true || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _exportingPdf = true);
    try {
      await MonthlyReportService.export(
        report: MonthlyReport(
          history: widget.history,
          month: selected,
          limits: widget.budgetLimits,
        ),
        name: name,
        shareOrigin: origin,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuat PDF. Silakan coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  void _showEditTransactionDialog(
    BuildContext context,
    TransactionModel tx,
    StateSetter setModalState,
  ) {
    final merchantController = TextEditingController(text: tx.merchant);
    final sourceController = TextEditingController(text: tx.source);
    String selectedCategory = tx.category;
    String selectedMethod = tx.paymentMethod;

    final availableCategories = tx.isIncome
        ? TransactionModel.incomeCategories
        : TransactionClassifier.categories;

    if (!availableCategories.contains(selectedCategory)) {
      selectedCategory = availableCategories.last;
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
                    Text(
                      tx.isIncome ? 'Asal Pemasukan' : 'Nama Merchant',
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
                      'Sumber Uang',
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

                    DropdownButtonFormField<String>(
                      initialValue: selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Metode Pembayaran',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: TransactionModel.paymentMethods
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(method),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() => selectedMethod = value);
                        }
                      },
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
                      tx.source = sourceController.text.trim();
                      tx.paymentMethod = selectedMethod;
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
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detail Transaksi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        tx.merchant,
                        style: const TextStyle(fontSize: 18),
                      ),
                      subtitle: Text(
                        '${tx.category}\nSumber Uang: ${tx.source}\nMetode: ${tx.paymentMethod}',
                      ),
                      trailing: Text(
                        '${tx.isIncome ? '+' : '-'} ${tx.nominalStr}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: tx.isIncome ? Colors.green : Colors.redAccent,
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
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstMonth = DateTime(now.year, now.month - 3);
    final nextMonth = DateTime(now.year, now.month + 1);
    final selectedMonth = DateTime(now.year, now.month - _selectedMonthOffset);
    final filteredHistory =
        widget.history.where((tx) {
          bool matchesSearch = tx.merchant.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
          bool matchesCategory =
              _selectedCategory == "Semua" || tx.category == _selectedCategory;
          final matchesMonth = _selectedMonthOffset == -1
              ? !tx.dateTime.isBefore(firstMonth) &&
                    tx.dateTime.isBefore(nextMonth)
              : tx.dateTime.year == selectedMonth.year &&
                    tx.dateTime.month == selectedMonth.month;
          final matchesType =
              _selectedType == 'Semua' ||
              (_selectedType == 'Pemasukan' ? tx.isIncome : !tx.isIncome);
          return matchesSearch &&
              matchesCategory &&
              matchesMonth &&
              matchesType;
        }).toList()..sort((a, b) {
          final comparison = switch (_sortOrder) {
            'Paling mahal' => b.numericNominal.compareTo(a.numericNominal),
            'Paling murah' => a.numericNominal.compareTo(b.numericNominal),
            'Paling lama' => a.dateTime.compareTo(b.dateTime),
            _ => b.dateTime.compareTo(a.dateTime),
          };
          return comparison != 0
              ? comparison
              : b.dateTime.compareTo(a.dateTime);
        });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _exportingPdf ? null : _downloadMonthlyReport,
            icon: _exportingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: Text(
              _exportingPdf
                  ? 'Membuat laporan PDF...'
                  : 'Download Laporan Bulanan PDF',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Ekspor Laporan Excel / Sheets'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                if (widget.history.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Belum ada transaksi untuk diekspor.'),
                    ),
                  );
                  return;
                }
                try {
                  await ExportService.exportTransactionsToExcel(widget.history);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Gagal mengekspor laporan. Silakan coba lagi.',
                      ),
                    ),
                  );
                }
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
              fillColor: Theme.of(context).colorScheme.surface,
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

          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Jenis Transaksi',
              border: OutlineInputBorder(),
            ),
            items: ['Semua', 'Pengeluaran', 'Pemasukan']
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedType = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('history-category-filter'),
            initialValue: _selectedCategory,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              prefixIcon: Icon(Icons.category_outlined),
              border: OutlineInputBorder(),
            ),
            items:
                [
                      'Semua',
                      ...TransactionClassifier.categories,
                      ...TransactionModel.incomeCategories,
                    ]
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedCategory = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: const ValueKey('history-month-filter'),
            initialValue: _selectedMonthOffset,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Bulan',
              prefixIcon: Icon(Icons.calendar_month_outlined),
              border: OutlineInputBorder(),
              helperText: 'Bulan ini dan maksimal 3 bulan sebelumnya.',
            ),
            items: [
              const DropdownMenuItem(
                value: -1,
                child: Text('Semua bulan tersedia'),
              ),
              for (var offset = 0; offset <= 3; offset++)
                DropdownMenuItem(
                  value: offset,
                  child: Text(
                    MonthlyReportService.monthLabel(
                      DateTime(now.year, now.month - offset),
                    ),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedMonthOffset = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('history-sort-order'),
            initialValue: _sortOrder,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Urutkan berdasarkan',
              prefixIcon: Icon(Icons.sort),
              border: OutlineInputBorder(),
            ),
            items:
                ['Paling mahal', 'Paling murah', 'Paling baru', 'Paling lama']
                    .map(
                      (order) =>
                          DropdownMenuItem(value: order, child: Text(order)),
                    )
                    .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _sortOrder = value);
            },
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
                            '${tx.category} • ${tx.paymentMethod}\nSumber Uang: ${tx.source}\n${tx.formattedTime}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            '${tx.isIncome ? '+' : '-'} ${tx.nominalStr}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: tx.isIncome
                                  ? Colors.green
                                  : Colors.redAccent,
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
