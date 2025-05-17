import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:order_management/database/database_helper.dart';
import 'dart:async';

class SyncService {
  static final SyncService instance = SyncService._internal();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  SyncService._internal();

  // Constants for config keys
  static const String KEY_LAST_SYNC_PRODUCTS = 'last_sync_all_products';
  static const String KEY_LAST_SYNC_PROFILES = 'last_sync_profiles';
  static const String KEY_LAST_SYNC_ORDERS = 'last_sync_orders';
  static const String KEY_LAST_SYNC_ORDER_DETAILS = 'last_sync_order_details';

  // Helper method to get current timestamp in ISO format
  String _getCurrentTimestamp() {
    return DateTime.now().toUtc().toIso8601String();
  }

  Future<SyncResult> syncSupabaseToSQLite() async {
    final supabase = Supabase.instance.client;
    final SyncResult result = SyncResult();

    print('=== STARTING DATABASE SYNC ===');

    try {
      // Sync products
      print('Syncing products...');
      await _syncProducts(supabase, result);

      // Sync profiles
      print('Syncing profiles...');
      await _syncProfiles(supabase, result);

      // Sync orders and order details
      print('Syncing orders and order details...');
      await _syncOrdersAndDetails(supabase, result);

      // Verify data in SQLite
      print('Verifying data in SQLite database...');
      final dbProducts = await _dbHelper.getProducts();
      final dbOrders = await _dbHelper.getOrders();

      print('=== SYNC SUMMARY ===');
      print('Products in database: ${dbProducts.length}');
      print('Orders in database: ${dbOrders.length}');
      print('Profiles in database: ${result.successfulProfiles}');
      print('=== END DATABASE SYNC ===');

      result.success = true;
      return result;
    } catch (e) {
      print('CRITICAL ERROR during sync: $e');
      result.errors.add('CRITICAL ERROR: $e');
      result.success = false;
      return result;
    }
  }

  Future<void> _syncProducts(SupabaseClient supabase, SyncResult result) async {
    try {
      // Get last sync time for products
      String? lastSyncTime = await _dbHelper.getConfigValue(
        KEY_LAST_SYNC_PRODUCTS,
      );

      print('Last sync time for products: ${lastSyncTime ?? "Never"}');

      // Prepare query and fetch products
      List<dynamic> products = [];

      if (lastSyncTime != null) {
        // Fetch products updated since last sync
        final updatedProducts = await supabase
            .from('all_products')
            .select()
            .gte('updated_at', lastSyncTime);

        // Fetch products created since last sync
        final newProducts = await supabase
            .from('all_products')
            .select()
            .gte('created_at', lastSyncTime);

        // Merge results, avoiding duplicates by id
        final Map<int, dynamic> productMap = {};
        for (var product in updatedProducts) {
          productMap[product['id']] = product;
        }
        for (var product in newProducts) {
          productMap[product['id']] = product;
        }
        products = productMap.values.toList();
      } else {
        // If no last sync time, fetch all products
        products = await supabase.from('all_products').select();
      }

      print('Found ${products.length} products to sync');
      result.totalProducts = products.length;

      // Track products with validation issues
      final List<Map<String, dynamic>> invalidProducts = [];

      for (final product in products) {
        try {
          // Check for required fields
          if (product['name'] == null) {
            // Log product with missing required field
            invalidProducts.add({
              'id': product['id'],
              'error': 'Missing required field: name',
              'data': product.toString(),
            });

            // Skip this product instead of trying to insert it
            print(
              'Skipping product ${product['id']} due to missing name field',
            );
            continue;
          }

          await _dbHelper.upsertProduct({
            'id': product['id'],
            'created_at': product['created_at'],
            'updated_at': product['updated_at'],
            'name': product['name'],
            'uprices': product['uprices'],
            'image': product['image'],
            'discount': product['discount'],
            'description': product['description'],
            'category_1': product['category_1'],
            'category_2': product['category_2'],
            'popular_product': product['popular_product'] ? 1 : 0,
            'matching_words': product['matching_words'],
          });
          result.successfulProducts++;
        } catch (e) {
          print('ERROR upserting product ${product['id']}: $e');
          result.errors.add('Product ${product['id']}: $e');
        }
      }

      // Store details about invalid products
      if (invalidProducts.isNotEmpty) {
        result.invalidProducts = invalidProducts;
        result.warnings.add(
          '${invalidProducts.length} products had validation issues and were skipped',
        );
      }

      // Update last sync time
      if (products.isNotEmpty) {
        await _dbHelper.setConfigValue(
          KEY_LAST_SYNC_PRODUCTS,
          _getCurrentTimestamp(),
        );
      }

      print(
        'Product sync complete: ${result.successfulProducts}/${result.totalProducts} upserted successfully' +
            (invalidProducts.isEmpty
                ? ''
                : ' (${invalidProducts.length} products skipped)'),
      );
    } catch (e) {
      print('Error syncing products: $e');
      result.errors.add('Products sync error: $e');
    }
  }

