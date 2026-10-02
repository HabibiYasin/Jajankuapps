import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../theme/app_theme.dart';

class TopCategoriesWidget extends StatelessWidget {
  final List<TransactionModel> history;

  const TopCategoriesWidget({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    // 1. Filter transaksi hanya untuk bulan ini
    final now = DateTime.now();
    final currentMonthTransactions = history.where((tx) {
      return tx.dateTime.year == now.year && tx.dateTime.month == now.month;
    }).toList();

    // 2. Agregasi total nominal per kategori
    final Map<String, double> categoryTotals = {};
    for (var tx in currentMonthTransactions) {
      categoryTotals[tx.category] =
          (categoryTotals[tx.category] ?? 0.0) + tx.numericNominal;
    }

    // 3. Urutkan dari yang terbesar
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Ambil Top 3 saja
    final top3 = sortedCategories.take(3).toList();

    if (top3.isEmpty) {
      const card = Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Belum ada pengeluaran di bulan ini.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
      return card;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top 3 Kategori Bulan Ini',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...top3.asMap().entries.map((entry) {
          int index = entry.key;
          var category = entry.value.key;
          var total = entry.value.value;

          // Warna badge ranking
          Color badgeColor;
          if (index == 0) {
            badgeColor = Colors.amber.shade700;
          } else if (index == 1) {
            badgeColor = AppColors.teal;
          } else {
            badgeColor = AppColors.pink;
          }

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: badgeColor,
                child: Text(
                  '#${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                category,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Total: Rp${total.toStringAsFixed(0)}'),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              onTap: () {
                // Saat diklik, tampilkan detail transaksi untuk kategori ini
                _showCategoryDetail(
                  context,
                  category,
                  currentMonthTransactions,
                );
              },
            ),
          );
        }),
      ],
    );
  }

  // Fungsi untuk menampilkan Popup Detail Transaksi Berdasarkan Kategori yang diklik
  void _showCategoryDetail(
    BuildContext context,
    String category,
    List<TransactionModel> transactions,
  ) {
    final filtered = transactions
        .where((tx) => tx.category == category)
        .toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detail Kategori: $category',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.teal,
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final tx = filtered[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        tx.merchant,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${tx.dateTime.day}/${tx.dateTime.month}/${tx.dateTime.year}',
                      ),
                      trailing: Text(
                        tx.nominalStr,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
