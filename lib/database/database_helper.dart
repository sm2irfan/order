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
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
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
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
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

    // Create config table to store app configuration including last sync times
    await db.execute('''
    CREATE TABLE config (
      key TEXT PRIMARY KEY,
      value TEXT
    )
    ''');
  }

  // Get a config value by key
  Future<String?> getConfigValue(String key) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> result = await db.query(
      'config',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    return result.isNotEmpty ? result.first['value'] as String? : null;
  }

  // Set a config value
  Future<int> setConfigValue(String key, String value) async {
    Database db = await instance.database;
    return await db.insert('config', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Insert or update a product
  Future<int> upsertProduct(Map<String, dynamic> row) async {
    Database db = await instance.database;

    try {
      return await db.insert(
        'all_products',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // If insert with REPLACE fails, try an update
      print('Error during product upsert, trying update: $e');
      return await db.update(
        'all_products',
        row,
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  // Insert or update a profile
  Future<int> upsertProfile(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(
      'profiles',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insert or update an order
  Future<int> upsertOrder(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(
      'orders',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insert or update an order detail
  Future<int> upsertOrderDetail(Map<String, dynamic> row) async {
    Database db = await instance.database;

    try {
      // For order details without an ID, we need a different approach
      // First check if it exists by using order_id and product_id
      final existingRows = await db.query(
        'order_details',
        where: 'order_id = ? AND product_id = ?',
        whereArgs: [row['order_id'], row['product_id']],
      );

      if (existingRows.isNotEmpty) {
        // Create a map for the update that excludes the id field
        final Map<String, dynamic> updateData = Map<String, dynamic>.from(row);

        // Remove id field to avoid unique constraint violations
        updateData.remove('id');

        // Update existing record without changing its ID
        return await db.update(
          'order_details',
          updateData,
          where: 'order_id = ? AND product_id = ?',
          whereArgs: [row['order_id'], row['product_id']],
        );
      } else {
        // For insert operations, if id is provided and not auto-generated
        // we should make sure it doesn't conflict
        if (row.containsKey('id')) {
          // Check if an order detail with this ID already exists
          final existingWithId = await db.query(
            'order_details',
            where: 'id = ?',
            whereArgs: [row['id']],
            limit: 1,
          );

          if (existingWithId.isNotEmpty) {
            // If ID exists but is for a different order/product, remove the ID to let SQLite auto-generate it
            final copyWithoutId = Map<String, dynamic>.from(row);
            copyWithoutId.remove('id');
            return await db.insert('order_details', copyWithoutId);
          }
        }

        // Insert new record
        return await db.insert('order_details', row);
      }
    } catch (e) {
      print('Error in upsertOrderDetail: $e');
      // If we get here, something went wrong, try a safe insert without the ID
      try {
        final safeRow = Map<String, dynamic>.from(row);
        safeRow.remove('id'); // Remove ID to let SQLite auto-generate it
        return await db.insert('order_details', safeRow);
      } catch (fallbackError) {
        print('Fallback insert also failed: $fallbackError');
        rethrow;
      }
    }
  }

  // Original methods kept for backward compatibility
  Future<int> insertOrder(Map<String, dynamic> row) async {
    return await upsertOrder(row);
  }

  Future<int> insertOrderDetail(Map<String, dynamic> row) async {
    return await upsertOrderDetail(row);
  }

  Future<int> insertProduct(Map<String, dynamic> row) async {
    return await upsertProduct(row);
  }

  Future<int> insertProfile(Map<String, dynamic> row) async {
    return await upsertProfile(row);
  }

  // Get all orders
  Future<List<Map<String, dynamic>>> getOrders() async {
    Database db = await instance.database;
    return await db.query(
      'orders',
      orderBy: 'created_at DESC', // Sort by creation date in descending order
    );
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

  // Get a product by ID
  Future<Map<String, dynamic>?> getProductById(int productId) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> result = await db.query(
      'all_products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Get all profiles
  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    Database db = await instance.database;
    return await db.query('profiles');
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

  // Clear a table before syncing
  Future<void> clearTable(String tableName) async {
    Database db = await instance.database;
    await db.delete(tableName);
    print('Cleared table: $tableName');
  }
}
