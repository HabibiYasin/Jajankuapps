import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'models/transaction_model.dart';
import 'services/ocr_service.dart';
import 'services/account_data_service.dart';
import 'services/budget_notification_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'widgets/expense_floating_menu.dart';
import 'screens/manual_expense_screen.dart';
import 'screens/personalization_screen.dart';
import 'theme/app_theme.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    debugPrint('Firebase gagal diinisialisasi: $error');
  }

  runApp(
    MaterialApp(
      title: 'Jajanku',
      theme: AppTheme.light,
      home: const QrisTrackerApp(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class QrisTrackerApp extends StatefulWidget {
  const QrisTrackerApp({super.key});
  @override
  State<QrisTrackerApp> createState() => _QrisTrackerAppState();
}

class _QrisTrackerAppState extends State<QrisTrackerApp>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  final String _userName = "Guest";
  final _accountData = AccountDataService.instance;
  String? _visibleUid;
  double get _dailyBudgetLimit => _accountData.limits.daily;
  double get _weeklyBudgetLimit => _accountData.limits.weekly;
  double get _monthlyBudgetLimit => _accountData.limits.monthly;

  List<TransactionModel> _transactionHistory = [];
  final _picker = ImagePicker();
  bool _isLoading = false;

  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _accountData.addListener(_applyAccountData);
    _accountData.start();

    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (value) {
            if (value.isNotEmpty) {
              String sharedPath = value.first.path;
              _processSharedImageFile(File(sharedPath));
            }
          },
          onError: (err) {
            debugPrint("Error get shared media stream: $err");
          },
        );

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        String sharedPath = value.first.path;
        _processSharedImageFile(File(sharedPath));
      }
      ReceiveSharingIntent.instance.reset();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accountData.removeListener(_applyAccountData);
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadTransactionsFromDB() async {
    await _accountData.refreshGuest();
    _applyAccountData();
  }

  void _applyAccountData() {
    if (!mounted) return;
    setState(() {
      if (_visibleUid != _accountData.uid) {
        _visibleUid = _accountData.uid;
      }
      _transactionHistory = _accountData.history;
    });
    unawaited(
      BudgetNotificationService.sync(_transactionHistory, _dailyBudgetLimit),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTransactionsFromDB();
    }
  }

  Future<void> _processSharedImageFile(File imageFile) async {
    final owner = _accountData.uid;
    try {
      setState(() {
        _isLoading = true;
      });

      final tx = await OcrService.processImage(imageFile);
      if (tx.numericNominal <= 0 || !tx.numericNominal.isFinite) {
        throw const FormatException(
          'Nominal tidak terbaca. Coba gambar yang lebih jelas atau Catat Manual.',
        );
      }

      await _accountData.insert(tx, expectedUid: owner);
      await _loadTransactionsFromDB();

      if (!mounted) return;
      setState(() {
        _selectedIndex = 1;
        _isLoading = false;
      });

      _checkDailyBudget();
      if (tx.category == 'Umum' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kategori belum pasti. Pilih kategori melalui Riwayat → Edit Detail.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal memproses file: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null || !mounted) return;
      await _processSharedImageFile(File(pickedFile.path));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka kamera atau galeri: $error')),
      );
    }
  }

  Future<void> _recordManualExpense() async {
    final owner = _accountData.uid;
    final tx = await Navigator.of(context).push<TransactionModel>(
      MaterialPageRoute(builder: (_) => const ManualExpenseScreen()),
    );
    if (tx == null || !mounted || owner != _accountData.uid) return;
    setState(() => _isLoading = true);
    try {
      await _accountData.insert(tx, expectedUid: owner);
      await _loadTransactionsFromDB();
      if (!mounted || owner != _accountData.uid) return;
      setState(() => _selectedIndex = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengeluaran berhasil disimpan.')),
      );
      _checkDailyBudget();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan pengeluaran: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performEdit(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Perubahan gagal: $error')));
      }
    }
  }

  void _checkDailyBudget() {
    double totalToday = 0;
    DateTime now = DateTime.now();
    for (var tx in _transactionHistory) {
      if (tx.dateTime.year == now.year &&
          tx.dateTime.month == now.month &&
          tx.dateTime.day == now.day) {
        totalToday += tx.numericNominal;
      }
    }
    if (totalToday > _dailyBudgetLimit) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Budget Habis!'),
            ],
          ),
          content: Text(
            'Pengeluaran harian mencapai Rp${totalToday.toStringAsFixed(0)}.\nBatas: Rp${_dailyBudgetLimit.toStringAsFixed(0)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jajanku',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            Text(
              'Catat jajan, lebih tenang',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.charcoal, AppColors.teal],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(
            key: ValueKey(_accountData.uid),
            history: _transactionHistory,
            dailyLimit: _dailyBudgetLimit,
            monthlyLimit: _monthlyBudgetLimit,
          ),
          TransactionHistoryScreen(
            key: ValueKey('history-${_accountData.uid}'),
            history: _transactionHistory,
            onDelete: (tx) => _performEdit(() => _accountData.delete(tx)),
            onUpdateDate: (tx, newDate) =>
                _performEdit(() => _accountData.updateDate(tx, newDate)),
            onUpdateTransaction: (tx) =>
                _performEdit(() => _accountData.updateDetails(tx)),
          ),
          PersonalizationScreen(
            userName: _userName,
            dailyLimit: _dailyBudgetLimit,
            weeklyLimit: _weeklyBudgetLimit,
            monthlyLimit: _monthlyBudgetLimit,
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? ExpenseFloatingMenu(
              onManualEntry: _recordManualExpense,
              onGallery: () => _processImage(ImageSource.gallery),
              onCamera: () => _processImage(ImageSource.camera),
            )
          : null,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.charcoal.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_rounded),
                selectedIcon: Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.teal,
                ),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long, color: AppColors.teal),
                label: 'Riwayat',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_rounded),
                selectedIcon: Icon(Icons.tune_rounded, color: AppColors.teal),
                label: 'Personalisasi',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