  Future<void> _syncProfiles(SupabaseClient supabase, SyncResult result) async {
    try {
      // Get last sync time for profiles
      String? lastSyncTime = await _dbHelper.getConfigValue(
        KEY_LAST_SYNC_PROFILES,
      );

      print('Last sync time for profiles: ${lastSyncTime ?? "Never"}');

      // Prepare query and fetch profiles
      List<dynamic> profiles = [];

      if (lastSyncTime != null) {
        // Fetch profiles updated since last sync
        final updatedProfiles = await supabase
            .from('profiles')
            .select()
            .gte('updated_at', lastSyncTime);

        // Fetch profiles created since last sync
        final newProfiles = await supabase
            .from('profiles')
            .select()
            .gte('created_at', lastSyncTime);

        // Merge results, avoiding duplicates by id
        final Map<String, dynamic> profileMap = {};
        for (var profile in updatedProfiles) {
          profileMap[profile['id']] = profile;
        }
        for (var profile in newProfiles) {
          profileMap[profile['id']] = profile;
        }
        profiles = profileMap.values.toList();
      } else {
        // If no last sync time, fetch all profiles
        profiles = await supabase.from('profiles').select();
      }

      print('Found ${profiles.length} profiles to sync');
      result.totalProfiles = profiles.length;

      for (final profile in profiles) {
        try {
          await _dbHelper.upsertProfile({
            'id': profile['id'],
            'full_name': profile['full_name'],
            'address':
                profile['address'] != null &&
                        profile['address'] is List &&
                        (profile['address'] as List).isNotEmpty
                    ? (profile['address'] as List).join(
                      ', ',
                    ) // Handle list address
                    : profile['address'] is String
                    ? profile['address']
                    : null, // Handle string or null
            'phone_number': profile['phone_number'],
            'created_at': profile['created_at'],
            'email': profile['email'],
            'temp_password': profile['temp_password'],
            'updated_at': profile['updated_at'],
            'profile_number': profile['profile_number'],
            'sms_send_successfully': profile['sms_send_successfully'] ? 1 : 0,
          });
          result.successfulProfiles++;
        } catch (e) {
          print('ERROR upserting profile ${profile['id']}: $e');
          result.errors.add('Profile ${profile['id']}: $e');
        }
      }

      // Update last sync time
      if (profiles.isNotEmpty) {
        await _dbHelper.setConfigValue(
          KEY_LAST_SYNC_PROFILES,
          _getCurrentTimestamp(),
        );
      }

      print(
        'Profile sync complete: ${result.successfulProfiles}/${result.totalProfiles} upserted successfully',
      );
    } catch (e) {
      print('Error syncing profiles: $e');
      result.errors.add('Profiles sync error: $e');
    }
  }

