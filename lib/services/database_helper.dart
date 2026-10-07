import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('qris_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    const int dbVersion = 5;
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: _createDB,
      onUpgrade:
          _upgradeDB, // Menangani penambahan kolom tanpa merusak data lama
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL DEFAULT 'expense',
        merchant TEXT,
        nominalStr TEXT,
        dateTime TEXT,
        category TEXT,
        source TEXT,
        paymentMethod TEXT NOT NULL DEFAULT 'QRIS',
        numericNominal REAL
      )
    ''');
    await _createMigrationTable(db);
  }

  Future<void> _createMigrationTable(Database db) => db.execute('''
    CREATE TABLE cloud_imports (
      localId INTEGER PRIMARY KEY, uid TEXT NOT NULL, cloudId TEXT NOT NULL
    )
  ''');

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE transactions ADD COLUMN source TEXT DEFAULT 'QRIS Umum'",
      );
    }
    if (oldVersion < 3) await _createMigrationTable(db);
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE transactions ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'",
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE transactions ADD COLUMN paymentMethod TEXT NOT NULL DEFAULT 'QRIS'",
      );
    }
  }

  // CREATE: Simpan Transaksi Baru
  Future<int> insertTransaction(TransactionModel tx) async {
    final db = await instance.database;
    return await db.insert('transactions', {
      'type': tx.type,
      'merchant': tx.merchant,
      'nominalStr': tx.nominalStr,
      'dateTime': tx.dateTime.toIso8601String(),
      'category': tx.category,
      'source': tx.source,
      'paymentMethod': tx.paymentMethod,
      'numericNominal': tx.numericNominal,
    });
  }

  // READ: Ambil Semua Riwayat Transaksi
  Future<List<TransactionModel>> fetchTransactions() async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'id NOT IN (SELECT localId FROM cloud_imports)',
      orderBy: 'dateTime DESC',
    );

    return result
        .map(
          (json) => TransactionModel(
            id: json['id'] as int?,
            type: (json['type'] as String?) ?? 'expense',
            merchant: json['merchant'] as String,
            nominalStr: json['nominalStr'] as String,
            dateTime: DateTime.parse(json['dateTime'] as String),
            category: json['category'] as String,
            source: (json['source'] as String?) ?? 'QRIS Umum',
            paymentMethod: (json['paymentMethod'] as String?) ?? 'QRIS',
            numericNominal: json['numericNominal'] as double,
          ),
        )
        .toList();
  }

  // Claims survive crashes and reserve a local row for exactly one account.
  Future<List<Map<String, Object?>>> importCandidates(String uid) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT t.*, c.cloudId FROM transactions t
      LEFT JOIN cloud_imports c ON t.id = c.localId
      WHERE c.uid IS NULL OR c.uid = ?
    ''',
      [uid],
    );
  }

  Future<String> claimImport(int localId, String uid, String cloudId) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.insert('cloud_imports', {
        'localId': localId,
        'uid': uid,
        'cloudId': cloudId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final row = (await txn.query(
        'cloud_imports',
        where: 'localId = ?',
        whereArgs: [localId],
      )).single;
      if (row['uid'] != uid) {
        throw StateError('Transaksi sudah dipilih akun lain');
      }
      return row['cloudId'] as String;
    });
  }

  Future<void> finishImport(int localId) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [localId]);
  }

  // UPDATE: Ubah Tanggal Transaksi
  Future<int> updateTransactionDate(
    TransactionModel tx,
    DateTime newDate,
  ) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {'dateTime': newDate.toIso8601String()},
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  // UPDATE FULL: Ubah Merchant, Source, Category dari form Edit
  Future<int> updateTransactionFull(TransactionModel tx) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {
        'merchant': tx.merchant,
        'category': tx.category,
        'source': tx.source,
        'paymentMethod': tx.paymentMethod,
      },
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  // DELETE: Hapus Transaksi
  Future<int> deleteTransaction(TransactionModel tx) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [tx.id]);
  }
}
