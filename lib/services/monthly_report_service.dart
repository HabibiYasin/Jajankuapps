import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/budget_limits.dart';
import '../models/transaction_model.dart';

class ReportGroup {
  final String name;
  double total = 0;
  int count = 0;
  ReportGroup(this.name);
}

class MonthlyReport {
  final DateTime month;
  final DateTime generatedAt;
  final BudgetLimits limits;
  late final List<TransactionModel> incomes;
  double get incomeTotal => sum(incomes);
  late final List<TransactionModel> transactions;
  late final List<TransactionModel> previous;
  late final List<TransactionModel> comparablePrevious;

  MonthlyReport({
    required List<TransactionModel> history,
    required DateTime month,
    required this.limits,
    DateTime? generatedAt,
  }) : month = DateTime(month.year, month.month),
       generatedAt = generatedAt ?? DateTime.now() {
    incomes =
        history.where((t) => t.isIncome && inMonth(t, this.month)).toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    transactions =
        history.where((t) => !t.isIncome && inMonth(t, this.month)).toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final last = DateTime(month.year, month.month - 1);
    previous = history.where((t) => !t.isIncome && inMonth(t, last)).toList();
    final lastDay = DateTime(last.year, last.month + 1, 0).day;
    comparablePrevious = previous
        .where(
          (t) =>
              !isCurrentMonth ||
              t.dateTime.day <= math.min(this.generatedAt.day, lastDay),
        )
        .toList();
  }

  static bool inMonth(TransactionModel t, DateTime m) =>
      t.dateTime.year == m.year && t.dateTime.month == m.month;
  bool get isCurrentMonth =>
      month.year == generatedAt.year && month.month == generatedAt.month;
  static double sum(Iterable<TransactionModel> rows) =>
      rows.fold(0, (total, t) => total + t.numericNominal);
  double get total => sum(transactions);
  double get tracked => sum(transactions.where(limits.includes));
  double get previousTotal => sum(comparablePrevious);
  double? get changePercent =>
      previousTotal > 0 ? (total - previousTotal) / previousTotal * 100 : null;
  double get usedPercent => tracked / limits.monthly * 100;

  List<ReportGroup> groups({bool merchants = false}) {
    final groups = <String, ReportGroup>{};
    for (final t in transactions) {
      final name = (merchants ? t.merchant : t.category).trim();
      final key = name.toLowerCase();
      final g = groups.putIfAbsent(
        key,
        () => ReportGroup(name.isEmpty ? 'Tidak diketahui' : name),
      );
      g.total += t.numericNominal;
      g.count++;
    }
    return groups.values.toList()..sort((a, b) {
      final result = merchants
          ? b.count.compareTo(a.count)
          : b.total.compareTo(a.total);
      if (result != 0) return result;
      final tie = merchants
          ? b.total.compareTo(a.total)
          : b.count.compareTo(a.count);
      return tie != 0 ? tie : a.name.compareTo(b.name);
    });
  }
}

class MonthlyReportService {
  static const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  static String monthLabel(DateTime date) =>
      '${months[date.month - 1]} ${date.year}';
  static String money(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final integer = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'Rp $integer${parts[1] == '00' ? '' : ',${parts[1]}'}';
  }

  static String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String safe(String s) => s
      .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ')
      .replaceAll(RegExp(r'[^\x20-\x7e\u00a0-\u00ff]'), '?');
  static String short(String s) {
    final cleaned = safe(s);
    return cleaned.length > 90 ? '${cleaned.substring(0, 87)}...' : cleaned;
  }

