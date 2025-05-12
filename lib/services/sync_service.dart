import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:order_management/database/database_helper.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();

  SyncService._internal();

  Future<SyncResult> syncSupabaseToSQLite() async {
    final supabase = Supabase.instance.client;
    final dbHelper = DatabaseHelper.instance;

    print('=== STARTING DATABASE SYNC ===');
    final SyncResult result = SyncResult();

    try {
      // Sync products
      print('Fetching products from Supabase...');
      List<dynamic> products = [];
      // Note: If product list is very large, pagination might be needed here too.
      // For now, assuming it fits in a single reasonable request.
      products = await supabase.from('all_products').select();
      print('Found ${products.length} products to sync');
      result.totalProducts = products.length;

      for (final product in products) {
        try {
          await dbHelper.upsertProduct({
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
      print(
        'Product sync complete: ${result.successfulProducts}/${result.totalProducts} upserted successfully',
      );

      // Sync profiles
      print('Fetching profiles from Supabase...');
      // Note: If profile list is very large, pagination might be needed here too.
      final profiles = await supabase.from('profiles').select();
      print('Found ${profiles.length} profiles to sync');
      result.totalProfiles = profiles.length;

      for (final profile in profiles) {
        try {
          await dbHelper.upsertProfile({
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
      print(
        'Profile sync complete: ${result.successfulProfiles}/${result.totalProfiles} upserted successfully',
      );

      // Sync orders and order_details (Optimized)
      print('Fetching all orders from Supabase with pagination...');
      List<Map<String, dynamic>> allOrders = [];
      int pageSize = 1000; // Supabase default limit for range, adjust if needed
      int currentPage = 0;
      bool hasMoreOrders = true;

      while (hasMoreOrders) {
        final pageStart = currentPage * pageSize;
        final pageEnd = pageStart + pageSize - 1;
        print(
          'Fetching orders page ${currentPage + 1} (range $pageStart-$pageEnd)...',
        );
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
      print('Found ${allOrders.length} total orders to sync');
      result.totalOrders = allOrders.length;

      print('Fetching all order details from Supabase...');
      // Note: If total order_details are extremely numerous, this might also need pagination.
      // For now, attempting to fetch all in one go.
      final List<Map<String, dynamic>> allOrderDetailsList =
          await supabase.from('order_details').select();
      result.totalOrderDetails = allOrderDetailsList.length;
      print('Found ${allOrderDetailsList.length} total order details to sync');

      // Group order details by order_id for efficient lookup
      final Map<String, List<Map<String, dynamic>>> orderDetailsMap = {};
      for (final detail in allOrderDetailsList) {
        final orderId = detail['order_id'] as String?;
        if (orderId != null) {
          orderDetailsMap.putIfAbsent(orderId, () => []).add(detail);
        }
      }

      for (final orderData in allOrders) {
        try {
          await dbHelper.upsertOrder({
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
                await dbHelper.upsertOrderDetail({
                  'order_id': detailData['order_id'],
                  'product_id': detailData['product_id'],
                  'quantity': detailData['quantity'],
                  'unit': detailData['unit'],
                  'discount': detailData['discount'],
                  'price': detailData['price'],
                  'created_at': detailData['created_at'],
                });
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
      print(
        'Order sync complete: ${result.successfulOrders}/${result.totalOrders} orders upserted successfully',
      );
      print(
        'Order details sync complete: ${result.successfulOrderDetails}/${result.totalOrderDetails} details upserted successfully',
      );

      // Verify data in SQLite
      print('Verifying data in SQLite database...');
      final dbProducts = await dbHelper.getProducts();
      final dbOrders = await dbHelper.getOrders();

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

  // Optionally add a method to clear tables
  Future<void> clearAllTables() async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.clearTable('order_details');
    await dbHelper.clearTable('orders');
    await dbHelper.clearTable('all_products');
    await dbHelper.clearTable('profiles');
    print('Cleared all tables for fresh sync');
  }
}

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

    return buffer.toString();
  }
}
