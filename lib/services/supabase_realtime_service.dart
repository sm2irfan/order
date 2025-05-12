import 'dart:async'; // Import async
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRealtimeService {
  final SupabaseClient _client;
  RealtimeChannel? _ordersChannel;

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
                }
                break;
              case PostgresChangeEvent.update:
                orderId = payload.newRecord['id'] as String?;
                if (orderId != null) {
                  _updatedOrderController.add(orderId);
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
                  }
                }
                break;
              default:
            }
          },
        )
        .subscribe((status, [dynamic error]) {
          if (status == 'SUBSCRIBED') {
          } else if (status == 'CHANNEL_ERROR') {
            print(
              'Error subscribing to real-time orders updates for UI. Error: ${error?.toString()}',
            );
          } else if (status == 'TIMED_OUT') {
            print('Real-time orders subscription for UI timed out.');
          }
        });
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
