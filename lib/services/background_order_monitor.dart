import 'dart:async';
import 'package:order_management/services/ringtone_service.dart';
import 'package:order_management/services/supabase_order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundOrderMonitor {
  static const String _lastOrderCountKey = 'last_order_count';
  static const String _lastOrderIdKey = 'last_order_id';
  static const String _isMonitoringKey = 'is_monitoring_enabled';

  static Timer? _backgroundTimer;
  static bool _isMonitoring = false;
  static int _lastKnownOrderCount = 0;
  static String? _lastKnownOrderId;

  /// Start background monitoring for new orders
  static Future<void> startMonitoring() async {
    if (_isMonitoring) {
      print('🔄 Background order monitoring already running');
      return;
    }

    print('🚀 Starting background order monitoring...');

    // Initialize with current state
    await _initializeState();

    // Enable monitoring flag
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isMonitoringKey, true);
    _isMonitoring = true;

    // Start periodic checking every 30 seconds
    _backgroundTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _checkForNewOrders();
    });

    print('✅ Background order monitoring started (checking every 30 seconds)');
  }

  /// Stop background monitoring
  static Future<void> stopMonitoring() async {
    print('🛑 Stopping background order monitoring...');

    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    _isMonitoring = false;

    // Update preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isMonitoringKey, false);

    print('✅ Background order monitoring stopped');
  }

  /// Initialize the monitoring state with current order data
  static Future<void> _initializeState() async {
    try {
      print('🔄 Initializing background monitor state...');

      final service = SupabaseOrderService();
      final orders = await service.fetchOrders();

      _lastKnownOrderCount = orders.length;
      if (orders.isNotEmpty) {
        // Sort by creation date to get the most recent order
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _lastKnownOrderId = orders.first.id;
      }

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastOrderCountKey, _lastKnownOrderCount);
      if (_lastKnownOrderId != null) {
        await prefs.setString(_lastOrderIdKey, _lastKnownOrderId!);
      }

      print(
        '📊 Initialized with $_lastKnownOrderCount orders, latest: $_lastKnownOrderId',
      );
    } catch (e) {
      print('❌ Error initializing background monitor state: $e');
    }
  }

  /// Check for new orders and trigger ringtone if found
  static Future<void> _checkForNewOrders() async {
    if (!_isMonitoring) return;

    try {
      print('🔍 Checking for new orders in background...');

      final service = SupabaseOrderService();
      final currentOrders = await service.fetchOrders();

      // Check if we have more orders than before OR new order with same count
      final currentOrderCount = currentOrders.length;

      // Sort orders by creation date to get the newest one
      currentOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final newestOrder = currentOrders.isNotEmpty ? currentOrders.first : null;
      final currentNewestId = newestOrder?.id;

      if (currentOrderCount > _lastKnownOrderCount) {
        // More orders than before - definitely new orders!
        final newOrdersCount = currentOrderCount - _lastKnownOrderCount;
        print('🎉 NEW ORDERS DETECTED: $newOrdersCount new orders found!');

        if (newestOrder != null) {
          print('🔔 Confirmed new order: ${newestOrder.id}');
          print('👤 Customer: ${newestOrder.customerName ?? "Unknown"}');
          print('💰 Amount: LKR ${newestOrder.totalAmount}');

          // 🔔 AUTOMATICALLY ENABLE RINGTONE FOR NEW ORDER
          try {
            await RingtoneService.enableRingtone();
            print(
              '🔔 BACKGROUND: Ringtone automatically enabled for new order ${newestOrder.id}',
            );
          } catch (e) {
            print('❌ Error enabling ringtone in background: $e');
          }

          // Update our tracking
          _lastKnownOrderCount = currentOrderCount;
          _lastKnownOrderId = newestOrder.id;

          // Save to preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_lastOrderCountKey, _lastKnownOrderCount);
          await prefs.setString(_lastOrderIdKey, _lastKnownOrderId!);

          print('✅ Background monitoring state updated');
        }
      } else if (currentOrderCount == _lastKnownOrderCount &&
          newestOrder != null &&
          (_lastKnownOrderId == null || currentNewestId != _lastKnownOrderId)) {
        // Same count but different newest order - new order replaced an old one!
        print('🎉 NEW ORDER DETECTED: Same count but newest order changed!');
        print('🔄 Previous newest: $_lastKnownOrderId');
        print('🆕 Current newest: $currentNewestId');
        print('🔔 Confirmed new order: ${newestOrder.id}');
        print('👤 Customer: ${newestOrder.customerName ?? "Unknown"}');
        print('💰 Amount: LKR ${newestOrder.totalAmount}');

        // 🔔 AUTOMATICALLY ENABLE RINGTONE FOR NEW ORDER
        try {
          await RingtoneService.enableRingtone();
          print(
            '🔔 BACKGROUND: Ringtone automatically enabled for new order ${newestOrder.id}',
          );
        } catch (e) {
          print('❌ Error enabling ringtone in background: $e');
        }

        // Update our tracking
        _lastKnownOrderCount = currentOrderCount;
        _lastKnownOrderId = newestOrder.id;

        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastOrderCountKey, _lastKnownOrderCount);
        await prefs.setString(_lastOrderIdKey, _lastKnownOrderId!);

        print('✅ Background monitoring state updated');
      } else if (currentOrderCount == _lastKnownOrderCount) {
        print('📊 No new orders detected (count: $currentOrderCount)');
      } else {
        // Fewer orders than before - possibly deleted orders
        print(
          '⚠️ Order count decreased from $_lastKnownOrderCount to $currentOrderCount',
        );
        _lastKnownOrderCount = currentOrderCount;

        // Update tracking with the newest order if any exist
        if (currentOrders.isNotEmpty) {
          currentOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _lastKnownOrderId = currentOrders.first.id;
        } else {
          _lastKnownOrderId = null;
        }

        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastOrderCountKey, _lastKnownOrderCount);
        if (_lastKnownOrderId != null) {
          await prefs.setString(_lastOrderIdKey, _lastKnownOrderId!);
        } else {
          await prefs.remove(_lastOrderIdKey);
        }
      }
    } catch (e) {
      print('❌ Error checking for new orders in background: $e');
    }
  }

  /// Restore monitoring state from preferences on app start
  static Future<void> restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if monitoring was enabled
      final wasMonitoring = prefs.getBool(_isMonitoringKey) ?? false;

      // Restore tracking data
      _lastKnownOrderCount = prefs.getInt(_lastOrderCountKey) ?? 0;
      _lastKnownOrderId = prefs.getString(_lastOrderIdKey);

      print('🔄 Restored background monitor state:');
      print('   - Was monitoring: $wasMonitoring');
      print('   - Last count: $_lastKnownOrderCount');
      print('   - Last ID: $_lastKnownOrderId');

      // If monitoring was enabled, restart it
      if (wasMonitoring) {
        await startMonitoring();
      }
    } catch (e) {
      print('❌ Error restoring background monitor state: $e');
    }
  }

  /// Check if monitoring is currently active
  static bool get isMonitoring => _isMonitoring;

  /// Get the current monitoring status
  static Map<String, dynamic> getStatus() {
    return {
      'isMonitoring': _isMonitoring,
      'lastKnownOrderCount': _lastKnownOrderCount,
      'lastKnownOrderId': _lastKnownOrderId,
      'hasTimer': _backgroundTimer != null && _backgroundTimer!.isActive,
    };
  }

  /// Manually trigger a check for new orders (useful for testing)
  static Future<void> checkNow() async {
    print('🔍 Manual check for new orders triggered...');
    await _checkForNewOrders();
  }

  /// Update the known state when orders are refreshed in the UI
  static Future<void> updateKnownState(List<dynamic> orders) async {
    if (orders.isEmpty) return;

    try {
      _lastKnownOrderCount = orders.length;

      // Find the newest order
      var newestOrder = orders.first;
      for (var order in orders) {
        if (order.createdAt != null && newestOrder.createdAt != null) {
          if (order.createdAt.isAfter(newestOrder.createdAt)) {
            newestOrder = order;
          }
        }
      }

      _lastKnownOrderId = newestOrder.id;

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastOrderCountKey, _lastKnownOrderCount);
      await prefs.setString(_lastOrderIdKey, _lastKnownOrderId!);

      print(
        '🔄 Updated known state: $_lastKnownOrderCount orders, newest: $_lastKnownOrderId',
      );
    } catch (e) {
      print('❌ Error updating known state: $e');
    }
  }
}
