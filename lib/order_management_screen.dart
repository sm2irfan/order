import 'dart:async';
import 'package:flutter/material.dart';
import 'package:order_management/models/order_model.dart';
import 'package:order_management/screens/desktop_order_screen.dart';
import 'package:order_management/screens/mobile_order_screen.dart';
import 'package:order_management/screens/cache_management_screen.dart';
import 'package:order_management/screens/customer_profile_screen.dart';
import 'package:order_management/services/auth_service.dart';
import 'package:order_management/services/supabase_order_service.dart';
import 'package:order_management/services/image_cache_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:order_management/main.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter = 'All';
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  Order? _selectedOrder;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<String> _orderStatuses = [
    'All',
    'Order Placed',
    'Order Processing',
    'Order Shipped',
    'Out for Delivery',
    'Delivered',
    'Order Cancelled',
  ];

  bool _isLoading = false;
  final AuthService _authService = AuthService.instance;
  final SupabaseOrderService _orderService = SupabaseOrderService();

  // Real-time subscription for orders table
  late final RealtimeChannel _ordersChannel;

  // Debouncing variables to prevent multiple rapid reloads
  Timer? _debounceTimer;
  bool _isUpdating = false;
  static const Duration _debounceDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    print('🚀 OrderManagementScreen initializing...');
    _initializeOfflineService();
    _searchController.addListener(_filterOrders);
    _setupRealtimeSubscription();
    print('👂 Search controller listener added');
  }

  // Initialize and load orders
  Future<void> _initializeOfflineService() async {
    print('🚀 Initializing and loading orders...');

    try {
      // Load orders directly from Supabase
      await _loadOrdersFromSupabase();
    } catch (e) {
      print('💥 Error loading orders: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load orders from Supabase
  Future<void> _loadOrdersOfflineFirst() async {
    print('📱 Loading orders from Supabase...');

    setState(() {
      _isLoading = true;
    });

    try {
      List<Order> orders = await _orderService.fetchOrders();

      setState(() {
        _allOrders = orders;
        _filteredOrders = orders;
        _isLoading = false;
      });

      print(
        '✅ Successfully loaded ${orders.length} orders from local database',
      );
    } catch (e) {
      print('💥 Error loading orders from local database: $e');
      setState(() {
        _isLoading = false;
      });

      // Fallback to original method
      _loadOrdersFromSupabase();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ordersChannel.unsubscribe();
    _debounceTimer?.cancel();
    print('🔌 Real-time subscription cleaned up');
    super.dispose();
  }

  /// Debounced reload to prevent multiple rapid database calls
  void _debouncedReload() {
    if (_isUpdating) {
      print('⏳ Update already in progress, skipping reload');
      return;
    }

    // Cancel existing timer
    _debounceTimer?.cancel();

    // Start new timer
    _debounceTimer = Timer(_debounceDelay, () {
      if (mounted && !_isUpdating) {
        print('🔄 Debounced reload triggered');
        _loadOrdersOfflineFirst();
      }
    });
  }

  /// Setup real-time subscription for orders table
  void _setupRealtimeSubscription() {
    print('🔄 Setting up real-time subscription for orders table...');

    final supabase = Supabase.instance.client;

    _ordersChannel =
        supabase
            .channel('orders_realtime')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'orders',
              callback: _handleOrdersRealtimeChange,
            )
            .subscribe();

    print('✅ Real-time subscription setup complete');
  }

  /// Handle real-time changes from orders table
  void _handleOrdersRealtimeChange(PostgresChangePayload payload) {
    print('🔔 Real-time change detected in orders table');
    print('📋 Event type: ${payload.eventType}');
    print('📋 Table: ${payload.table}');
    print('📋 Schema: ${payload.schema}');

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        _handleNewOrder(payload);
        break;
      case PostgresChangeEvent.update:
        _handleOrderUpdate(payload);
        break;
      case PostgresChangeEvent.delete:
        _handleOrderDelete(payload);
        break;
      default:
        print('🔍 Unknown event type: ${payload.eventType}');
    }
  }

  /// Handle new order insertion
  void _handleNewOrder(PostgresChangePayload payload) {
    final newOrderData = payload.newRecord;
    if (newOrderData['id'] != null) {
      final orderId = newOrderData['id'] as String;
      final orderStatus = newOrderData['order_status'] as String? ?? 'Unknown';
      final totalAmount = newOrderData['total_amount'] as num? ?? 0.0;
      final customerName = newOrderData['customer_name'] as String?;

      // Enhanced logging
      _logOrderChange(
        changeType: 'INSERT',
        orderId: orderId,
        newStatus: orderStatus,
        customerName: customerName,
        totalAmount: totalAmount,
        additionalData: {
          'payment_method': newOrderData['payment_method'],
          'delivery_option': newOrderData['delivery_option'],
          'created_at': newOrderData['created_at'],
        },
      );

      // Auto-refresh orders list using offline-first approach
      if (mounted) {
        _debouncedReload();
      }
    }
  }

  /// Handle order updates
  void _handleOrderUpdate(PostgresChangePayload payload) {
    final oldData = payload.oldRecord;
    final newData = payload.newRecord;

    if (newData['id'] != null) {
      final orderId = newData['id'] as String;
      final oldStatus = oldData['order_status'] as String? ?? 'Unknown';
      final newStatus = newData['order_status'] as String? ?? 'Unknown';
      final customerName = newData['customer_name'] as String?;

      // Detect what changed
      final changes = <String, dynamic>{};
      oldData.forEach((key, oldValue) {
        final newValue = newData[key];
        if (oldValue != newValue) {
          changes[key] = {'old': oldValue, 'new': newValue};
        }
      });

      // Enhanced logging
      _logOrderChange(
        changeType: 'UPDATE',
        orderId: orderId,
        oldStatus: oldStatus,
        newStatus: newStatus,
        customerName: customerName,
        totalAmount: newData['total_amount'] as num?,
        additionalData: {
          'changes_count': changes.length,
          'changed_fields': changes.keys.toList(),
          'all_changes': changes,
        },
      );

      // Auto-refresh orders list using offline-first approach for status changes
      if (oldStatus != newStatus && mounted) {
        _debouncedReload();
      }
    }
  }

  /// Handle order deletions
  void _handleOrderDelete(PostgresChangePayload payload) {
    final deletedData = payload.oldRecord;
    if (deletedData['id'] != null) {
      final orderId = deletedData['id'] as String;
      final orderStatus = deletedData['order_status'] as String? ?? 'Unknown';
      final customerName = deletedData['customer_name'] as String?;

      // Enhanced logging
      _logOrderChange(
        changeType: 'DELETE',
        orderId: orderId,
        oldStatus: orderStatus,
        customerName: customerName,
        totalAmount: deletedData['total_amount'] as num?,
        additionalData: {
          'deleted_at': DateTime.now().toIso8601String(),
          'original_created_at': deletedData['created_at'],
        },
      );

      // Auto-refresh orders list using offline-first approach for deletions
      if (mounted) {
        _debouncedReload();
      }
    }
  }

  /// Enhanced logging method for order changes
  void _logOrderChange({
    required String changeType,
    required String orderId,
    String? oldStatus,
    String? newStatus,
    String? customerName,
    num? totalAmount,
    Map<String, dynamic>? additionalData,
  }) {
    final timestamp = DateTime.now().toIso8601String();

    // Console logging with enhanced formatting
    print('📊 ================== ORDER CHANGE LOG ==================');
    print('⏰ Timestamp: $timestamp');
    print('🔄 Change Type: $changeType');
    print('📦 Order ID: $orderId');
    if (oldStatus != null) print('📋 Old Status: $oldStatus');
    if (newStatus != null) print('📋 New Status: $newStatus');
    if (customerName != null) print('👤 Customer: $customerName');
    if (totalAmount != null)
      print('💰 Amount: LKR ${totalAmount.toStringAsFixed(2)}');
    if (additionalData != null && additionalData.isNotEmpty) {
      print('📋 Additional Data:');
      additionalData.forEach((key, value) {
        print('   - $key: $value');
      });
    }
    print('================================================== END LOG');

    // Optional: Save to database by creating a log entry object
    // final logEntry = {
    //   'timestamp': timestamp,
    //   'change_type': changeType,
    //   'order_id': orderId,
    //   'old_status': oldStatus,
    //   'new_status': newStatus,
    //   'customer_name': customerName,
    //   'total_amount': totalAmount,
    //   'additional_data': additionalData,
    // };
    // _saveLogToDatabase(logEntry);
  }

  /// Optional method to save logs to a database table
  // Future<void> _saveLogToDatabase(Map<String, dynamic> logEntry) async {
  //   try {
  //     final supabase = Supabase.instance.client;
  //     await supabase.from('order_change_logs').insert(logEntry);
  //     print('✅ Log entry saved to database');
  //   } catch (e) {
  //     print('❌ Failed to save log entry: $e');
  //   }
  // }

  /// Load orders directly from Supabase function
  Future<void> _loadOrdersFromSupabase() async {
    if (!mounted) return;

    print('🚀 Starting to load orders from Supabase...');
    setState(() {
      _isLoading = true;
    });

    try {
      print('📞 Calling SupabaseOrderService.fetchOrders()...');
      final service = SupabaseOrderService();
      final List<Order> orders = await service.fetchOrders();

      print('✅ Successfully received ${orders.length} orders from service');

      // Log summary of orders
      if (orders.isNotEmpty) {
        print('📊 Orders Summary:');
        final statusCounts = <String, int>{};
        for (final order in orders) {
          statusCounts[order.orderStatus] =
              (statusCounts[order.orderStatus] ?? 0) + 1;
        }
        statusCounts.forEach((status, count) {
          print('  📋 $status: $count orders');
        });
      }

      if (mounted) {
        setState(() {
          _allOrders = orders;
          _filterOrders();
          _isLoading = false;
        });
        print('🔄 UI state updated with ${orders.length} orders');
      }
    } catch (e) {
      print('💥 Error loading orders from Supabase: $e');

      // Check if it's an authentication error
      if (e.toString().contains('Authentication expired') ||
          e.toString().contains('Invalid JWT') ||
          e.toString().contains('User not authenticated')) {
        print('🔐 Authentication error detected - signing out');

        // Sign out the user
        await Supabase.instance.client.auth.signOut();

        if (mounted) {
          // Pop back to the auth wrapper which will show login
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
          );
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _allOrders = [];
          _filteredOrders = [];
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load orders: $e')));
      }
    }
  }

  void _filterOrders() {
    String searchTerm = _searchController.text.toLowerCase();
    print(
      '🔍 Filtering orders with search: "$searchTerm", status: "$_selectedStatusFilter"',
    );

    setState(() {
      _filteredOrders =
          _allOrders.where((order) {
            bool matchesSearch =
                searchTerm.isEmpty ||
                order.id.toLowerCase().contains(searchTerm);
            bool matchesStatus =
                _selectedStatusFilter == 'All' ||
                order.orderStatus == _selectedStatusFilter;
            return matchesSearch && matchesStatus;
          }).toList();
    });

    print(
      '📊 Filtered results: ${_filteredOrders.length} orders (from ${_allOrders.length} total)',
    );
    if (_filteredOrders.isNotEmpty) {
      print(
        '🔎 Sample filtered order IDs: ${_filteredOrders.take(3).map((o) => o.id).join(", ")}',
      );
    }
  }

  void _handleOrderSelection(Order order) async {
    print('🎯 Order selected: ${order.id} (Status: ${order.orderStatus})');
    print(
      '👤 Customer: ${order.customerName ?? "Unknown"} (${order.customerPhoneNumber ?? "No phone"})',
    );
    print('💰 Total Amount: LKR ${order.totalAmount}');
    print('📦 Items: ${order.items.length}');

    setState(() {
      _selectedOrder = order;
    });
  }

  void _deselectOrder() {
    setState(() {
      _selectedOrder = null;
    });
  }

  void _modifyOrder(Order order) {
    // Placeholder for order modification logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Modify order feature coming soon')));
  }

  void _cancelOrder(Order order) {
    // Placeholder for order cancellation logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Cancel order feature coming soon')));
  }

  // Method to handle order status changes
  void _handleStatusChange(Order order, String newStatus) async {
    if (_isUpdating) {
      print('🚫 Status update already in progress, ignoring duplicate request');
      return;
    }

    _isUpdating = true;
    print(
      '🔄 Changing order ${order.id} status from "${order.orderStatus}" to "$newStatus"',
    );

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Updating order status...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      // Update status via Supabase service
      await _orderService.updateOrderStatus(order.id, newStatus);

      // Skip the automatic reload since real-time will handle it
      // Just update local state for immediate feedback
      setState(() {
        final index = _allOrders.indexWhere((o) => o.id == order.id);
        if (index != -1) {
          final updatedOrder = Order(
            id: order.id,
            userId: order.userId,
            items: order.items,
            totalAmount: order.totalAmount,
            createdAt: order.createdAt,
            orderStatus: newStatus,
            paymentMethod: order.paymentMethod,
            deliveryOption: order.deliveryOption,
            customerName: order.customerName,
            customerPhoneNumber: order.customerPhoneNumber,
            deliveryAddress: order.deliveryAddress,
            deliveryTimeSlot: order.deliveryTimeSlot,
            deliveryPartnerName: order.deliveryPartnerName,
            deliveryPartnerPhone: order.deliveryPartnerPhone,
          );
          _allOrders[index] = updatedOrder;
          _filterOrders();
        }
      });

      // Hide loading and show success
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Order ${order.id} status updated to "$newStatus"'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      print('✅ Order status updated successfully in database and UI');
    } catch (e) {
      print('❌ Error updating order status: $e');

      // Check if it's an authentication error
      if (e.toString().contains('Authentication') ||
          e.toString().contains('not authenticated') ||
          e.toString().contains('Invalid JWT')) {
        print('🔐 Authentication error detected during status update');

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Session expired. Please login again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );

        // Navigate to login
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
          );
        }
        return;
      }

      // Show generic error message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to update order status: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      _isUpdating = false;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Order Placed':
        return Colors.blue;
      case 'Order Processing':
        return Colors.orange;
      case 'Order Shipped':
        return Colors.purple;
      case 'Out for Delivery':
        return Colors.amber;
      case 'Delivered':
        return Colors.green;
      case 'Order Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStockStatusColor(String? stockQuantity) {
    if (stockQuantity == null || stockQuantity == 'N/A') {
      return Colors.grey;
    }

    final stock = int.tryParse(stockQuantity);
    if (stock == null) {
      return Colors.grey;
    }

    if (stock == 0) {
      return Colors.red; // Out of stock
    } else if (stock <= 5) {
      return Colors.orange; // Low stock
    } else {
      return Colors.green; // Good stock
    }
  }

  double _calculateSubtotal(Order order) {
    return order.items.fold(
      0.0,
      (sum, item) => sum + (item.quantity * item.price),
    );
  }

  double _calculateTotalDiscount(Order order) {
    return order.items.fold(0.0, (sum, item) => sum + (item.discount ?? 0));
  }

  // Method to make phone calls
  Future<void> _makePhoneCall(String phoneNumber) async {
    print('📞 Attempting to make call to: $phoneNumber');

    // Clean the phone number (remove spaces, dashes, etc.)
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    print('📞 Cleaned number: $cleanedNumber');

    final Uri phoneUri = Uri(scheme: 'tel', path: cleanedNumber);

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        print('✅ Phone call initiated successfully');
      } else {
        print('❌ Cannot launch phone dialer');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to make phone call from this device'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('💥 Error making phone call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to make phone call: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: SelectableText(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16, // Increased font size
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 16, // Increased font size
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to build a clickable phone number row
  Widget _buildPhoneRow(String label, String phoneNumber) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: SelectableText(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16, // Increased font size
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _makePhoneCall(phoneNumber),
              child: Text(
                phoneNumber,
                style: const TextStyle(
                  fontSize: 16, // Increased font size
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to build a clickable link row
  Widget _buildLinkRow(String label, String link) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: SelectableText(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _openLink(link),
              child: Text(
                link,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to build a clickable profile number row
  Widget _buildProfileNumberRow(String label, int profileNumber) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: SelectableText(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToCustomerProfile(profileNumber),
              child: Text(
                profileNumber.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to navigate to customer profile screen
  void _navigateToCustomerProfile(int profileNumber) {
    print('🔗 Navigating to customer profile for profile #$profileNumber');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) =>
                CustomerProfileScreen(initialProfileNumber: profileNumber),
      ),
    );
  }

  // Method to open link in browser
  Future<void> _openLink(String link) async {
    try {
      final uri = Uri.parse(link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ Opened link: $link');
      } else {
        print('❌ Could not launch link: $link');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not open link: $link')));
        }
      }
    } catch (e) {
      print('💥 Error opening link: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
      }
    }
  }

  // Method to handle status filter changes in mobile view
  void _handleStatusFilterChange(String? newValue) {
    setState(() {
      _selectedStatusFilter = newValue;
      _filterOrders();
    });
  }

  // Method to show order details on mobile
  void _showMobileOrderDetails(BuildContext context, Order order) {
    _handleOrderSelection(order);
    showDialog(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: SelectableText(
              'Order Details: ${order.id}',
              style: const TextStyle(
                fontSize: 20, // Increased font size
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Status:', order.orderStatus),
                  _buildDetailRow(
                    'Date:',
                    '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                  ),
                  if (order.customerName != null)
                    _buildDetailRow('Customer:', order.customerName!),
                  if (order.customerPhoneNumber != null)
                    _buildPhoneRow('Phone:', order.customerPhoneNumber!),
                  if (order.profileNumber != null)
                    _buildProfileNumberRow('Profile #:', order.profileNumber!),
                  if (order.link != null) _buildLinkRow('Link:', order.link!),
                  if (order.geographicCoordinates != null)
                    _buildDetailRow(
                      'Coordinates:',
                      order.geographicCoordinates!,
                    ),
                  _buildDetailRow('Payment:', order.paymentMethod),
                  _buildDetailRow('Delivery:', order.deliveryOption),
                  if (order.deliveryTimeSlot != null)
                    _buildDetailRow('Time Slot:', order.deliveryTimeSlot!),
                  if (order.deliveryAddress != null)
                    _buildDetailRow('Address:', order.deliveryAddress!),
                  _buildDetailRow(
                    'Total:',
                    'LKR ${order.totalAmount.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 16),
                  const SelectableText(
                    'Items:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18, // Increased font size
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...order.items.map((item) {
                    // Calculate unit price properly
                    final unitPrice = item.price / item.quantity;
                    final totalPrice = item.price - (item.discount ?? 0);

                    return GestureDetector(
                      onTap: () {
                        print('🖱️ Product name tapped: ${item.productName}');
                        _showProductImage(context, item);
                      },
                      child: ListTile(
                        dense: true,
                        title: Text(
                          item.productName,
                          style: TextStyle(
                            color:
                                item.productImageUrl != null
                                    ? Colors.blue
                                    : null,
                            decoration:
                                item.productImageUrl != null
                                    ? TextDecoration.underline
                                    : null,
                            fontSize: 16, // Increased font size
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product ID: ${item.productId}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${item.quantity} ${item.unit} @ LKR ${unitPrice.toStringAsFixed(2)} each',
                              style: const TextStyle(
                                fontSize: 14, // Increased font size
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (item.stockQuantity != null)
                              Text(
                                'Stock: ${item.stockQuantity}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStockStatusColor(
                                    item.stockQuantity,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (item.profit != null)
                              Text(
                                'Profit: LKR ${item.profit!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      item.profit! > 0
                                          ? Colors.green
                                          : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        trailing: Text(
                          'LKR ${totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16, // Increased font size
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16, // Increased font size
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
    );
  }

  // Method to show product image dialog
  void _showProductImage(BuildContext context, OrderDetail item) {
    print('🖼️ _showProductImage called for: ${item.productName}');
    print('🖼️ Product image URL: ${item.productImageUrl}');

    if (item.productImageUrl == null || item.productImageUrl!.isEmpty) {
      print('❌ No image URL available for ${item.productName}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No image available for this product'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    print(
      '✅ Showing image dialog for ${item.productName} with URL: ${item.productImageUrl}',
    );

    showDialog(
      context: context,
      builder:
          (BuildContext context) => Dialog(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ProductImageWidget(
                    imageUrl: item.productImageUrl,
                    size: 300,
                    onTap: () {
                      print('🖼️ Image tapped - opening full screen');
                      _showFullScreenImage(context, item);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap image to view full screen',
                    style: TextStyle(
                      fontSize: 14, // Increased from 12
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Method to show product image in full screen
  void _showFullScreenImage(BuildContext context, OrderDetail item) {
    print('🖼️ _showFullScreenImage called for: ${item.productName}');

    if (item.productImageUrl == null || item.productImageUrl!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image not available')));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => FullScreenImageViewer(
              imageUrl: item.productImageUrl!,
              productName: item.productName,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const SelectableText('Order Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Orders',
            onPressed: _loadOrdersFromSupabase,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String value) {
              switch (value) {
                case 'customer_profile':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CustomerProfileScreen(),
                    ),
                  );
                  break;
                case 'cache':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CacheManagementScreen(),
                    ),
                  );
                  break;
                case 'logout':
                  _authService.handleLogout(context);
                  break;
              }
            },
            itemBuilder:
                (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'customer_profile',
                    child: ListTile(
                      leading: Icon(Icons.person),
                      title: Text('Customer Profile'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'cache',
                    child: ListTile(
                      leading: Icon(Icons.image),
                      title: Text('Cache Management'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Logout'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              color: Colors.grey[200],
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.0),
                      ),
                      SizedBox(width: 12),
                      Text('Loading orders...'),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child:
                isDesktop
                    ? DesktopOrderScreen(
                      allOrders: _allOrders,
                      filteredOrders: _filteredOrders,
                      selectedOrder: _selectedOrder,
                      selectedStatusFilter: _selectedStatusFilter,
                      orderStatuses: _orderStatuses,
                      searchController: _searchController,
                      onOrderSelect: _handleOrderSelection,
                      onDeselectOrder: _deselectOrder,
                      onModifyOrder: _modifyOrder,
                      onCancelOrder: _cancelOrder,
                      getStatusColor: _getStatusColor,
                      calculateSubtotal: _calculateSubtotal,
                      calculateDiscount: _calculateTotalDiscount,
                      buildDetailRow: _buildDetailRow,
                      onPhoneNumberTap: _makePhoneCall,
                      onProfileNumberTap: _navigateToCustomerProfile,
                    )
                    : MobileOrderScreen(
                      filteredOrders: _filteredOrders,
                      selectedStatusFilter: _selectedStatusFilter,
                      orderStatuses: _orderStatuses,
                      searchController: _searchController,
                      onFilterChange: _handleStatusFilterChange,
                      onShowDetails: _showMobileOrderDetails,
                      getStatusColor: _getStatusColor,
                      onOrderUpdate: _modifyOrder,
                      onOrderSelect: _handleOrderSelection,
                      onStatusChange: _handleStatusChange,
                    ),
          ),
        ],
      ),
    );
  }
}
