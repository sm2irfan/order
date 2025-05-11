// filepath: /home/irfan/StudioProjects/Order/order_management/lib/order_management_screen.dart
import 'package:flutter/material.dart';
import 'package:order_management/models/order_model.dart';
import 'package:order_management/screens/desktop_order_screen.dart';
import 'package:order_management/screens/mobile_order_screen.dart';

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
    'In Transit',
    'Delivered',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadSampleOrders();
    _filterOrders();
    _searchController.addListener(_filterOrders);
  }

  void _loadSampleOrders() {
    // Sample data mimicking the SQL structure
    _allOrders = [
      Order(
        id: 'ORD001',
        userId: 'user1-uuid-example',
        totalAmount: 250.75,
        deliveryOption: 'Home Delivery',
        deliveryAddress: '123 Main St, Colombo',
        deliveryTimeSlot: '10 AM - 12 PM',
        paymentMethod: 'Credit Card',
        orderStatus: 'Delivered',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        deliveryPartnerName: 'QuickDeliv',
        deliveryPartnerPhone: '0771234567',
        items: [
          OrderDetail(
            productId: 101,
            productName: 'Apples',
            quantity: 2,
            unit: 'kg',
            price: 100.00,
            discount: 5,
          ),
          OrderDetail(
            productId: 102,
            productName: 'Milk',
            quantity: 1,
            unit: 'L',
            price: 50.75,
          ),
        ],
      ),
      Order(
        id: 'ORD002',
        userId: 'user2-uuid-example',
        totalAmount: 150.50,
        deliveryOption: 'Store Pickup',
        paymentMethod: 'Cash on Delivery',
        orderStatus: 'In Transit',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        deliveryPartnerName: 'FastMovers',
        deliveryPartnerPhone: '0719876543',
        items: [
          OrderDetail(
            productId: 103,
            productName: 'Bread',
            quantity: 5,
            unit: 'pack',
            price: 20.00,
            discount: 10,
          ),
          OrderDetail(
            productId: 101,
            productName: 'Bananas',
            quantity: 1,
            unit: 'kg',
            price: 50.50,
          ),
        ],
      ),
      Order(
        id: 'ORD003',
        userId: 'user3-uuid-example',
        totalAmount: 75.00,
        deliveryOption: 'Home Delivery',
        deliveryAddress: '456 Lake Rd, Kandy',
        deliveryTimeSlot: '2 PM - 4 PM',
        paymentMethod: 'Mobile Payment',
        orderStatus: 'Order Placed',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        items: [
          OrderDetail(
            productId: 102,
            productName: 'Eggs',
            quantity: 3,
            unit: 'dozen',
            price: 25.00,
          ),
        ],
      ),
      Order(
        id: 'ORD004',
        userId: 'user4-uuid-example',
        totalAmount: 90.00,
        deliveryOption: 'Home Delivery',
        deliveryAddress: '789 Beach Ave, Galle',
        deliveryTimeSlot: 'ASAP',
        paymentMethod: 'Credit Card',
        orderStatus: 'Cancelled',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        items: [
          OrderDetail(
            productId: 105,
            productName: 'Juice',
            quantity: 2,
            unit: 'bottle',
            price: 45.00,
          ),
        ],
      ),
    ];
  }

  void _filterOrders() {
    String searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredOrders =
          _allOrders.where((order) {
            final matchesSearchTerm = order.id.toLowerCase().contains(
              searchTerm,
            );
            final matchesStatus =
                _selectedStatusFilter == 'All' ||
                order.orderStatus == _selectedStatusFilter;
            return matchesSearchTerm && matchesStatus;
          }).toList();

      // Update selected order if needed
      if (_selectedOrder != null && !_filteredOrders.contains(_selectedOrder)) {
        _selectedOrder = _filteredOrders.isNotEmpty ? _filteredOrders[0] : null;
      } else if (_selectedOrder == null && _filteredOrders.isNotEmpty) {
        _selectedOrder = _filteredOrders[0];
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleOrderSelection(Order order) {
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
    // Implement modification logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Modify action for ${order.id}')));
  }

  void _cancelOrder(Order order) {
    // Implement cancellation logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Cancel action for ${order.id}')));
  }

  double _calculateSubtotal(Order order) {
    return order.items.fold(
      0,
      (sum, item) => sum + (item.quantity * item.price),
    );
  }

  double _calculateTotalDiscount(Order order) {
    return order.items.fold(0, (sum, item) => sum + (item.discount ?? 0));
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Delivered':
        return Colors.green;
      case 'In Transit':
        return Colors.blue;
      case 'Order Placed':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showOrderDetailsDialog(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Order Details: ${order.id}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildDetailRow('Status:', order.orderStatus),
                _buildDetailRow(
                  'Total Amount:',
                  'LKR ${order.totalAmount.toStringAsFixed(2)}',
                ),
                _buildDetailRow('Payment Method:', order.paymentMethod),
                _buildDetailRow('Delivery Option:', order.deliveryOption),
                if (order.deliveryAddress != null)
                  _buildDetailRow('Delivery Address:', order.deliveryAddress!),
                if (order.deliveryTimeSlot != null)
                  _buildDetailRow('Time Slot:', order.deliveryTimeSlot!),
                if (order.deliveryPartnerName != null)
                  _buildDetailRow(
                    'Delivery Partner:',
                    order.deliveryPartnerName!,
                  ),
                if (order.deliveryPartnerPhone != null)
                  _buildDetailRow(
                    'Partner Phone:',
                    order.deliveryPartnerPhone!,
                  ),
                const SizedBox(height: 10),
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...order.items.map(
                  (item) => ListTile(
                    title: Text('${item.productName} (ID: ${item.productId})'),
                    subtitle: Text(
                      '${item.quantity} ${item.unit} @ LKR ${item.price.toStringAsFixed(2)} each',
                    ),
                    trailing: Text('LKR ${item.itemTotal.toStringAsFixed(2)}'),
                  ),
                ),
                if (order.orderStatus == 'Order Placed') ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text('Modify Order'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _modifyOrder(order);
                        },
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Cancel Order'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _cancelOrder(order);
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Detect if we're on a desktop-sized screen
    final bool isDesktop = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Grocery Order Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Orders',
            onPressed: () {
              _loadSampleOrders();
              _filterOrders();
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body:
          isDesktop
              ? DesktopOrderScreen(
                allOrders: _allOrders,
                filteredOrders: _filteredOrders,
                selectedOrder: _selectedOrder,
                selectedStatusFilter: _selectedStatusFilter,
                orderStatuses: _orderStatuses,
                searchController: _searchController,
                onOrderSelect: _handleOrderSelection,
                onDeselectOrder: _deselectOrder, // Add this new callback
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
                onFilterChange: (String? newValue) {
                  setState(() {
                    _selectedStatusFilter = newValue;
                    _filterOrders();
                  });
                },
                onShowDetails: _showOrderDetailsDialog,
                getStatusColor: _getStatusColor,
              ),
    );
  }
}
