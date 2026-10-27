import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor, SystemUiOverlayStyle;
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'models/transaction_model.dart';
import 'models/budget_totals.dart';
import 'services/ocr_service.dart';
import 'services/account_data_service.dart';
import 'services/profile_plan_store.dart';
import 'services/premium_billing_service.dart';
import 'services/auth_service.dart';
import 'services/app_activity_service.dart';
import 'services/manual_tour.dart';
import 'services/app_update_service.dart';
import 'widgets/app_update_gate.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/budget_notification_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'screens/income_screen.dart';
import 'widgets/expense_floating_menu.dart';
import 'screens/manual_expense_screen.dart';
import 'screens/login_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/personalization_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/budget_settings_screen.dart';
import 'theme/app_theme.dart';

import 'config/app_environment.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JajankuStartup());
}

Future<SharedPreferences> _initializeApp() async {
  final environment = AppEnvironment.current;
  try {
    await Firebase.initializeApp(options: environment.firebaseOptions);
  } catch (error) {
    debugPrint('Firebase gagal diinisialisasi: $error');
  }

  final activityPreferences = await SharedPreferences.getInstance();
  await AppActivityService.recordLocalOpen(activityPreferences);
  final user = AuthService.instance.currentUser;
  if (user != null) {
    try {
      await AuthService.instance
          .syncProfile(user)
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Profil akun belum tersinkron: $error');
    }
  }

  return SharedPreferences.getInstance();
}

class JajankuStartup extends StatefulWidget {
  const JajankuStartup({super.key});

  @override
  State<JajankuStartup> createState() => _JajankuStartupState();
}

class _JajankuStartupState extends State<JajankuStartup> {
  late final Future<SharedPreferences> _initialization = _initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return JajankuApp(preferences: snapshot.data!);
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: snapshot.hasError
              ? const Scaffold(
                  body: Center(
                    child: Text('Gagal membuka aplikasi. Coba buka kembali.'),
                  ),
                )
              : const SplashScreen(),
        );
      },
    );
  }
}

class JajankuApp extends StatefulWidget {
  const JajankuApp({super.key, required this.preferences});

  final SharedPreferences preferences;

  @override
  State<JajankuApp> createState() => _JajankuAppState();
}

class _JajankuAppState extends State<JajankuApp> {
  late bool _isDark = widget.preferences.getBool('dark_mode') ?? false;

  Future<void> _toggleTheme() async {
    setState(() => _isDark = !_isDark);
    await widget.preferences.setBool('dark_mode', _isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appFlavor == 'dev' ? 'Jajanku (Dev)' : 'Jajanku',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => AppUpdateGate(
        packageName: appFlavor == 'dev'
            ? 'com.jajanku.app.dev'
            : 'com.jajanku.app',
        checkForUpdate: () => AppUpdateService.checkCurrent(widget.preferences),
        child: child ?? const SizedBox.shrink(),
      ),
      home: QrisTrackerApp(onToggleTheme: _toggleTheme),
      debugShowCheckedModeBanner: false,
    );
  }
}

class QrisTrackerApp extends StatefulWidget {
  const QrisTrackerApp({super.key, this.onToggleTheme});

  final VoidCallback? onToggleTheme;
  @override
  State<QrisTrackerApp> createState() => _QrisTrackerAppState();
}

