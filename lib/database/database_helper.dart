import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      try {
        // Test if the database is still valid
        await _database!.rawQuery('SELECT 1');
        return _database!;
      } catch (e) {
        print('🔧 Existing database connection invalid: $e');
        _database = null; // Force reinitialize
      }
    }

    try {
      _database = await _initDB('order_management.db');
      print('✅ Database initialized successfully');
      return _database!;
    } catch (e) {
      print('❌ Failed to initialize database: $e');
      rethrow;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Adding console log for database path
    print('Database path: $path');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      readOnly: false, // Explicitly set to read-write mode
      singleInstance: true, // Ensure single instance
    );
  }

  // Check database health and fix issues
  Future<bool> checkDatabaseHealth() async {
    try {
      Database db = await instance.database;

      // Test basic operations
      await db.rawQuery('SELECT COUNT(*) FROM orders');
      await db.rawQuery('SELECT COUNT(*) FROM order_details');

      print('✅ Database health check passed');
      return true;
    } catch (e) {
      print('❌ Database health check failed: $e');

      // Try to fix by reinitializing
      try {
        _database = null;
        Database db = await instance.database;
        await db.rawQuery('SELECT COUNT(*) FROM orders');
        print('✅ Database fixed after reinitialization');
        return true;
      } catch (fixError) {
        print('❌ Database fix failed: $fixError');
        return false;
      }
    }
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

    // Create orders table with customer fields
    await db.execute('''
    CREATE TABLE orders (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      customer_name TEXT,
      customer_phone_number TEXT,
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

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add customer fields to orders table
      await db.execute('ALTER TABLE orders ADD COLUMN customer_name TEXT');
      await db.execute(
        'ALTER TABLE orders ADD COLUMN customer_phone_number TEXT',
      );
      print('Database upgraded from version $oldVersion to $newVersion');
    }
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

  // Offline order management methods

  // Save order to local database
  Future<void> saveOrderToLocal(Map<String, dynamic> order) async {
    Database db = await instance.database;

    await db.transaction((txn) async {
      // Insert or replace order
      await txn.insert('orders', {
        'id': order['id'],
        'user_id': order['user_id'],
        'customer_name': order['customer_name'],
        'customer_phone_number': order['customer_phone_number'],
        'total_amount': order['total_amount'],
        'delivery_option': order['delivery_option'],
        'delivery_address': order['delivery_address'],
        'delivery_time_slot': order['delivery_time_slot'],
        'payment_method': order['payment_method'],
        'order_status': order['order_status'],
        'created_at': order['created_at'],
        'updated_at': order['updated_at'],
        'delivery_partner_name': order['delivery_partner_name'],
        'delivery_partner_phone': order['delivery_partner_phone'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Handle order details: First delete existing details, then insert new ones
      // This prevents duplicate items when syncing the same order multiple times
      if (order['items'] != null) {
        // Delete existing order details for this order to prevent duplicates
        await txn.delete(
          'order_details',
          where: 'order_id = ?',
          whereArgs: [order['id']],
        );

        // Insert fresh order details
        for (var item in order['items']) {
          await txn.insert('order_details', {
            'order_id': order['id'],
            'product_id': item['product_id'],
            'quantity': item['quantity'],
            'unit': item['unit'],
            'discount': item['discount'] ?? 0,
            'price': item['price'],
            'created_at': item['created_at'],
            'updated_at': item['updated_at'],
          });
        }
      }
    });

    print(
      'Saved order ${order['id']} to local database with ${order['items']?.length ?? 0} items',
    );
  }

  // Get orders with details from local database
  Future<List<Map<String, dynamic>>> getOrdersWithDetails() async {
    try {
      Database db = await instance.database;

      // Test database connectivity with a simple query first
      await db.rawQuery('SELECT 1');
      print('📊 Database connectivity test passed');

      // Get all orders
      List<Map<String, dynamic>> orders = await db.query(
        'orders',
        orderBy: 'created_at DESC',
      );
      print('📋 Retrieved ${orders.length} orders from local database');

      if (orders.isEmpty) return orders;

      // Get all order details
      List<Map<String, dynamic>> allDetails = await db.query(
        'order_details',
        orderBy: 'order_id, id',
      );
      print(
        '📦 Retrieved ${allDetails.length} order details from local database',
      );

      // Group details by order_id
      Map<String, List<Map<String, dynamic>>> detailsMap = {};
      for (var detail in allDetails) {
        String orderId = detail['order_id'];
        if (!detailsMap.containsKey(orderId)) {
          detailsMap[orderId] = [];
        }

        // Create a mutable copy of the detail map to avoid read-only issues
        Map<String, dynamic> mutableDetail = Map<String, dynamic>.from(detail);

        // Add basic product name (will be enhanced by service with cached names)
        mutableDetail['product_name'] =
            'Product ${mutableDetail['product_id']}';
        mutableDetail['product_image_url'] = null;

        detailsMap[orderId]!.add(mutableDetail);
      }

      // Attach details to each order with mutable copies
      List<Map<String, dynamic>> mutableOrders = [];
      for (var order in orders) {
        String orderId = order['id'];
        Map<String, dynamic> mutableOrder = Map<String, dynamic>.from(order);
        mutableOrder['details'] = detailsMap[orderId] ?? [];
        mutableOrders.add(mutableOrder);
      }

      print(
        '✅ Successfully processed ${mutableOrders.length} orders with details',
      );
      return mutableOrders;
    } catch (e) {
      print('❌ Error in getOrdersWithDetails: $e');
      print('🔧 Error type: ${e.runtimeType}');

      // Try to reinitialize database connection
      try {
        print('🔄 Attempting to reinitialize database connection...');
        _database = null; // Force reinitialize
        Database db = await instance.database;
        print('✅ Database reinitialized successfully');

        // Retry the query
        List<Map<String, dynamic>> orders = await db.query(
          'orders',
          orderBy: 'created_at DESC',
        );
        print('🔄 Retry successful: Retrieved ${orders.length} orders');
        return orders;
      } catch (retryError) {
        print('❌ Retry failed: $retryError');
        rethrow;
      }
    }
  }

  // Search orders in local database
  Future<List<Map<String, dynamic>>> searchOrders(String query) async {
    Database db = await instance.database;

    List<Map<String, dynamic>> orders = await db.query(
      'orders',
      where: '''
        LOWER(id) LIKE LOWER(?) OR 
        LOWER(customer_name) LIKE LOWER(?) OR 
        LOWER(customer_phone_number) LIKE LOWER(?) OR
        LOWER(order_status) LIKE LOWER(?)
      ''',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );

    if (orders.isEmpty) return orders;

    // Get details for matching orders
    List<String> orderIds = orders.map((o) => o['id'] as String).toList();
    String placeholders = orderIds.map((_) => '?').join(',');

    List<Map<String, dynamic>> allDetails = await db.query(
      'order_details',
      where: 'order_id IN ($placeholders)',
      whereArgs: orderIds,
      orderBy: 'order_id, id',
    );

    // Group details by order_id
    Map<String, List<Map<String, dynamic>>> detailsMap = {};
    for (var detail in allDetails) {
      String orderId = detail['order_id'];
      if (!detailsMap.containsKey(orderId)) {
        detailsMap[orderId] = [];
      }

      // Create a mutable copy of the detail map to avoid read-only issues
      Map<String, dynamic> mutableDetail = Map<String, dynamic>.from(detail);

      mutableDetail['product_name'] = 'Product ${mutableDetail['product_id']}';
      mutableDetail['product_image_url'] = null;

      detailsMap[orderId]!.add(mutableDetail);
    }

    // Attach details to each order with mutable copies
    List<Map<String, dynamic>> mutableOrders = [];
    for (var order in orders) {
      String orderId = order['id'];
      Map<String, dynamic> mutableOrder = Map<String, dynamic>.from(order);
      mutableOrder['details'] = detailsMap[orderId] ?? [];
      mutableOrders.add(mutableOrder);
    }

    return mutableOrders;
  }

  // Filter orders by status from local database
  Future<List<Map<String, dynamic>>> getOrdersByStatus(String status) async {
    Database db = await instance.database;

    List<Map<String, dynamic>> orders;
    if (status == 'All') {
      orders = await db.query('orders', orderBy: 'created_at DESC');
    } else {
      orders = await db.query(
        'orders',
        where: 'order_status = ?',
        whereArgs: [status],
        orderBy: 'created_at DESC',
      );
    }

    if (orders.isEmpty) return orders;

    // Get details for matching orders
    List<String> orderIds = orders.map((o) => o['id'] as String).toList();
    String placeholders = orderIds.map((_) => '?').join(',');

    List<Map<String, dynamic>> allDetails = await db.query(
      'order_details',
      where: 'order_id IN ($placeholders)',
      whereArgs: orderIds,
      orderBy: 'order_id, id',
    );

    // Group details by order_id
    Map<String, List<Map<String, dynamic>>> detailsMap = {};
    for (var detail in allDetails) {
      String orderId = detail['order_id'];
      if (!detailsMap.containsKey(orderId)) {
        detailsMap[orderId] = [];
      }

      // Create a mutable copy of the detail map to avoid read-only issues
      Map<String, dynamic> mutableDetail = Map<String, dynamic>.from(detail);

      mutableDetail['product_name'] = 'Product ${mutableDetail['product_id']}';
      mutableDetail['product_image_url'] = null;

      detailsMap[orderId]!.add(mutableDetail);
    }

    // Attach details to each order with mutable copies
    List<Map<String, dynamic>> mutableOrders = [];
    for (var order in orders) {
      String orderId = order['id'];
      Map<String, dynamic> mutableOrder = Map<String, dynamic>.from(order);
      mutableOrder['details'] = detailsMap[orderId] ?? [];
      mutableOrders.add(mutableOrder);
    }

    return mutableOrders;
  }

  // Update order status in local database
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    Database db = await instance.database;
    await db.update(
      'orders',
      {
        'order_status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  // Get order status counts from local database
  Future<Map<String, int>> getOrderStatusCounts() async {
    Database db = await instance.database;

    List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT order_status, COUNT(*) as count 
      FROM orders 
      GROUP BY order_status
    ''');

    Map<String, int> counts = {};
    for (var result in results) {
      counts[result['order_status']] = result['count'];
    }

    return counts;
  }

  // Delete all orders from local database (for testing/reset)
  Future<void> clearAllOrders() async {
    Database db = await instance.database;
    await db.delete('order_details');
    await db.delete('orders');
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
