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
    const int dbVersion = 1; // Mendefinisikan versi database secara eksplisit
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: dbVersion, 
      onCreate: _createDB
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
        numericNominal REAL
      )
    ''');
  }

  // CREATE: Simpan Transaksi Baru
  Future<int> insertTransaction(TransactionModel tx) async {
    final db = await instance.database;
    return await db.insert('transactions', {
      'merchant': tx.merchant,
      'nominalStr': tx.nominalStr,
      'dateTime': tx.dateTime.toIso8601String(),
      'category': tx.category,
      'numericNominal': tx.numericNominal,
    });
  }

  // READ: Ambil Semua Riwayat Transaksi
  Future<List<TransactionModel>> fetchTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'dateTime DESC');

    return result.map((json) => TransactionModel(
      merchant: json['merchant'] as String,
      nominalStr: json['nominalStr'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      category: json['category'] as String,
      numericNominal: json['numericNominal'] as double,
    )).toList();
  }

  // UPDATE: Ubah Tanggal Transaksi Berdasarkan ID / Index
  Future<int> updateTransactionDate(TransactionModel tx, DateTime newDate) async {
    final db = await instance.database;
    // Untuk simplifikasi MVP, kita update berdasarkan kesamaan merchant & timestamp lama
    return await db.update(
      'transactions',
      {'dateTime': newDate.toIso8601String()},
      where: 'merchant = ? AND nominalStr = ?',
      whereArgs: [tx.merchant, tx.nominalStr],
    );
  }

  // DELETE: Hapus Transaksi
  Future<int> deleteTransaction(TransactionModel tx) async {
    final db = await instance.database;
    return await db.delete(
      'transactions',
      where: 'merchant = ? AND nominalStr = ? AND dateTime = ?',
      whereArgs: [tx.merchant, tx.nominalStr, tx.dateTime.toIso8601String()],
    );
  }
}