  Future<void> _syncOrdersAndDetails(
    SupabaseClient supabase,
    SyncResult result,
  ) async {
    try {
      // Get last sync times for orders and order details
      String? lastSyncTimeOrders = await _dbHelper.getConfigValue(
        KEY_LAST_SYNC_ORDERS,
      );
      String? lastSyncTimeOrderDetails = await _dbHelper.getConfigValue(
        KEY_LAST_SYNC_ORDER_DETAILS,
      );

      print('Last sync time for orders: ${lastSyncTimeOrders ?? "Never"}');
      print(
        'Last sync time for order details: ${lastSyncTimeOrderDetails ?? "Never"}',
      );

      // Sync orders first
      List<Map<String, dynamic>> allOrders = [];
      int pageSize = 1000;

      // If we have a last sync time, fetch updated and new orders separately
      if (lastSyncTimeOrders != null) {
        // Fetch orders updated since last sync with pagination
        int currentPage = 0;
        bool hasMoreUpdatedOrders = true;

        while (hasMoreUpdatedOrders) {
          final pageStart = currentPage * pageSize;
          final pageEnd = pageStart + pageSize - 1;

          final List<Map<String, dynamic>> fetchedOrders = await supabase
              .from('orders')
              .select()
              .gte('updated_at', lastSyncTimeOrders)
              .range(pageStart, pageEnd);

          allOrders.addAll(fetchedOrders);

          if (fetchedOrders.length < pageSize) {
            hasMoreUpdatedOrders = false;
          } else {
            currentPage++;
          }
        }

        // Fetch orders created since last sync with pagination
        currentPage = 0;
        bool hasMoreNewOrders = true;

        while (hasMoreNewOrders) {
          final pageStart = currentPage * pageSize;
          final pageEnd = pageStart + pageSize - 1;

          final List<Map<String, dynamic>> fetchedOrders = await supabase
              .from('orders')
              .select()
              .gte('created_at', lastSyncTimeOrders)
              .range(pageStart, pageEnd);

          // Add only orders that aren't already in allOrders
          final Set<String> existingOrderIds = Set<String>.from(
            allOrders.map((order) => order['id'] as String),
          );

          for (var order in fetchedOrders) {
            if (!existingOrderIds.contains(order['id'])) {
              allOrders.add(order);
            }
          }

          if (fetchedOrders.length < pageSize) {
            hasMoreNewOrders = false;
          } else {
            currentPage++;
          }
        }
      } else {
        // If no last sync time, fetch all orders with pagination
        int currentPage = 0;
        bool hasMoreOrders = true;

        while (hasMoreOrders) {
          final pageStart = currentPage * pageSize;
          final pageEnd = pageStart + pageSize - 1;

          final List<Map<String, dynamic>> fetchedOrders = await supabase
              .from('orders')
              .select()
              .range(pageStart, pageEnd);

          allOrders.addAll(fetchedOrders);

          if (fetchedOrders.length < pageSize) {
            hasMoreOrders = false;
          } else {
            currentPage++;
          }
        }
      }

      print('Found ${allOrders.length} orders to sync');
      // add print orders
      for (var order in allOrders) {
        print('Order ID: ${order['id']}');
      }
      result.totalOrders = allOrders.length;

      // Get order detail ids that need to be synced
      Set<String> orderIdsToSync = Set<String>.from(
        allOrders.map((order) => order['id'] as String),
      );

      // If we have orders from before last sync that might have updated details
      if (lastSyncTimeOrderDetails != null && lastSyncTimeOrders != null) {
        // Find orders that existed before but might have updated details
        final List<Map<String, dynamic>> oldOrdersWithNewDetails =
            await supabase
                .from('order_details')
                .select('order_id')
                .gte('updated_at', lastSyncTimeOrderDetails)
                .lt('created_at', lastSyncTimeOrders)
                .order('order_id');

        // Add these order ids to our sync set
        for (var detail in oldOrdersWithNewDetails) {
          orderIdsToSync.add(detail['order_id'] as String);
        }
      }

      // Fetch order details for all orders that need syncing
      List<Map<String, dynamic>> allOrderDetailsList = [];

      if (orderIdsToSync.isNotEmpty) {
        // Split into batches if there are many order ids
        const int batchSize = 100; // Adjust based on your API limits
        for (int i = 0; i < orderIdsToSync.length; i += batchSize) {
          final end =
              (i + batchSize < orderIdsToSync.length)
                  ? i + batchSize
                  : orderIdsToSync.length;
          final batch = orderIdsToSync.toList().sublist(i, end);

          final List<Map<String, dynamic>> batchDetails = await supabase
              .from('order_details')
              .select()
              .filter(
                'order_id',
                'in',
                batch,
              ); // Using filter method instead of in/in_

          allOrderDetailsList.addAll(batchDetails);
        }
      }

      print('Found ${allOrderDetailsList.length} order details to sync');
      result.totalOrderDetails = allOrderDetailsList.length;

      // Group order details by order_id for efficient lookup
      final Map<String, List<Map<String, dynamic>>> orderDetailsMap = {};
      for (final detail in allOrderDetailsList) {
        final orderId = detail['order_id'] as String?;
        if (orderId != null) {
          orderDetailsMap.putIfAbsent(orderId, () => []).add(detail);
        }
      }

      // Process orders and their details
      for (final orderData in allOrders) {
        try {
          await _dbHelper.upsertOrder({
            'id': orderData['id'],
            'user_id': orderData['user_id'],
            'total_amount': orderData['total_amount'],
            'delivery_option': orderData['delivery_option'],
            'delivery_address': orderData['delivery_address'],
            'delivery_time_slot': orderData['delivery_time_slot'],
            'payment_method': orderData['payment_method'],
            'order_status': orderData['order_status'],
            'created_at': orderData['created_at'],
            'delivery_partner_name': orderData['delivery_partner_name'],
            'delivery_partner_phone': orderData['delivery_partner_phone'],
          });
          result.successfulOrders++;

          // Get details for this order from the pre-fetched map
          final List<Map<String, dynamic>>? detailsForThisOrder =
              orderDetailsMap[orderData['id']];
          if (detailsForThisOrder != null) {
            for (final detailData in detailsForThisOrder) {
              try {
                // Make a copy of the detail data to avoid modifying the original
                final Map<String, dynamic> detailCopy =
                    Map<String, dynamic>.from(detailData);

                // If this is a realtime update and contains an ID field that might conflict,
                // consider letting the upsert method handle it safely
                await _dbHelper.upsertOrderDetail(detailCopy);
                result.successfulOrderDetails++;
              } catch (e) {
                print(
                  'ERROR upserting order detail for order ${detailData['order_id']}, product ${detailData['product_id']}: $e',
                );
                result.errors.add(
                  'Order detail for order ${detailData['order_id']}, product ${detailData['product_id']}: $e',
                );
              }
            }
          }
        } catch (e) {
          print('ERROR upserting order ${orderData['id']}: $e');
          result.errors.add('Order ${orderData['id']}: $e');
        }
      }

      // Update last sync times
      final currentTime = _getCurrentTimestamp();
      if (allOrders.isNotEmpty) {
        await _dbHelper.setConfigValue(KEY_LAST_SYNC_ORDERS, currentTime);
      }
      if (allOrderDetailsList.isNotEmpty) {
        await _dbHelper.setConfigValue(
          KEY_LAST_SYNC_ORDER_DETAILS,
          currentTime,
        );
      }

      print(
        'Order sync complete: ${result.successfulOrders}/${result.totalOrders} orders upserted successfully',
      );
      print(
        'Order details sync complete: ${result.successfulOrderDetails}/${result.totalOrderDetails} details upserted successfully',
      );
    } catch (e) {
      print('Error syncing orders and details: $e');
      result.errors.add('Orders sync error: $e');
    }
  }

