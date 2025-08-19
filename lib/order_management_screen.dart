import 'dart:async';
import 'package:flutter/material.dart';
import 'package:order_management/models/order_model.dart';
import 'package:order_management/screens/desktop_order_screen.dart';
import 'package:order_management/screens/mobile_order_screen.dart';
import 'package:order_management/services/auth_service.dart';
import 'package:order_management/services/supabase_order_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:order_management/main.dart';

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

  @override
  void initState() {
    super.initState();
    print('🚀 OrderManagementScreen initializing...');
    _loadOrdersFromSupabase();
    _searchController.addListener(_filterOrders);
    print('👂 Search controller listener added');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  double _calculateSubtotal(Order order) {
    return order.items.fold(
      0.0,
      (sum, item) => sum + (item.quantity * item.price),
    );
  }

  double _calculateTotalDiscount(Order order) {
    return order.items.fold(0.0, (sum, item) => sum + (item.discount ?? 0));
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
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
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
            title: SelectableText('Order Details: ${order.id}'),
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
                    _buildDetailRow('Phone:', order.customerPhoneNumber!),
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
                    style: TextStyle(fontWeight: FontWeight.bold),
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
                          ),
                        ),
                        subtitle: Text(
                          '${item.quantity} ${item.unit} @ LKR ${unitPrice.toStringAsFixed(2)} each',
                        ),
                        trailing: Text('LKR ${totalPrice.toStringAsFixed(2)}'),
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Close'),
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
                  GestureDetector(
                    onTap: () {
                      print('🖼️ Image tapped - opening full screen');
                      _showFullScreenImage(context, item);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.productImageUrl!,
                        fit: BoxFit.contain,
                        height: 300,
                        width: 300,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SizedBox(
                            height: 300,
                            width: 300,
                            child: Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 300,
                            width: 300,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap image to view full screen',
                    style: TextStyle(
                      fontSize: 12,
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

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (BuildContext context) => Scaffold(
            backgroundColor: Colors.transparent,
            body: GestureDetector(
              onTap: () {
                print('🖼️ Full screen image tapped - closing');
                Navigator.of(context).pop();
              },
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Product name at the top
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Full screen image
                    Expanded(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.network(
                          item.productImageUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 96,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Instructions at the bottom
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      child: const Column(
                        children: [
                          Text(
                            'Pinch to zoom • Tap to close',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Icon(Icons.close, color: Colors.white70, size: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _authService.handleLogout(context),
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
                    ),
          ),
        ],
      ),
    );
  }
}
