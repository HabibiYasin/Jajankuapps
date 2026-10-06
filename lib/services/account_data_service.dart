import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget_limits.dart';
import '../models/transaction_model.dart';
import 'cloud_account_store.dart';
import 'database_helper.dart';

class AccountDataService extends ChangeNotifier {
  static final instance = AccountDataService();
  final FirebaseFirestore? _firestore;
  final String? Function()? _currentUid;
  AccountDataService({this._firestore, this._currentUid});

  CloudAccountStore get _cloud =>
      CloudAccountStore(_firestore ?? FirebaseFirestore.instance);
  String? get _authenticatedUid => _currentUid != null
      ? _currentUid()
      : Firebase.apps.isEmpty
      ? null
      : FirebaseAuth.instance.currentUser?.uid;
  StreamSubscription<User?>? _auth;
  StreamSubscription? _transactions;
  StreamSubscription? _settings;
  int _generation = 0;
  bool _started = false;
  bool _disposed = false;
  bool _txReady = false, _budgetReady = false;
  bool _txPending = false, _budgetPending = false;
  bool _txCached = true, _budgetCached = true;
  int _writes = 0;
  String? uid;
  List<TransactionModel> history = [];
  BudgetLimits limits = const BudgetLimits();
  String? error;
  bool importing = false;

  bool get ready => _txReady && _budgetReady;
  bool get budgetReady => _budgetReady;
  bool get pending => _writes > 0 || _txPending || _budgetPending;
  String get status =>
      error ??
      (uid == null
          ? 'Guest: data tersimpan di HP ini'
          : !ready
          ? 'Memuat data akun…'
          : pending
          ? 'Perubahan menunggu tersimpan ke cloud'
          : _txCached || _budgetCached
          ? 'Menampilkan data lokal; menunggu koneksi cloud'
          : 'Data tersinkron ke cloud');

  void start() {
    if (_started) return;
    _started = true;
    if (Firebase.apps.isEmpty) {
      unawaited(switchAccount(null));
    } else {
      _auth = FirebaseAuth.instance.authStateChanges().listen(
        (user) => unawaited(switchAccount(user?.uid)),
      );
    }
  }