  // Method to perform a full sync (ignoring timestamps)
  Future<SyncResult> performFullSync() async {
    // Clear all timestamp config values
    await _dbHelper.setConfigValue(KEY_LAST_SYNC_PRODUCTS, '');
    await _dbHelper.setConfigValue(KEY_LAST_SYNC_PROFILES, '');
    await _dbHelper.setConfigValue(KEY_LAST_SYNC_ORDERS, '');
    await _dbHelper.setConfigValue(KEY_LAST_SYNC_ORDER_DETAILS, '');

    // Then perform the sync
    return await syncSupabaseToSQLite();
  }

  // Optionally add a method to clear tables
  Future<void> clearAllTables() async {
    await _dbHelper.clearTable('order_details');
    await _dbHelper.clearTable('orders');
    await _dbHelper.clearTable('all_products');
    await _dbHelper.clearTable('profiles');
    print('Cleared all tables for fresh sync');
  }
}

// Keeping the existing SyncResult class
class SyncResult {
  bool success = false;
  int totalProducts = 0;
  int successfulProducts = 0;
  int totalProfiles = 0;
  int successfulProfiles = 0;
  int totalOrders = 0;
  int successfulOrders = 0;
  int totalOrderDetails = 0;
  int successfulOrderDetails = 0;
  List<String> errors = [];
  List<String> warnings = []; // New field for warnings
  List<Map<String, dynamic>> invalidProducts =
      []; // For tracking invalid products

  bool get hasWarnings => warnings.isNotEmpty;

  String get summary {
    final buffer = StringBuffer();

    if (success) {
      buffer.writeln('Sync completed successfully!');
    } else {
      buffer.writeln('Sync completed with errors.');
    }

    buffer.writeln('Products: $successfulProducts/$totalProducts');
    buffer.writeln('Profiles: $successfulProfiles/$totalProfiles');
    buffer.writeln('Orders: $successfulOrders/$totalOrders');
    buffer.writeln('Order Details: $successfulOrderDetails/$totalOrderDetails');

    if (errors.isNotEmpty) {
      buffer.writeln('Errors: ${errors.length}');
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('Warnings: ${warnings.length}');
      for (var warning in warnings) {
        buffer.writeln('- $warning');
      }
    }

    return buffer.toString();
  }

  String get detailedReport {
    final buffer = StringBuffer(summary);

    if (invalidProducts.isNotEmpty) {
      buffer.writeln('\nInvalid Products:');
      for (var product in invalidProducts) {
        buffer.writeln('- Product ID: ${product['id']}');
        buffer.writeln('  Error: ${product['error']}');
      }
    }

    if (errors.isNotEmpty) {
      buffer.writeln('\nErrors:');
      for (var error in errors) {
        buffer.writeln('- $error');
      }
    }

    return buffer.toString();
  }
}
