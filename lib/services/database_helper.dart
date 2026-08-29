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
    const int dbVersion = 2; // Naikkan versi ke 2 untuk menambahkan kolom 'source'
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: dbVersion, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB, // Menangani penambahan kolom tanpa merusak data lama
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant TEXT,
        nominalStr TEXT,
        dateTime TEXT,
        category TEXT,
        source TEXT,
        numericNominal REAL
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE transactions ADD COLUMN source TEXT DEFAULT 'QRIS Umum'");
    }
  }

  // CREATE: Simpan Transaksi Baru
  Future<int> insertTransaction(TransactionModel tx) async {
    final db = await instance.database;
    return await db.insert('transactions', {
      'merchant': tx.merchant,
      'nominalStr': tx.nominalStr,
      'dateTime': tx.dateTime.toIso8601String(),
      'category': tx.category,
      'source': tx.source,
      'numericNominal': tx.numericNominal,
    });
  }

  // READ: Ambil Semua Riwayat Transaksi
  Future<List<TransactionModel>> fetchTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'dateTime DESC');

    return result.map((json) => TransactionModel(
      id: json['id'] as int?,
      merchant: json['merchant'] as String,
      nominalStr: json['nominalStr'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      category: json['category'] as String,
      source: (json['source'] as String?) ?? 'QRIS Umum',
      numericNominal: json['numericNominal'] as double,
    )).toList();
  }

  // UPDATE: Ubah Tanggal Transaksi 
  Future<int> updateTransactionDate(TransactionModel tx, DateTime newDate) async {
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
      },
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  // DELETE: Hapus Transaksi
  Future<int> deleteTransaction(TransactionModel tx) async {
    final db = await instance.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }
}