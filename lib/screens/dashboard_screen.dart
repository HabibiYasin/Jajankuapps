import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction_model.dart';
import 'top_categories_widget.dart';
import '../widgets/tutorial_dialog.dart';
import '../theme/app_theme.dart';
import '../models/spending_progress.dart';
import 'spending_progress_screen.dart';

class DashboardScreen extends StatefulWidget {
  final List<TransactionModel> history;
  final double dailyLimit;
  final double monthlyLimit;

  const DashboardScreen({
    super.key,
    required this.history,
    required this.dailyLimit,
    required this.monthlyLimit,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Menjalankan pengecekan popup tutorial setelah frame pertama selesai dirender
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorialPopup();
    });
  }

  Future<void> _checkAndShowTutorialPopup() async {
    final prefs = await SharedPreferences.getInstance();

    // Jangan tampilkan lagi pada hari yang sama jika pengguna memilih opsi ini.
    String? lastHiddenDate = prefs.getString('tutorial_hidden_date');
    if (lastHiddenDate != null) {
      DateTime hideDate = DateTime.parse(lastHiddenDate);
      DateTime now = DateTime.now();

      if (now.year == hideDate.year &&
          now.month == hideDate.month &&
          now.day == hideDate.day) {
        return;
      }
    }

    // Beri jarak minimal 10 menit antar-popup otomatis, termasuk setelah
    // aplikasi ditutup lalu dibuka kembali.
    final lastShownValue = prefs.getString('tutorial_last_shown_at');
    final lastShown = lastShownValue == null
        ? null
        : DateTime.tryParse(lastShownValue);
    final now = DateTime.now();
    if (lastShown != null &&
        now.difference(lastShown) < const Duration(minutes: 10)) {
      return;
    }

    await prefs.setString('tutorial_last_shown_at', now.toIso8601String());
    if (!mounted) return;
    await showTutorialDialog(context, allowHideToday: true);
  }

  double _calculateTotal(DateTime period, {bool monthly = false}) {
    return widget.history
        .where((tx) {
          final date = tx.dateTime;
          return date.year == period.year &&
              date.month == period.month &&
              (monthly || date.day == period.day);
        })
        .fold(0.0, (total, tx) => total + tx.numericNominal);
  }

  String _formatAmount(double amount) {
    if (amount.abs() < 1000) return amount.toStringAsFixed(0);
    final thousands = (amount / 1000)
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.?0+$'), '');
    return '${thousands.replaceAll('.', ',')}K';
  }

  String _getMonthName(int monthNumber) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return months[monthNumber - 1];
  }

  String _getShortDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Sen';
      case 2:
        return 'Sel';
      case 3:
        return 'Rab';
      case 4:
        return 'Kam';
      case 5:
        return 'Jum';
      case 6:
        return 'Sab';
      case 7:
        return 'Min';
      default:
        return '';
    }
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required double total,
    required double budget,
    required IconData icon,
    required Color accent,
    required DateTime periodDate,
    bool monthly = false,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Lihat dan bagikan progres $label',
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SpendingProgressScreen(
                progress: SpendingProgress(
                  period: monthly
                      ? (label.startsWith('Bulan Kemarin')
                            ? 'Bulan Kemarin'
                            : 'Bulan Ini')
                      : label,
                  date: periodDate,
                  monthly: monthly,
                  spent: total,
                  budget: budget,
                ),
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.charcoal.withValues(alpha: 0.07),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Maks. budget: Rp${_formatAmount(budget)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ketuk untuk bagikan',
                  style: TextStyle(fontSize: 10, color: AppColors.teal),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: budget > 0 ? (total / budget).clamp(0.0, 1.0) : 0.0,
                    minHeight: 6,
                    backgroundColor: AppColors.mist.withValues(alpha: 0.3),
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChartBars() {
    List<Widget> bars = [];
    DateTime now = DateTime.now();
    double maxVal = 1.0;
    List<double> dailyTotals = [];
    for (int i = 6; i >= 0; i--) {
      DateTime targetDay = now.subtract(Duration(days: i));
      double dailyTotal = 0;
      for (var tx in widget.history) {
        if (tx.dateTime.year == targetDay.year &&
            tx.dateTime.month == targetDay.month &&
            tx.dateTime.day == targetDay.day) {
          dailyTotal += tx.numericNominal;
        }
      }
      dailyTotals.add(dailyTotal);
      if (dailyTotal > maxVal) maxVal = dailyTotal;
    }
    for (int i = 0; i < 7; i++) {
      DateTime targetDay = now.subtract(Duration(days: 6 - i));
      double t = dailyTotals[i];
      double barHeight = (t / maxVal) * 90;
      if (barHeight < 4) barHeight = 4;
      bool isToday = (i == 6);
      bars.add(
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (t > 0)
              Text(
                _formatAmount(t),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            const SizedBox(height: 6),
            Container(
              width: 24,
              height: barHeight,
              decoration: BoxDecoration(
                color: isToday ? Colors.teal : Colors.teal[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getShortDayName(targetDay.weekday),
              style: TextStyle(
                fontSize: 11,
                color: isToday ? Colors.teal : Colors.grey,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }
    return bars;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final lastMonth = DateTime(now.year, now.month - 1);
    final currentDaily = _calculateTotal(now);
    final yesterdayTotal = _calculateTotal(yesterday);
    final currentMonthly = _calculateTotal(now, monthly: true);
    final lastMonthly = _calculateTotal(lastMonth, monthly: true);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildSummaryCard(
                label: 'Hari Ini',
                periodDate: now,
                value: 'Rp${_formatAmount(currentDaily)}',
                total: currentDaily,
                budget: widget.dailyLimit,
                icon: Icons.today_rounded,
                accent: currentDaily >= widget.dailyLimit
                    ? AppColors.pink
                    : AppColors.teal,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                label: 'Kemarin',
                periodDate: yesterday,
                value: 'Rp${_formatAmount(yesterdayTotal)}',
                total: yesterdayTotal,
                budget: widget.dailyLimit,
                icon: Icons.history_rounded,
                accent: yesterdayTotal >= widget.dailyLimit
                    ? AppColors.pink
                    : AppColors.teal,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryCard(
                label: 'Bulan Kemarin (${_getMonthName(lastMonth.month)})',
                periodDate: lastMonth,
                monthly: true,
                value: 'Rp${_formatAmount(lastMonthly)}',
                total: lastMonthly,
                budget: widget.monthlyLimit,
                icon: Icons.calendar_month_rounded,
                accent: lastMonthly >= widget.monthlyLimit
                    ? AppColors.pink
                    : AppColors.aqua,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                label: 'Bulan Ini (${_getMonthName(now.month)})',
                periodDate: now,
                monthly: true,
                value: 'Rp${_formatAmount(currentMonthly)}',
                total: currentMonthly,
                budget: widget.monthlyLimit,
                icon: Icons.calendar_month_rounded,
                accent: currentMonthly >= widget.monthlyLimit
                    ? AppColors.pink
                    : AppColors.aqua,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Statistik Belanja (7 Hari Terakhir)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            height: 190,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _buildChartBars(),
            ),
          ),
          const SizedBox(height: 24),

          TopCategoriesWidget(history: widget.history),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
