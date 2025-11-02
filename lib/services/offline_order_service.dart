import 'dart:async';
import 'package:order_management/database/database_helper.dart';
import 'package:order_management/models/order_model.dart';
import 'package:order_management/services/supabase_order_service.dart';
import 'package:order_management/services/image_cache_service.dart';

class OfflineOrderService {
  static final OfflineOrderService _instance = OfflineOrderService._internal();
  factory OfflineOrderService() => _instance;
  OfflineOrderService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SupabaseOrderService _remoteService = SupabaseOrderService();

  Timer? _syncTimer;
  bool _isInitialized = false;
  bool _isOnline = true;
  bool _isSyncing = false;

  // Initialize offline service
  Future<void> initialize() async {
    if (_isInitialized) {
      print('ℹ️ OfflineOrderService already initialized, skipping...');
      return;
    }

    print('🔄 Initializing OfflineOrderService...');

    // Add small delay to ensure database is ready
    await Future.delayed(const Duration(milliseconds: 100));

    // Initial sync from remote to local (only once during initialization)
    await syncOrdersFromRemote();

    // Start periodic sync only after initial sync is complete
    _startPeriodicSync();

    _isInitialized = true;
    print('✅ OfflineOrderService initialized');
  }

  // Dispose resources
  void dispose() {
    _syncTimer?.cancel();
  }

  // Get orders (offline-first approach)
  Future<List<Order>> getOrders() async {
    try {
      print('📱 Loading orders from local database...');

      // Check database health first
      bool isHealthy = await _dbHelper.checkDatabaseHealth();
      if (!isHealthy) {
        print('⚠️ Database unhealthy, falling back to remote');
        return await _remoteService.fetchOrders();
      }

      // Get orders from local database
      List<Map<String, dynamic>> ordersData =
          await _dbHelper.getOrdersWithDetails();

      // Convert to Order objects
      List<Order> orders = [];
      for (Map<String, dynamic> orderData in ordersData) {
        List<OrderDetail> items = [];

        if (orderData['details'] != null) {
          for (Map<String, dynamic> detailData in orderData['details']) {
            items.add(OrderDetail.fromMap(detailData));
          }
        }

        orders.add(Order.fromMap(orderData, items));
      }

      print(
        '✅ Successfully loaded ${orders.length} orders from local database',
      );

      // Preload images in background for better user experience
      _preloadOrderImages(orders);

      return orders;
    } catch (e) {
      print('❌ Error loading orders from local database: $e');
      rethrow;
    }
  }

  // Get orders by status (offline-first)
  Future<List<Order>> getOrdersByStatus(String status) async {
    try {
      List<Map<String, dynamic>> ordersData = await _dbHelper.getOrdersByStatus(
        status,
      );

      List<Order> orders = [];
      for (Map<String, dynamic> orderData in ordersData) {
        List<OrderDetail> items = [];

        if (orderData['details'] != null) {
          for (Map<String, dynamic> detailData in orderData['details']) {
            items.add(OrderDetail.fromMap(detailData));
          }
        }

        orders.add(Order.fromMap(orderData, items));
      }

      return orders;
    } catch (e) {
      print('❌ Error loading orders by status: $e');
      rethrow;
    }
  }

  // Search orders
  Future<List<Order>> searchOrders(String query) async {
    try {
      List<Map<String, dynamic>> ordersData = await _dbHelper.searchOrders(
        query,
      );

      List<Order> orders = [];
      for (Map<String, dynamic> orderData in ordersData) {
        List<OrderDetail> items = [];

        if (orderData['details'] != null) {
          for (Map<String, dynamic> detailData in orderData['details']) {
            items.add(OrderDetail.fromMap(detailData));
          }
        }

        orders.add(Order.fromMap(orderData, items));
      }

      return orders;
    } catch (e) {
      print('❌ Error searching orders: $e');
      rethrow;
    }
  }

  // Update order status (offline-first)
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      // Update locally first
      await _dbHelper.updateOrderStatus(orderId, newStatus);
      print('✅ Order $orderId status updated locally to $newStatus');

