import 'dart:async'; // Import async
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:order_management/database/database_helper.dart'; // Import for database access

class SupabaseRealtimeService {
  final SupabaseClient _client;
  RealtimeChannel? _ordersChannel;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Stream controllers for different event types
  final _newOrderController = StreamController<String>.broadcast();
  final _updatedOrderController = StreamController<String>.broadcast();
  final _deletedOrderController =
      StreamController<
        Map<String, dynamic>
      >.broadcast(); // To pass old data if needed

  Stream<String> get newOrderStream => _newOrderController.stream;
  Stream<String> get updatedOrderStream => _updatedOrderController.stream;
  Stream<Map<String, dynamic>> get deletedOrderStream =>
      _deletedOrderController.stream;

  SupabaseRealtimeService(this._client);

  void subscribeToOrdersTable() {
    _ordersChannel = _client.channel('realtime:orders');

    _ordersChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (PostgresChangePayload payload) {
            String? orderId;

            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                orderId = payload.newRecord['id'] as String?;
                if (orderId != null) {
                  _newOrderController.add(orderId);

                  // Update last sync time in config for realtime updates
                  _updateSyncTimeForRealtime('orders');
                }
                break;
              case PostgresChangeEvent.update:
                orderId = payload.newRecord['id'] as String?;
                if (orderId != null) {
                  _updatedOrderController.add(orderId);

                  // Update last sync time in config for realtime updates
                  _updateSyncTimeForRealtime('orders');
                }
                break;
              case PostgresChangeEvent.delete:
                // For delete, the ID is in oldRecord
                final oldRecord = payload.oldRecord;
                if (oldRecord != null && oldRecord.containsKey('id')) {
                  orderId = oldRecord['id'] as String?;
                  if (orderId != null) {
                    _deletedOrderController.add({
                      'id': orderId,
                      ...oldRecord,
                    }); // Pass ID and old data

                    // Update last sync time in config for realtime updates
                    _updateSyncTimeForRealtime('orders');
                  }
                }
                break;
              default:
            }
          },
        )
        .subscribe((status, [dynamic error]) {
          if (status == 'SUBSCRIBED') {
            print('Successfully subscribed to realtime orders updates');
          } else if (status == 'CHANNEL_ERROR') {
            print(
              'Error subscribing to real-time orders updates for UI. Error: ${error?.toString()}',
            );
          } else if (status == 'TIMED_OUT') {
            print('Real-time orders subscription for UI timed out.');
          }
        });
  }

  // Helper method to update sync times when realtime events occur
  void _updateSyncTimeForRealtime(String table) {
    final String currentTime = DateTime.now().toUtc().toIso8601String();
    String configKey;

    switch (table) {
      case 'orders':
        configKey = 'last_sync_orders';
        break;
      case 'order_details':
        configKey = 'last_sync_order_details';
        break;
      case 'profiles':
        configKey = 'last_sync_profiles';
        break;
      case 'all_products':
        configKey = 'last_sync_all_products';
        break;
      default:
        return; // Unknown table
    }

    // Update the timestamp
    _dbHelper
        .setConfigValue(configKey, currentTime)
        .then(
          (_) => print('Updated last sync time for $table via realtime update'),
        )
        .catchError((error) => print('Error updating sync time: $error'));
  }

  void dispose() {
    if (_ordersChannel != null) {
      _client.removeChannel(_ordersChannel!);
      _ordersChannel = null;
    }
    _newOrderController.close();
    _updatedOrderController.close();
    _deletedOrderController.close();
  }
}
