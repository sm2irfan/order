import 'package:supabase_flutter/supabase_flutter.dart';

class OrderStatusHistoryService {
  static final supabase = Supabase.instance.client;
  static const String _tableName = 'orders_status_history';

  /// Adds a new status history record when an order status is updated
  static Future<Map<String, dynamic>?> addStatusHistory({
    required String orderId,
    required String orderStatus,
    String? updatedById,
    String? updatedByName,
  }) async {
    try {
      final response =
          await supabase
              .from(_tableName)
              .insert({'order_id': orderId, 'order_status': orderStatus})
              .select()
              .single();

      return response;
    } on PostgrestException catch (error) {
      print('Error adding status history: ${error.message}');
      return null;
    } catch (e) {
      print('Unexpected error adding status history: $e');
      return null;
    }
  }

  /// Deletes a status history record
  static Future<bool> deleteStatusHistory(String id) async {
    try {
      await supabase.from(_tableName).delete().eq('id', id);

      return true;
    } on PostgrestException catch (error) {
      print('Error deleting status history: ${error.message}');
      return false;
    } catch (e) {
      print('Unexpected error deleting status history: $e');
      return false;
    }
  }

  /// Gets all status history for a specific order
  static Future<List<Map<String, dynamic>>> getOrderStatusHistory(
    String orderId,
  ) async {
    try {
      final response = await supabase
          .from(_tableName)
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (error) {
      print('Error fetching status history: ${error.message}');
      return [];
    } catch (e) {
      print('Unexpected error fetching status history: $e');
      return [];
    }
  }

  /// Deletes all status history for a specific order
  static Future<bool> deleteOrderStatusHistory(String orderId) async {
    try {
      await supabase.from(_tableName).delete().eq('order_id', orderId);

      return true;
    } on PostgrestException catch (error) {
      print('Error deleting order status history: ${error.message}');
      return false;
    } catch (e) {
      print('Unexpected error deleting order status history: $e');
      return false;
    }
  }
}
