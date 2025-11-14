import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:order_management/models/order_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOrderService {
  static const String _baseUrl =
      'https://lhytairgnojpzgbgjhod.supabase.co/functions/v1';

  /// Fetch all orders from Supabase function
  Future<List<Order>> fetchOrders() async {
    print('🔄 Starting to fetch orders from Supabase function...');

    try {
      // Get the current user's access token
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;

      if (session == null) {
        print('❌ No active session found');
        throw Exception('User not authenticated');
      }

      // Check if session is expired
      final expiresAt = session.expiresAt;
      final now = DateTime.now().millisecondsSinceEpoch / 1000;

      if (expiresAt != null && expiresAt <= now) {
        print('⏰ Session expired, attempting to refresh...');
        try {
          final refreshResponse = await supabase.auth.refreshSession();
          if (refreshResponse.session == null) {
            print('❌ Failed to refresh session');
            throw Exception('Session expired and refresh failed');
          }
          print('✅ Session refreshed successfully');
        } catch (e) {
          print('💥 Error refreshing session: $e');
          throw Exception('Authentication failed: $e');
        }
      }

      final accessToken = supabase.auth.currentSession?.accessToken;
      if (accessToken == null) {
        throw Exception('No access token available');
      }

      print('📜 Using access token: ${accessToken.substring(0, 20)}...');
      print('📡 Making HTTP GET request to: $_baseUrl/get-auth-user-order');

      final response = await http.get(
        Uri.parse('$_baseUrl/get-auth-user-order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('📊 Response status code: ${response.statusCode}');
      print('📦 Response body length: ${response.body.length} characters');

      if (response.statusCode == 401) {
        print('🔐 Authentication failed - redirecting to login');
        // Clear any cached session
        await supabase.auth.signOut();
        throw Exception('Authentication expired. Please login again.');
      }

      if (response.statusCode == 200) {
        print('✅ Successfully received response from Supabase');

        final Map<String, dynamic> responseData = json.decode(response.body);
        print('🔍 Parsed response data keys: ${responseData.keys.toList()}');

        final List<dynamic> ordersJson = responseData['orders'] ?? [];
        print('📋 Found ${ordersJson.length} orders in response');

        if (ordersJson.isNotEmpty) {
          print('🔎 First order sample: ${ordersJson.first}');
        }

        final List<Order> parsedOrders = ordersJson.map((orderJson) {
          final order = _parseOrderFromJson(orderJson);
          print(
            '✨ Parsed order: ID=${order.id}, Status=${order.orderStatus}, Items=${order.items.length}',
          );
          return order;
        }).toList();

        print('🎉 Successfully parsed ${parsedOrders.length} orders');
        return parsedOrders;
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('📄 Error response body: ${response.body}');
        throw Exception(
          'Failed to fetch orders: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 Error fetching orders from Supabase: $e');
      print('🔧 Error type: ${e.runtimeType}');
      throw Exception('Failed to fetch orders: $e');
    }
  }

  /// Parse order from JSON response
  Order _parseOrderFromJson(Map<String, dynamic> json) {
    try {
      print('🔄 Parsing order: ${json['id']}');

      // Parse order items
      final List<OrderDetail> items = [];
      if (json['items'] != null && json['items'] is List) {
        print('📦 Found ${json['items'].length} items for order ${json['id']}');

        for (var itemJson in json['items']) {
          final item = _parseOrderDetailFromJson(itemJson);
          items.add(item);
          print(
            '  ➕ Added item: ${item.productName} x${item.quantity} @ ${item.price}',
          );
        }
      } else {
        print('⚠️  No items found for order ${json['id']}');
      }

      // Parse customer profile
      String? customerName;
      String? customerPhoneNumber;
      if (json['profile'] != null) {
        final profile = json['profile'] as Map<String, dynamic>;
        customerName = profile['full_name'] as String?;
        customerPhoneNumber = profile['phone_number'] as String?;
        print('👤 Customer: $customerName ($customerPhoneNumber)');
      } else {
        print('⚠️  No profile found for order ${json['id']}');
      }

      // Parse created_at date
      DateTime createdAt;
      try {
        createdAt = DateTime.parse(json['created_at'] as String);
        print('📅 Order date: ${createdAt.toString()}');
      } catch (e) {
        createdAt = DateTime.now();
        print('⚠️  Failed to parse created_at for order ${json['id']}: $e');
      }

      final order = Order(
        id: json['id'] as String,
        userId: json['user_id'] as String?,
        customerName: customerName,
        customerPhoneNumber: customerPhoneNumber,
        totalAmount: (json['total_amount'] as num).toDouble(),
        deliveryOption: json['delivery_option'] as String,
        deliveryAddress: json['delivery_address'] as String?,
        deliveryTimeSlot: json['delivery_time_slot'] as String?,
        paymentMethod: json['payment_method'] as String,
        orderStatus: json['order_status'] as String,
        createdAt: createdAt,
        deliveryPartnerName: json['delivery_partner_name'] as String?,
        deliveryPartnerPhone: json['delivery_partner_phone'] as String?,
        items: items,
      );

      print(
        '✅ Successfully parsed order ${order.id}: ${order.orderStatus}, Total: ${order.totalAmount}',
      );
      return order;
    } catch (e) {
      print('💥 Error parsing order from JSON: $e');
      print('📄 JSON data: $json');
      rethrow;
    }
  }

  /// Parse order detail from JSON response
  OrderDetail _parseOrderDetailFromJson(Map<String, dynamic> json) {
    try {
      final int productId = json['product_id'] as int;
      // Get product name and image directly from the response
      final String productName = json['name'] as String? ?? 'Product $productId';
      final String? productImageUrl = json['image'] as String?;
      final int quantity = json['quantity'] as int;
      final String unit = json['unit'] as String;
      final int? discount = json['discount'] as int?;
      final double price = (json['price'] as num).toDouble();
      final String? stockQuantity = json['stock_quantity']?.toString();
      final double? profit = json['profit'] != null 
          ? (json['profit'] as num).toDouble() 
          : null;

      // Calculate unit price for logging
      final unitPrice = price / quantity;

      print(
        '    🛍️  Product $productId: $productName, $quantity $unit @ $unitPrice each (Total: $price) [Stock: ${stockQuantity ?? 'N/A'}] [Profit: ${profit ?? 'N/A'}]',
      );

      return OrderDetail(
        productId: productId,
        productName: productName,
        productImageUrl: productImageUrl,
        quantity: quantity,
        unit: unit,
        discount: discount,
        price: price,
        stockQuantity: stockQuantity,
        profit: profit,
      );
    } catch (e) {
      print('💥 Error parsing order detail from JSON: $e');
      print('📄 Detail JSON: $json');
      rethrow;
    }
  }

  /// Update order status and create history record
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    print('🔄 Updating order $orderId status to: $newStatus');

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        print('❌ No authenticated user found');
        throw Exception('User not authenticated');
      }

      print('👤 Current user: ${user.id}');

      // Start a transaction-like operation
      // First, update the order status in the orders table
      print('📝 Updating orders table...');
      await supabase
          .from('orders')
          .update({'order_status': newStatus})
          .eq('id', orderId);

      print('✅ Order status updated in orders table');

      // Then, create a record in the orders_status_history table
      print('📊 Creating status history record...');
      final historyData = {
        'order_id': orderId,
        'order_status': newStatus,
        'updated_by_id': user.id,
        'updated_by_name': user.email?.split('@').first ?? 'Unknown User',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      print('📋 History data: $historyData');

      await supabase.from('orders_status_history').insert(historyData);

      print('✅ Status history record created successfully');
      print('🎉 Order status update completed for order: $orderId');

      return true;
    } catch (e) {
      print('❌ Error updating order status: $e');
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Get order status history for a specific order
  Future<List<Map<String, dynamic>>> getOrderStatusHistory(
    String orderId,
  ) async {
    print('📋 Fetching status history for order: $orderId');

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('orders_status_history')
          .select('*')
          .eq('order_id', orderId)
          .order('created_at', ascending: false);

      print(
        '📊 Found ${response.length} status history records for order $orderId',
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching order status history: $e');
      throw Exception('Failed to fetch status history: $e');
    }
  }
}
