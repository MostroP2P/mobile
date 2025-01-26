import 'dart:async';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mostro_mobile/data/models/order.dart';

class OrderRepositoryEncrypted implements OrderRepository<Order> {
  static const _dbName = 'orders_encrypted.db';
  static const _dbVersion = 1;
  static const _tableName = 'orders';

  final String _dbPassword;

  Database? _database;

  OrderRepositoryEncrypted({required String dbPassword})
      : _dbPassword = dbPassword;

  /// Return the single instance of Database, opening if needed
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the encrypted database
  Future<Database> _initDatabase() async {
    final docDir = await getDatabasesPath();
    final dbPath = join(docDir, _dbName);

    return await openDatabase(
      dbPath,
      password: _dbPassword,
      version: _dbVersion,
      onCreate: _onCreate,
      // onUpgrade: _onUpgrade if needed
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create table with all columns from the Order model
    // id is primary key, so if you don't expect collisions, use that
    await db.execute('''
    CREATE TABLE $_tableName (
      id TEXT PRIMARY KEY,
      kind TEXT,
      status TEXT,
      amount INTEGER,
      fiatCode TEXT,
      minAmount INTEGER,
      maxAmount INTEGER,
      fiatAmount INTEGER,
      paymentMethod TEXT,
      premium INTEGER,
      masterBuyerPubkey TEXT,
      masterSellerPubkey TEXT,
      buyerInvoice TEXT,
      createdAt INTEGER,
      expiresAt INTEGER,
      buyerToken INTEGER,
      sellerToken INTEGER
    )
    ''');
  }

  // region: CRUD

  @override
  Future<void> addOrder(Order order) async {
    final db = await database;
    await db.insert(
      _tableName,
      order.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Order>> getAllOrders() async {
    final db = await database;
    final results = await db.query(_tableName);
    return results.map((map) => Order.fromMap(map)).toList();
  }

  @override
  Future<Order?> getOrderById(String orderId) async {
    final db = await database;
    final results = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [orderId],
    );
    if (results.isNotEmpty) {
      return Order.fromMap(results.first);
    }
    return null;
  }

  @override
  Future<void> updateOrder(Order order) async {
    // The order must have a valid id
    if (order.id == null) {
      throw ArgumentError('Cannot update an Order with null ID');
    }

    final db = await database;
    await db.update(
      _tableName,
      order.toMap(),
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  // endregion

  @override
  void dispose() {
    // TODO: implement dispose
  }
}