  static Future<Uint8List> buildPdf({
    required MonthlyReport report,
    required String name,
  }) async {
    final r = report;
    final pdf = pw.Document(
      title: 'Laporan Bulanan Jajanku - ${monthLabel(r.month)}',
      author: safe(name),
    );
    final teal = PdfColor.fromHex('#00796B');
    pw.Widget title(String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: teal,
        ),
      ),
    );
    pw.Widget text(String value) =>
        pw.Text(safe(value), style: const pw.TextStyle(fontSize: 10));
    pw.Widget table(List<String> headers, List<List<String>> rows) =>
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 9,
          ),
          headerDecoration: pw.BoxDecoration(color: teal),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellPadding: const pw.EdgeInsets.all(4),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        );
    pw.Widget header(pw.Context context) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'JAJANKU | LAPORAN PENGELUARAN BULANAN',
          style: pw.TextStyle(
            color: teal,
            fontWeight: pw.FontWeight.bold,
            fontSize: 16,
          ),
        ),
        pw.SizedBox(height: 6),
        text('Nama: ${name.trim().isEmpty ? 'Pengguna Jajanku' : name}'),
        text('Bulan: ${monthLabel(r.month)} | Dibuat: ${date(r.generatedAt)}'),
        pw.Divider(color: teal),
      ],
    );
    pw.Widget footer(pw.Context context) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Jajanku - Dokumen pribadi',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Text(
          'Halaman ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    );
    void page(List<pw.Widget> contents) => pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        maxPages: 1000,
        header: header,
        footer: footer,
        build: (_) => contents,
      ),
    );

    final remaining = math.max(0.0, r.limits.monthly - r.tracked);
    page([
      title('01. Ringkasan dan penggunaan budget'),
      table(
        ['Indikator', 'Nilai'],
        [
          ['Total pemasukan tercatat', money(r.incomeTotal)],
          ['Selisih pemasukan dan pengeluaran', money(r.incomeTotal - r.total)],
          ['Total seluruh pengeluaran', money(r.total)],
          ['Budget bulanan', money(r.limits.monthly)],
          ['Pengeluaran yang mengurangi budget', money(r.tracked)],
          ['Pengeluaran di luar budget', money(r.total - r.tracked)],
          ['Budget terpakai', '${r.usedPercent.toStringAsFixed(1)}%'],
          [
            r.tracked > r.limits.monthly ? 'Kelebihan budget' : 'Sisa budget',
            money((r.limits.monthly - r.tracked).abs()),
          ],
          ['Jumlah transaksi', '${r.transactions.length}'],
          [
            'Rata-rata per transaksi',
            money(r.transactions.isEmpty ? 0 : r.total / r.transactions.length),
          ],
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Row(
        children: [
          pw.SizedBox(
            width: 170,
            height: 150,
            child: pw.Chart(
              grid: pw.PieGrid(),
              datasets: [
                if (r.tracked > 0)
                  pw.PieDataSet(
                    value: math.min(r.tracked, r.limits.monthly),
                    color: teal,
                  ),
                if (remaining > 0)
                  pw.PieDataSet(value: remaining, color: PdfColors.grey300),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                text(
                  'Hijau: budget digunakan (${math.min(r.usedPercent, 100).toStringAsFixed(1)}%)',
                ),
                pw.SizedBox(height: 8),
                text(
                  'Abu-abu: sisa budget (${(remaining / r.limits.monthly * 100).toStringAsFixed(1)}%)',
                ),
                if (r.usedPercent > 100)
                  text(
                    'Penggunaan aktual ${r.usedPercent.toStringAsFixed(1)}%; kelebihan ${money(r.tracked - r.limits.monthly)}.',
                  ),
              ],
            ),
          ),
        ],
      ),
      text('Kategori budget: ${r.limits.trackedCategories.join(', ')}.'),
      title('02. Perbandingan dengan bulan lalu'),
      text(
        r.isCurrentMonth
            ? 'Bulan berjalan: perbandingan sampai tanggal ${r.generatedAt.day}; bulan lalu dibatasi hingga tanggal yang sama atau akhir bulan.'
            : 'Perbandingan total satu bulan penuh.',
      ),
      pw.SizedBox(height: 8),
      table(
        [
          'Indikator',
          monthLabel(DateTime(r.month.year, r.month.month - 1)),
          monthLabel(r.month),
        ],
        [
          [
            'Pengeluaran (periode sebanding)',
            money(r.previousTotal),
            money(r.total),
          ],
          [
            'Jumlah transaksi (periode sebanding)',
            '${r.comparablePrevious.length}',
            '${r.transactions.length}',
          ],
          [
            'Pengeluaran budget (kategori saat ini)',
            money(
              MonthlyReport.sum(r.comparablePrevious.where(r.limits.includes)),
            ),
            money(r.tracked),
          ],
          [
            'Total seluruh bulan',
            money(MonthlyReport.sum(r.previous)),
            money(r.total),
          ],
        ],
      ),
      pw.SizedBox(height: 8),
      text(
        r.changePercent == null
            ? 'Persentase perubahan tidak tersedia karena pengeluaran periode pembanding nol atau belum tercatat.'
            : 'Pengeluaran ${r.changePercent! >= 0 ? 'naik' : 'turun'} ${r.changePercent!.abs().toStringAsFixed(1)}% (${money((r.total - r.previousTotal).abs())}).',
      ),
    ]);

    final categories = r.groups();
    final frequentCategories = List<ReportGroup>.of(categories)
      ..sort((a, b) {
        final result = b.count.compareTo(a.count);
        return result != 0 ? result : b.total.compareTo(a.total);
      });
    final merchants = r.groups(merchants: true);
    final days = <int, List<TransactionModel>>{};
    for (final t in r.transactions) {
      days.putIfAbsent(t.dateTime.day, () => []).add(t);
    }
    page([
      title('03. Tiga kategori dengan pengeluaran terbesar'),
      text(
        'Diurutkan berdasarkan nominal; jumlah transaksi menunjukkan frekuensi pembelian.',
      ),
      pw.SizedBox(height: 8),
      if (categories.isEmpty)
        text('Belum ada transaksi pada bulan ini.')
      else
        table(
          ['Kategori', 'Transaksi', 'Total', '% pengeluaran'],
          categories
              .take(3)
              .map(
                (g) => [
                  short(g.name),
                  '${g.count}',
                  money(g.total),
                  '${(r.total == 0 ? 0 : g.total / r.total * 100).toStringAsFixed(1)}%',
                ],
              )
              .toList(),
        ),
      if (frequentCategories.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        text(
          'Kategori paling sering dibeli: ${frequentCategories.take(3).map((g) => '${short(g.name)} (${g.count} transaksi)').join('; ')}.',
        ),
      ],
      title('04. Toko dengan pembelian terbanyak'),
      text(
        'Diurutkan berdasarkan jumlah transaksi; jika sama, berdasarkan total nominal. Nama toko dikelompokkan tanpa membedakan huruf besar/kecil.',
      ),
      pw.SizedBox(height: 8),
      if (merchants.isEmpty)
        text('Belum ada pembelian.')
      else
        table(
          ['Toko', 'Transaksi', 'Total'],
          merchants
              .take(5)
              .map((g) => [short(g.name), '${g.count}', money(g.total)])
              .toList(),
        ),
      title('05. Rekap pengeluaran per tanggal'),
      table(
        ['Tanggal', 'Transaksi', 'Budget keluar', 'Di luar budget', 'Total'],
        [
          for (final day in days.keys.toList()..sort())
            [
              date(DateTime(r.month.year, r.month.month, day)),
              '${days[day]!.length}',
              money(MonthlyReport.sum(days[day]!.where(r.limits.includes))),
              money(
                MonthlyReport.sum(
                  days[day]!.where((t) => !r.limits.includes(t)),
                ),
              ),
              money(MonthlyReport.sum(days[day]!)),
            ],
          [
            'TOTAL',
            '${r.transactions.length}',
            money(r.tracked),
            money(r.total - r.tracked),
            money(r.total),
          ],
        ],
      ),
    ]);
    page([
      title('06. Rekap metode pembayaran'),
      table(
        ['Metode', 'Transaksi', 'Total'],
        [
          for (final method in TransactionModel.paymentMethods)
            [
              method,
              '${r.transactions.where((t) => t.paymentMethod == method).length}',
              money(
                MonthlyReport.sum(
                  r.transactions.where((t) => t.paymentMethod == method),
                ),
              ),
            ],
        ],
      ),
      title('07. Rincian seluruh transaksi'),
      if (r.transactions.isEmpty)
        text('Tidak ada transaksi tercatat.')
      else
        table(
          [
            'Tanggal / jam',
            'Toko',
            'Kategori / sumber uang / metode',
            'Nominal',
            'Budget',
          ],
          [
            for (final t in r.transactions)
              [
                t.formattedTime,
                short(t.merchant),
                '${short(t.category)} / ${short(t.source)} / ${t.paymentMethod}',
                money(t.numericNominal),
                r.limits.includes(t) ? 'Ya' : 'Tidak',
              ],
          ],
        ),
      if (r.incomes.isNotEmpty) ...[
        title('08. Rincian pemasukan'),
        table(
          [
            'Tanggal / jam',
            'Asal pemasukan',
            'Kategori',
            'Masuk ke',
            'Nominal',
          ],
          [
            for (final t in r.incomes)
              [
                t.formattedTime,
                short(t.merchant),
                short(t.category),
                short(t.source),
                money(t.numericNominal),
              ],
          ],
        ),
      ],
      title('Catatan laporan'),
      text(
        'Selisih hanya dihitung dari pemasukan dan pengeluaran tercatat, bukan saldo rekening. Pemasukan tidak menambah budget bulanan.',
      ),
      text(
        'Laporan menggunakan transaksi yang tercatat di Jajanku, termasuk pengeluaran di luar kategori budget. Hari tanpa transaksi tidak ditampilkan dalam rekap harian.',
      ),
      pw.SizedBox(height: 6),
      text(
        'Budget dan pilihan kategori memakai pengaturan saat laporan dibuat; aplikasi belum menyimpan riwayat perubahan budget setiap bulan. Jumlah transaksi bukan jumlah barang yang dibeli.',
      ),
      if (r.isCurrentMonth)
        text(
          'Laporan bulan berjalan bersifat sementara sampai akhir bulan. Data yang belum dicatat tidak dianggap sebagai pengeluaran.',
        ),
    ]);
    return pdf.save();
  }

  static Future<void> export({
    required MonthlyReport report,
    required String name,
    required Rect shareOrigin,
  }) async {
    final bytes = await buildPdf(report: report, name: name);
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/laporan_jajanku_${report.month.year}_${report.month.month.toString().padLeft(2, '0')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(path).writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/pdf')],
      text: 'Laporan bulanan Jajanku - ${monthLabel(report.month)}',
      sharePositionOrigin: shareOrigin,
    );
  }
}
