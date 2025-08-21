import 'dart:async';
import 'package:flutter/material.dart';
import 'package:order_management/models/order_model.dart';
import 'package:order_management/screens/desktop_order_screen.dart';
import 'package:order_management/screens/mobile_order_screen.dart';
import 'package:order_management/services/auth_service.dart';
import 'package:order_management/services/supabase_order_service.dart';

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
    _loadOrdersFromSupabase();
    _searchController.addListener(_filterOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load orders directly from Supabase function
  Future<void> _loadOrdersFromSupabase() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = SupabaseOrderService();
      final List<Order> orders = await service.fetchOrders();

      if (mounted) {
        setState(() {
          _allOrders = orders;
          _filterOrders();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading orders from Supabase: $e');
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
  }

  void _handleOrderSelection(Order order) async {
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
        return Colors.orange;
      case 'Order Processing':
        return Colors.blue;
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
                  ...order.items.map(
                    (item) => ListTile(
                      dense: true,
                      title: SelectableText(item.productName),
                      subtitle: SelectableText(
                        '${item.quantity} ${item.unit} @ LKR ${item.price.toStringAsFixed(2)} each',
                      ),
                      trailing: SelectableText(
                        'LKR ${item.itemTotal.toStringAsFixed(2)}',
                      ),
                    ),
                  ),
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
