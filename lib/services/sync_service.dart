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

      // Initialize products as empty list before API call
      List<dynamic> products = [];
      products = await supabase.from('all_products').select();

      print('Found ${products.length} products to sync');
      result.totalProducts = products.length;

      for (final product in products) {
        try {
          final dbResult = await dbHelper.upsertProduct({
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
          // print(
          //   'Upserted product: ${product['name']}, ID: ${product['id']}, Result: $dbResult',
          // );
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
      final profiles = await supabase.from('profiles').select();
      print('Found ${profiles.length} profiles to sync');
      result.totalProfiles = profiles.length;

      for (final profile in profiles) {
        try {
          final dbResult = await dbHelper.upsertProfile({
            'id': profile['id'],
            'full_name': profile['full_name'],
            'address':
                profile['address'] != null ? profile['address'][0] : null,
            'phone_number': profile['phone_number'],
            'created_at': profile['created_at'],
            'email': profile['email'],
            'temp_password': profile['temp_password'],
            'updated_at': profile['updated_at'],
            'profile_number': profile['profile_number'],
            'sms_send_successfully': profile['sms_send_successfully'] ? 1 : 0,
          });
          // print(
          //   'Upserted profile: ${profile['full_name']}, ID: ${profile['id']}, Result: $dbResult',
          // );
          result.successfulProfiles++;
        } catch (e) {
          print('ERROR upserting profile ${profile['id']}: $e');
          result.errors.add('Profile ${profile['id']}: $e');
        }
      }
      print(
        'Profile sync complete: ${result.successfulProfiles}/${result.totalProfiles} upserted successfully',
      );

      // Sync orders
      print('Fetching orders from Supabase...');
      final orders = await supabase.from('orders').select();
      print('Found ${orders.length} orders to sync');
      result.totalOrders = orders.length;

      for (final order in orders) {
        try {
          final orderResult = await dbHelper.upsertOrder({
            'id': order['id'],
            'user_id': order['user_id'],
            'total_amount': order['total_amount'],
            'delivery_option': order['delivery_option'],
            'delivery_address': order['delivery_address'],
            'delivery_time_slot': order['delivery_time_slot'],
            'payment_method': order['payment_method'],
            'order_status': order['order_status'],
            'created_at': order['created_at'],
            'delivery_partner_name': order['delivery_partner_name'],
            'delivery_partner_phone': order['delivery_partner_phone'],
          });
          // print('Upserted order: ID: ${order['id']}, Result: $orderResult');
          result.successfulOrders++;

          // Sync order details for this order
          print('Fetching order details for order ${order['id']}...');
          final orderDetails = await supabase
              .from('order_details')
              .select()
              .eq('order_id', order['id']);
          print(
            'Found ${orderDetails.length} details for order ${order['id']}',
          );
          result.totalOrderDetails += orderDetails.length;

          for (final detail in orderDetails) {
            try {
              final detailResult = await dbHelper.upsertOrderDetail({
                'order_id': detail['order_id'],
                'product_id': detail['product_id'],
                'quantity': detail['quantity'],
                'unit': detail['unit'],
                'discount': detail['discount'],
                'price': detail['price'],
                'created_at': detail['created_at'],
              });
              print(
                'Upserted order detail: Product ID: ${detail['product_id']}, Result: $detailResult',
              );
              result.successfulOrderDetails++;
            } catch (e) {
              print(
                'ERROR upserting order detail for order ${detail['order_id']}, product ${detail['product_id']}: $e',
              );
              result.errors.add(
                'Order detail for order ${detail['order_id']}, product ${detail['product_id']}: $e',
              );
            }
          }
        } catch (e) {
          print('ERROR upserting order ${order['id']}: $e');
          result.errors.add('Order ${order['id']}: $e');
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