      // Try to sync to remote in background
      _syncStatusUpdateToRemote(orderId, newStatus);
    } catch (e) {
      print('❌ Error updating order status: $e');
      rethrow;
    }
  }

  // Sync orders from remote to local
  Future<void> syncOrdersFromRemote() async {
    if (_isSyncing) {
      print('⏳ Sync already in progress, skipping duplicate sync request...');
      return;
    }

    _isSyncing = true;
    print('🌐 Syncing orders from remote to local...');

    try {
      // Fetch product names cache first if needed
      try {
        print('🔄 Fetching product names for caching...');
        await SupabaseOrderService.fetchProductNames();
      } catch (e) {
        print('⚠️ Failed to fetch product names: $e');
      }

      // Fetch orders from remote
      List<Order> remoteOrders = await _remoteService.fetchOrders();
      print('📥 Received ${remoteOrders.length} orders from remote');

      // Save each order to local database
      int processedCount = 0;
      for (Order order in remoteOrders) {
        Map<String, dynamic> orderData = order.toMap();

        // Add items to the order data
        orderData['items'] =
            order.items.map((item) {
              Map<String, dynamic> itemMap = item.toMap();
              itemMap['order_id'] = order.id;
              itemMap['created_at'] = order.createdAt.toIso8601String();
              itemMap['updated_at'] = order.createdAt.toIso8601String();
              return itemMap;
            }).toList();

        await _dbHelper.saveOrderToLocal(orderData);
        processedCount++;
      }

      print('✅ Successfully synced ${processedCount} orders to local database');
      _isOnline = true;
    } catch (e) {
      print('❌ Failed to sync from remote (probably offline): $e');
      _isOnline = false;
    } finally {
      _isSyncing = false;
    }
  }

  // Background sync of status update to remote
  Future<void> _syncStatusUpdateToRemote(
    String orderId,
    String newStatus,
  ) async {
    try {
      if (_isOnline) {
        await _remoteService.updateOrderStatus(orderId, newStatus);
        print('✅ Order $orderId status synced to remote');
      }
    } catch (e) {
      print('⚠️ Failed to sync status to remote (will retry later): $e');
      _isOnline = false;
      // TODO: Add to pending sync queue
    }
  }

  // Start periodic sync
  void _startPeriodicSync() {
    // Add a longer delay before starting periodic sync to avoid conflicts with initial sync
    Timer(const Duration(seconds: 30), () {
      _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
        if (!_isSyncing) {
          print('🔄 Periodic sync triggered');
          syncOrdersFromRemote();
        } else {
          print('⏳ Skipping periodic sync - sync already in progress');
        }
      });
      print(
        '🔄 Periodic sync started (every 5 minutes, started after 30 seconds delay)',
      );
    });
  }

  // Get order status counts
  Future<Map<String, int>> getOrderStatusCounts() async {
    try {
      return await _dbHelper.getOrderStatusCounts();
    } catch (e) {
      print('❌ Error getting order status counts: $e');
      return {};
    }
  }

  // Force full sync
  Future<void> forceSync() async {
    print('🔄 Force syncing all data...');

    try {
      // Just sync orders for now
      await syncOrdersFromRemote();
      print('✅ Force sync completed successfully');
      _isOnline = true;
    } catch (e) {
      print('❌ Force sync error: $e');
      _isOnline = false;
      rethrow;
    }
  }

  // Get connectivity status
  bool get isOnline => _isOnline;

  // Preload product images in the background for better user experience
  void _preloadOrderImages(List<Order> orders) async {
    try {
      List<String> imageUrls = [];

      for (Order order in orders) {
        for (OrderDetail item in order.items) {
          if (item.productImageUrl != null &&
              item.productImageUrl!.isNotEmpty) {
            imageUrls.add(item.productImageUrl!);
          }
        }
      }

      if (imageUrls.isNotEmpty) {
        print('🖼️ Starting to preload ${imageUrls.length} product images...');
        // Preload images in background without blocking UI
        ProductImageCacheManager.preloadImages(imageUrls)
            .then((_) {
              print('✅ Completed preloading ${imageUrls.length} images');
            })
            .catchError((e) {
              print('⚠️ Some images failed to preload: $e');
            });
      }
    } catch (e) {
      print('❌ Error during image preloading setup: $e');
    }
  }

  // Get sync status
  bool get isSyncing => _isSyncing;
}