class _QrisTrackerAppState extends State<QrisTrackerApp>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  final String _userName = "Guest";
  final _accountData = AccountDataService.instance;
  String? _visibleUid;
  bool _isPremium = false;
  StreamSubscription<bool>? _planSubscription;
  Timer? _budgetDayTimer;
  double get _dailyBudgetLimit =>
      _accountData.limits.dailyFor(DateTime.now(), _transactionHistory);
  double get _weeklyBudgetLimit =>
      _accountData.limits.weeklyFor(DateTime.now(), _transactionHistory);
  double get _monthlyBudgetLimit => _accountData.limits.monthly;

  List<TransactionModel> _transactionHistory = [];
  final _picker = ImagePicker();
  bool _isLoading = false;
  File? _pendingSharedImage;
  final Set<VoidCallback> _setupWaiters = {};

  late StreamSubscription _intentDataStreamSubscription;

  final _tour = ManualTour.instance;
  final _tutorialExamples = <TransactionModel>{};
  void _refreshTour() {
    if (mounted) setState(() {});
  }

  void _startTour() {
    if (mounted) setState(() => _selectedIndex = 0);
  }

  @override
  void initState() {
    super.initState();
    _tour.onStart = _startTour;
    _tour.addListener(_refreshTour);
    WidgetsBinding.instance.addObserver(this);
    PremiumBillingService.instance.start();
    _accountData.addListener(_applyAccountData);
    _accountData.start();
    _applyAccountData();
    _scheduleBudgetDayRefresh();

    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (value) {
            if (value.isNotEmpty) {
              String sharedPath = value.first.path;
              _pendingSharedImage = File(sharedPath);
              _consumeSharedImage();
            }
          },
          onError: (err) {
            debugPrint("Error get shared media stream: $err");
          },
        );

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (!mounted) return;
      if (value.isNotEmpty) {
        String sharedPath = value.first.path;
        _pendingSharedImage = File(sharedPath);
        _consumeSharedImage();
      }
      ReceiveSharingIntent.instance.reset();
    });
  }

  @override
  void dispose() {
    _budgetDayTimer?.cancel();
    _tour.removeListener(_refreshTour);
    _tour.onStart = null;
    _tour.stop();
    WidgetsBinding.instance.removeObserver(this);
    _accountData.removeListener(_applyAccountData);
    _planSubscription?.cancel();
    _intentDataStreamSubscription.cancel();
    for (final finish in _setupWaiters.toList()) {
      finish();
    }
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
        _selectedIndex = 0;
        _watchPlan(_visibleUid);
      }
      _transactionHistory = _accountData.history;
    });
    _consumeSharedImage();
    unawaited(
      BudgetNotificationService.sync(
        _accountData.limits.tracked(_transactionHistory),
        _dailyBudgetLimit,
        budget: _accountData.limits,
      ),
    );
  }

  void _scheduleBudgetDayRefresh() {
    _budgetDayTimer?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _budgetDayTimer = Timer(next.difference(now), () {
      if (!mounted) return;
      _applyAccountData();
      _scheduleBudgetDayRefresh();
    });
  }

  void _watchPlan(String? uid) {
    _planSubscription?.cancel();
    _planSubscription = null;
    _isPremium = false;
    if (uid == null) return;
    _planSubscription = ProfilePlanStore(FirebaseFirestore.instance)
        .watchVip(uid)
        .listen(
          (premium) {
            if (!mounted || _accountData.uid != uid) return;
            setState(() => _isPremium = premium);
          },
          onError: (Object error) {
            if (!mounted || _accountData.uid != uid) return;
            setState(() => _isPremium = false);
            debugPrint('Gagal memuat paket akun: $error');
          },
        );
  }

  void _consumeSharedImage() {
    if (!mounted ||
        AuthService.instance.currentUser == null ||
        AuthService.needsEmailVerification(AuthService.instance.currentUser) ||
        !_accountData.budgetReady ||
        (_accountData.uid != null && !_accountData.limits.isConfigured) ||
        _pendingSharedImage == null) {
      return;
    }
    final image = _pendingSharedImage!;
    _pendingSharedImage = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_processSharedImageFile(image));
    });
  }

  Future<bool> _awaitBudgetSetup() async {
    final owner = _accountData.uid;
    final result = Completer<bool>();
    late final VoidCallback check;
    late final VoidCallback cancel;
    void finish(bool allowed) {
      if (result.isCompleted) return;
      _accountData.removeListener(check);
      _setupWaiters.remove(cancel);
      result.complete(allowed);
    }

    check = () {
      if (!mounted || owner != _accountData.uid || _accountData.error != null) {
        finish(false);
      } else if (_accountData.budgetReady &&
          (_accountData.uid == null || _accountData.limits.isConfigured)) {
        finish(true);
      }
    };
    cancel = () => finish(false);
    _setupWaiters.add(cancel);
    _accountData.addListener(check);
    check();
    return result.future;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleBudgetDayRefresh();
      _loadTransactionsFromDB();
      unawaited(_recordAppOpen());
    }
  }

  Future<void> _recordAppOpen() async {
    try {
      await AppActivityService.recordLocalOpen(
        await SharedPreferences.getInstance(),
      );
      final user = AuthService.instance.currentUser;
      if (user != null && !AuthService.needsEmailVerification(user)) {
        await AppActivityService.recordCloudOpen(
          FirebaseFirestore.instance,
          user.uid,
        );
      }
    } catch (error) {
      debugPrint('Aktivitas aplikasi belum tersinkron: $error');
    }
  }

  Future<void> _processSharedImageFile(File imageFile) async {
    if (!await requireLogin(context) || !mounted) return;
    if (!await _awaitBudgetSetup() || !mounted) return;
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
    if (!await requireLogin(context) || !mounted) return;
    if (!await _awaitBudgetSetup() || !mounted) return;
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

  Future<void> _recordManualExpense({bool isIncome = false}) async {
    if (!await requireLogin(context) || !mounted) return;
    if (!await _awaitBudgetSetup() || !mounted) return;
    final tutorial = _tour.active && !isIncome;
    final owner = _accountData.uid;
    final tx = await Navigator.of(context).push<TransactionModel>(
      MaterialPageRoute(
        builder: (_) => ManualExpenseScreen(
          isIncome: isIncome,
          tutorial: _tour.active && !isIncome,
        ),
      ),
    );
    if (tx == null || !mounted || owner != _accountData.uid) return;
    if (tutorial) {
      if (_tour.active) {
        _tutorialExamples.add(tx);
        _tour.example = tx;
        _tour.go(ManualTourStep.today);
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _accountData.insert(tx, expectedUid: owner);
      await _loadTransactionsFromDB();
      if (!mounted || owner != _accountData.uid) return;
      setState(() => _selectedIndex = isIncome ? 2 : 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isIncome
                ? 'Pemasukan berhasil disimpan.'
                : 'Pengeluaran berhasil disimpan.',
          ),
        ),
      );
      if (!isIncome) _checkDailyBudget();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan transaksi: $error')),
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

  Future<void> Function(List<TransactionModel>, String) _sheetImporter(
    String? uid,
  ) =>
      (transactions, revision) => _accountData.replaceTransactions(
        transactions,
        expectedUid: uid,
        expectedRevision: revision,
      );

  void _checkDailyBudget() {
    final totalToday = BudgetTotals.forPeriod(
      _transactionHistory,
      _accountData.limits.trackedCategories,
      DateTime.now(),
    ).tracked;
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
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const LoginScreen(popOnLogin: false);
    }
    if (AuthService.needsEmailVerification(user)) {
      return const EmailVerificationScreen();
    }
    if (!_accountData.budgetReady) {
      if (_accountData.error != null) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_accountData.status, textAlign: TextAlign.center),
                FilledButton(
                  onPressed: _accountData.retry,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        );
      }
      return const SplashScreen();
    }
    if (_accountData.uid != null && !_accountData.limits.isConfigured) {
      return BudgetSettingsScreen(
        key: ValueKey('setup-${_accountData.uid}'),
        onboarding: true,
        dailyLimit: _dailyBudgetLimit,
        weeklyLimit: _weeklyBudgetLimit,
        monthlyLimit: _monthlyBudgetLimit,
        categories: _accountData.limits.trackedCategories,
        mode: _accountData.limits.mode,
      );
    }
    if (_isLoading) {
      return const SplashScreen();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        toolbarHeight: 72,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appFlavor == 'dev' ? 'Jajanku (Dev)' : 'Jajanku',
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
            child: IconButton.filledTonal(
              onPressed: widget.onToggleTheme,
              tooltip: Theme.of(context).brightness == Brightness.dark
                  ? 'Aktifkan mode terang'
                  : 'Aktifkan mode gelap',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                foregroundColor: Colors.white,
              ),
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(
            isPremium: _isPremium,
            key: ValueKey(_accountData.uid),
            history: _transactionHistory,
            dailyLimit: _dailyBudgetLimit,
            monthlyLimit: _monthlyBudgetLimit,
            budgetCategories: _accountData.limits.trackedCategories,
            budgetLimits: _accountData.limits,
          ),
          TransactionHistoryScreen(
            isPremium: _isPremium,
            key: ValueKey('history-${_accountData.uid}-${_tour.active}'),
            history: [
              if (_tour.example != null) _tour.example!,
              ..._transactionHistory,
            ],
            importRevision: _accountData.transactionRevision,
            onImportTransactions: _sheetImporter(_accountData.uid),
            budgetLimits: _accountData.limits,
            userName:
                AuthService.instance.currentUser?.displayName ?? _userName,
            onDelete: (tx) async {
              if (_tutorialExamples.contains(tx)) {
                _tour.stop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Selesai! Kamu sudah belajar tambah, edit, dan hapus.',
                    ),
                  ),
                );
                return;
              }
              return _performEdit(() => _accountData.delete(tx));
            },
            onUpdateDate: (tx, newDate) async {
              if (_tutorialExamples.contains(tx)) {
                tx.dateTime = newDate;
                return;
              }
              return _performEdit(() => _accountData.updateDate(tx, newDate));
            },
            onUpdateTransaction: (tx) async {
              if (_tutorialExamples.contains(tx)) {
                _tour.go(ManualTourStep.delete);
                return;
              }
              return _performEdit(() => _accountData.updateDetails(tx));
            },
          ),
          IncomeScreen(
            isPremium: _isPremium,
            key: ValueKey('income-${_accountData.uid}'),
            history: _transactionHistory,
            onAddIncome: () => _recordManualExpense(isIncome: true),
            onDelete: (tx) => _performEdit(() => _accountData.delete(tx)),
            onUpdateDate: (tx, date) =>
                _performEdit(() => _accountData.updateDate(tx, date)),
            onUpdateTransaction: (tx) =>
                _performEdit(() => _accountData.updateDetails(tx)),
          ),
          PersonalizationScreen(
            loggedInTier: _isPremium ? UserTier.premium : UserTier.free,
            userName: _userName,
            dailyLimit: _dailyBudgetLimit,
            weeklyLimit: _weeklyBudgetLimit,
            monthlyLimit: _monthlyBudgetLimit,
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? ExpenseFloatingMenu(
              key: ValueKey('expense-menu-${_tour.active}'),
              onManualEntry: _recordManualExpense,
              onGallery: () => _processImage(ImageSource.gallery),
              onCamera: () => _processImage(ImageSource.camera),
            )
          : null,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
              if (_tour.step == ManualTourStep.history && index == 1) {
                _tour.go(ManualTourStep.transaction);
              }
            },
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.grid_view_rounded),
                selectedIcon: Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.teal,
                ),
                label: 'Dashboard',
              ),
              NavigationDestination(
                key: _tour.key('history'),
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long, color: AppColors.teal),
                label: 'Riwayat',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.teal,
                ),
                label: 'Pemasukan',
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