  bool _active(int generation) => !_disposed && generation == _generation;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> switchAccount(String? nextUid) async {
    final generation = ++_generation;
    uid = nextUid;
    history = [];
    limits = const BudgetLimits();
    error = null;
    _txReady = _budgetReady = false;
    _txPending = _budgetPending = false;
    _txCached = _budgetCached = true;
    _writes = 0;
    _emit();
    final previousTransactions = _transactions;
    final previousSettings = _settings;
    _transactions = null;
    _settings = null;
    await previousTransactions?.cancel();
    await previousSettings?.cancel();
    if (!_active(generation)) return;
    if (nextUid == null) {
      await refreshGuest();
      return;
    }
    _transactions = _cloud
        .transactions(nextUid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          if (!_active(generation)) return;
          try {
            history =
                snapshot.docs
                    .map((doc) => CloudAccountStore.decode(nextUid, doc))
                    .toList()
                  ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
            _txReady = true;
            _txPending = snapshot.metadata.hasPendingWrites;
            _txCached = snapshot.metadata.isFromCache;
            _emit();
          } catch (e) {
            _failed(e, generation);
          }
        }, onError: (Object e) => _failed(e, generation));
    _settings = _cloud
        .budget(nextUid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          if (!_active(generation)) return;
          try {
            limits = snapshot.exists
                ? BudgetLimits.fromMap(snapshot.data()!)
                : const BudgetLimits();
            // A missing cached document is not proof that this is a new account.
            _budgetReady = snapshot.exists || !snapshot.metadata.isFromCache;
            _budgetPending = snapshot.metadata.hasPendingWrites;
            _budgetCached = snapshot.metadata.isFromCache;
            _emit();
          } catch (e) {
            _failed(e, generation);
          }
        }, onError: (Object e) => _failed(e, generation));
  }

  void _failed(Object failure, int generation) {
    if (!_active(generation)) return;
    final code = failure is FirebaseException ? failure.code : 'unknown';
    error = 'Sinkronisasi gagal ($code). Periksa koneksi lalu coba lagi.';
    debugPrint('Sinkronisasi akun: $failure');
    _emit();
  }

  Future<void> refreshGuest() async {
    if (uid != null) return;
    final generation = _generation;
    try {
      final data = await DatabaseHelper.instance.fetchTransactions();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('guest_budget_limits');
      final budget = saved == null
          ? const BudgetLimits()
          : BudgetLimits.fromMap(jsonDecode(saved) as Map<String, dynamic>);
      if (!_active(generation)) return;
      history = data;
      limits = budget;
      _txReady = _budgetReady = true;
      _emit();
    } catch (e) {
      _failed(e, generation);
    }
  }

  void _checkOwner(String? expectedUid) {
    if (uid != expectedUid || _authenticatedUid != expectedUid) {
      throw StateError('Akun berubah. Buka ulang halaman sebelum menyimpan.');
    }
  }

  void _queue(Future<void> operation) {
    final generation = _generation;
    _writes++;
    error = null;
    _emit();
    unawaited(
      operation.then(
        (_) {
          if (_active(generation)) {
            _writes--;
            _emit();
          }
        },
        onError: (Object e) {
          if (_active(generation)) {
            _writes--;
            _failed(e, generation);
          }
        },
      ),
    );
  }

  Future<void> insert(
    TransactionModel tx, {
    required String? expectedUid,
  }) async {
    _checkOwner(expectedUid);
    if (expectedUid == null) {
      await DatabaseHelper.instance.insertTransaction(tx);
      await refreshGuest();
    } else {
      _queue(
        _cloud
            .transactions(expectedUid)
            .doc()
            .set(CloudAccountStore.encode(tx)),
      );
    }
  }

  Future<void> delete(TransactionModel tx) async {
    _checkOwner(tx.ownerUid);
    if (tx.ownerUid == null) {
      await DatabaseHelper.instance.deleteTransaction(tx);
      await refreshGuest();
    } else {
      _queue(_cloud.transactions(tx.ownerUid!).doc(tx.cloudId!).delete());
    }
  }

  Future<void> updateDate(TransactionModel tx, DateTime date) async {
    _checkOwner(tx.ownerUid);
    if (tx.ownerUid == null) {
      await DatabaseHelper.instance.updateTransactionDate(tx, date);
      await refreshGuest();
    } else {
      _queue(
        _cloud.transactions(tx.ownerUid!).doc(tx.cloudId!).update({
          'dateTime': Timestamp.fromDate(date),
        }),
      );
    }
  }

  Future<void> updateDetails(TransactionModel tx) async {
    _checkOwner(tx.ownerUid);
    if (tx.ownerUid == null) {
      await DatabaseHelper.instance.updateTransactionFull(tx);
      await refreshGuest();
    } else {
      _queue(
        _cloud.transactions(tx.ownerUid!).doc(tx.cloudId!).update({
          'merchant': tx.merchant,
          'category': tx.category,
          'source': tx.source,
        }),
      );
    }
  }

  Future<void> saveBudget(
    BudgetLimits budget, {
    required String? expectedUid,
  }) async {
    _checkOwner(expectedUid);
    if (!budget.isValid) {
      throw ArgumentError(
        'Pilih kategori yang valid dan isi semua budget dengan angka lebih dari nol.',
      );
    }
    if (expectedUid == null) {
      final prefs = await SharedPreferences.getInstance();
      _checkOwner(expectedUid);
      await prefs.setString('guest_budget_limits', jsonEncode(budget.toMap()));
      await refreshGuest();
    } else {
      limits = BudgetLimits.fromMap(budget.toMap());
      _queue(_cloud.budget(expectedUid).set(budget.toMap()));
    }
  }

  Future<int> importCount() async {
    final owner = uid;
    if (owner == null) return 0;
    return (await DatabaseHelper.instance.importCandidates(owner)).length;
  }

  Future<int> importGuest(String expectedUid) async {
    _checkOwner(expectedUid);
    if (importing) throw StateError('Pemindahan masih berjalan');
    importing = true;
    _emit();
    var count = 0;
    try {
      final rows = await DatabaseHelper.instance.importCandidates(expectedUid);
      for (final row in rows) {
        _checkOwner(expectedUid);
        final id = await DatabaseHelper.instance.claimImport(
          row['id'] as int,
          expectedUid,
          _cloud.transactions(expectedUid).doc().id,
        );
        _checkOwner(expectedUid);
        await _cloud
            .importOnce(
              expectedUid,
              id,
              TransactionModel(
                merchant: row['merchant'] as String,
                nominalStr: row['nominalStr'] as String,
                dateTime: DateTime.parse(row['dateTime'] as String),
                category: row['category'] as String,
                source: (row['source'] as String?) ?? 'QRIS Umum',
                numericNominal: (row['numericNominal'] as num).toDouble(),
              ),
            )
            .timeout(const Duration(seconds: 20));
        // Remove the local copy only after the server confirms the atomic import.
        await DatabaseHelper.instance.finishImport(row['id'] as int);
        count++;
      }
      return count;
    } finally {
      importing = false;
      _emit();
    }
  }

  Future<void> beforeSignOut() async {
    if (importing) throw StateError('Tunggu pemindahan transaksi selesai.');
    if (uid != null) {
      await _cloud.firestore.waitForPendingWrites().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw StateError(
          'Hubungkan internet agar perubahan tersimpan sebelum keluar.',
        ),
      );
    }
  }

  Future<void> retry() => switchAccount(_authenticatedUid);

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _auth?.cancel();
    _transactions?.cancel();
    _settings?.cancel();
    super.dispose();
  }
}
