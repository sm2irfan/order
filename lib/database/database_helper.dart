import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('order_management.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Adding console log for database path
    print('Database path: $path');

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');

    // Create all_products table
    await db.execute('''
    CREATE TABLE all_products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      created_at TEXT NOT NULL,
      updated_at TEXT,
      name TEXT NOT NULL,
      uprices TEXT NOT NULL,
      image TEXT,
      discount INTEGER,
      description TEXT,
      category_1 TEXT,
      category_2 TEXT,
      popular_product INTEGER,
      matching_words TEXT
    )
    ''');

    // Create orders table
    await db.execute('''
    CREATE TABLE orders (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      total_amount REAL NOT NULL,
      delivery_option TEXT NOT NULL,
      delivery_address TEXT,
      delivery_time_slot TEXT,
      payment_method TEXT NOT NULL,
      order_status TEXT DEFAULT 'Order Placed',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      delivery_partner_name TEXT,
      delivery_partner_phone TEXT
    )
    ''');

    // Create order_details table
    await db.execute('''
    CREATE TABLE order_details (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id TEXT,
      product_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL,
      unit TEXT NOT NULL,
      discount INTEGER,
      price REAL NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES all_products (id)
    )
    ''');

    // Create profiles table
    await db.execute('''
    CREATE TABLE profiles (
      id TEXT PRIMARY KEY,
      full_name TEXT,
      address TEXT,
      phone_number TEXT,
      created_at TEXT,
      email TEXT,
      temp_password TEXT,
      updated_at TEXT,
      profile_number INTEGER,
      sms_send_successfully INTEGER
    )
    ''');
  }

  // Insert a new order
  Future<int> insertOrder(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('orders', row);
  }

  // Insert a new order detail
  Future<int> insertOrderDetail(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('order_details', row);
  }

  // Insert a new product
  Future<int> insertProduct(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('all_products', row);
  }

  // Insert a new profile
  Future<int> insertProfile(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('profiles', row);
  }

  // Get all orders
  Future<List<Map<String, dynamic>>> getOrders() async {
    Database db = await instance.database;
    return await db.query('orders');
  }

  // Get order details for a specific order
  Future<List<Map<String, dynamic>>> getOrderDetails(String orderId) async {
    Database db = await instance.database;
    return await db.query(
      'order_details',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  // Get all products
  Future<List<Map<String, dynamic>>> getProducts() async {
    Database db = await instance.database;
    return await db.query('all_products');
  }

  // Get a profile by ID
  Future<Map<String, dynamic>?> getProfile(String id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> result = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }
}
