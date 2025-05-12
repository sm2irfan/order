// filepath: /home/irfan/StudioProjects/Order/order_management/lib/order_management_screen.dart
import 'package:flutter/material.dart';
import 'package:order_management/models/order_model.dart';
import 'package:order_management/screens/desktop_order_screen.dart';
import 'package:order_management/screens/mobile_order_screen.dart';
import 'package:order_management/services/auth_service.dart';
import 'package:order_management/services/sync_service.dart';
import 'package:order_management/database/database_helper.dart';

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

  // Keep track of which order details are being fetched
  final Set<String> _fetchingOrderDetailsFor = {};

  final List<String> _orderStatuses = [
    'All',
    'Order Placed',
    'Order Processing',
    'Order Shipped',
    'Out for Delivery',
    'Delivered',
    'Order Cancelled',
  ];

  bool _isSyncing = false;
  final SyncService _syncService = SyncService.instance;
  final AuthService _authService = AuthService.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadOrdersFromDatabase();
    _searchController.addListener(_filterOrders);
  }

  Future<void> _loadOrdersFromDatabase() async {
    try {
      setState(() {
        _isSyncing = true;
      });

      final List<Map<String, dynamic>> ordersData = await _dbHelper.getOrders();
      print('Total orders fetched: ${ordersData.length}');

      final List<Map<String, dynamic>> productsData =
          await _dbHelper.getProducts();
      final Map<int, String> productNameMap = {};
      for (var product in productsData) {
        try {
          productNameMap[product['id'] as int] = product['name'] as String;
        } catch (e) {
          print('Error mapping product: ${e.toString()}');
        }
      }

      final List<Order> loadedOrders = [];

      for (final orderData in ordersData) {
        try {
          final String orderId = orderData['id'] as String;
          final String? userId = orderData['user_id'] as String?;

          final List<Map<String, dynamic>> orderDetailsData = await _dbHelper
              .getOrderDetails(orderId);

          final List<OrderDetail> orderDetails = [];
          for (var detail in orderDetailsData) {
            try {
              final int productId = detail['product_id'] as int;
              final String productName =
                  (productNameMap[productId]?.split(' - ').first) ??
                  'Unknown Product';
              orderDetails.add(
                OrderDetail(
                  productId: productId,
                  productName: productName,
                  quantity: detail['quantity'] as int,
                  unit: detail['unit'] as String,
                  discount: detail['discount'] as int?,
                  price: detail['price'] as double,
                ),
              );
            } catch (e) {
              print('Error creating order detail: ${e.toString()}');
            }
          }

          DateTime createdAt;
          try {
            createdAt = DateTime.parse(orderData['created_at'] as String);
          } catch (e) {
            createdAt = DateTime.now();
            print('Failed to parse date for order $orderId: $e');
          }

          loadedOrders.add(
            Order(
              id: orderId,
              userId: userId,
              // customerName and customerPhoneNumber will be loaded on demand
              customerName: null,
              customerPhoneNumber: null,
              totalAmount: orderData['total_amount'] as double,
              deliveryOption: orderData['delivery_option'] as String,
              deliveryAddress: orderData['delivery_address'] as String?,
              deliveryTimeSlot: orderData['delivery_time_slot'] as String?,
              paymentMethod: orderData['payment_method'] as String,
              orderStatus: orderData['order_status'] as String,
              createdAt: createdAt,
              deliveryPartnerName:
                  orderData['delivery_partner_name'] as String?,
              deliveryPartnerPhone:
                  orderData['delivery_partner_phone'] as String?,
              items: orderDetails,
            ),
          );
        } catch (e) {
          print('Error processing order: ${e.toString()}');
        }
      }

      setState(() {
        _allOrders = loadedOrders;
        _filterOrders();
        _isSyncing = false;
      });
    } catch (e) {
      print('Error loading orders from database: ${e.toString()}');
      setState(() {
        _isSyncing = false;
        _allOrders = [];
        _filteredOrders = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load orders: ${e.toString()}')),
        );
      }
    }
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
          SelectableText(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Delivered':
        return Colors.green;
      case 'Order Shipped':
        return Colors.blue;
      case 'Out for Delivery':
        return Colors.indigo;
      case 'Order Placed':
        return Colors.orange;
      case 'Order Processing':
        return Colors.amber;
      case 'Order Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<Order> _fetchAndSetCustomerDetails(Order order) async {
    // Check if details are needed and not already being fetched for this order
    if (order.userId != null &&
        (order.customerName == null || order.customerPhoneNumber == null) &&
        !_fetchingOrderDetailsFor.contains(order.id)) {
      try {
        if (mounted) {
          // Add to fetching set and trigger a rebuild to show loading if dialog is open
          setState(() {
            _fetchingOrderDetailsFor.add(order.id);
          });
        }

        final profileData = await _dbHelper.getProfile(order.userId!);
        Order updatedOrder = order; // Start with the original order

        if (profileData != null) {
          updatedOrder = Order(
            // Create a new updated order instance
            id: order.id,
            userId: order.userId,
            customerName: profileData['full_name'] as String?,
            customerPhoneNumber: profileData['phone_number'] as String?,
            totalAmount: order.totalAmount,
            deliveryOption: order.deliveryOption,
            deliveryAddress: order.deliveryAddress,
            deliveryTimeSlot: order.deliveryTimeSlot,
            paymentMethod: order.paymentMethod,
            orderStatus: order.orderStatus,
            createdAt: order.createdAt,
            deliveryPartnerName: order.deliveryPartnerName,
            deliveryPartnerPhone: order.deliveryPartnerPhone,
            items: order.items,
          );

          if (mounted) {
            setState(() {
              int allOrdersIndex = _allOrders.indexWhere(
                (o) => o.id == order.id,
              );
              if (allOrdersIndex != -1) {
                _allOrders[allOrdersIndex] = updatedOrder;
              }
              int filteredOrdersIndex = _filteredOrders.indexWhere(
                (o) => o.id == order.id,
              );
              if (filteredOrdersIndex != -1) {
                _filteredOrders[filteredOrdersIndex] = updatedOrder;
              }
              if (_selectedOrder?.id == order.id) {
                _selectedOrder = updatedOrder;
              }
            });
          }
        }
        return updatedOrder; // Return the (potentially) updated order
      } catch (e) {
        print("Error fetching customer details for order ${order.id}: $e");
        return order; // Return original order on error
      } finally {
        if (mounted) {
          // Remove from fetching set and trigger a rebuild
          setState(() {
            _fetchingOrderDetailsFor.remove(order.id);
          });
        }
      }
    }
    // If details already exist, no user ID, or already fetching (though caught by outer if), return original order
    return order;
  }

  void _handleOrderSelection(Order order) async {
    setState(() {
      _selectedOrder = order; // Select immediately
    });
    // Fetch details and get the potentially updated order
    Order updatedOrder = await _fetchAndSetCustomerDetails(order);
    // If the selection hasn't changed and the order instance in state needs update
    if (mounted &&
        _selectedOrder?.id == updatedOrder.id &&
        _selectedOrder != updatedOrder) {
      setState(() {
        _selectedOrder = updatedOrder;
      });
    }
  }

  void _showOrderDetailsDialog(BuildContext context, Order order) {
    // Initial order instance for the dialog
    Order initialOrderForDialog = _allOrders.firstWhere(
      (o) => o.id == order.id,
      orElse: () => order,
    );
    if (_selectedOrder?.id == initialOrderForDialog.id) {
      initialOrderForDialog = _selectedOrder!;
    }

    // Trigger fetch if needed, but don't await here.
    // The dialog will use StatefulBuilder to react to state changes.
    if (initialOrderForDialog.userId != null &&
        (initialOrderForDialog.customerName == null ||
            initialOrderForDialog.customerPhoneNumber == null) &&
        !_fetchingOrderDetailsFor.contains(initialOrderForDialog.id)) {
      // Call it without await, it will manage its own setState calls
      _fetchAndSetCustomerDetails(initialOrderForDialog);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter dialogSetState) {
            // Always get the most current version of the order from the main state
            Order displayOrder = _allOrders.firstWhere(
              (o) =>
                  o.id ==
                  initialOrderForDialog
                      .id, // Use initialOrderForDialog.id for lookup
              orElse: () => initialOrderForDialog,
            );
            if (_selectedOrder?.id == displayOrder.id) {
              displayOrder = _selectedOrder!;
            }

            final bool isLoading = _fetchingOrderDetailsFor.contains(
              displayOrder.id,
            );

            return AlertDialog(
              title: SelectableText('Order Details: ${displayOrder.id}'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: const [
                            CircularProgressIndicator(strokeWidth: 2.0),
                            SizedBox(width: 12),
                            Text("Loading customer..."),
                          ],
                        ),
                      )
                    else ...[
                      if (displayOrder.customerName != null)
                        _buildDetailRow(
                          'Customer Name:',
                          displayOrder.customerName!,
                        ),
                      if (displayOrder.customerPhoneNumber != null)
                        _buildDetailRow(
                          'Customer Phone:',
                          displayOrder.customerPhoneNumber!,
                        ),
                      if (displayOrder.userId != null &&
                          displayOrder.customerName == null &&
                          displayOrder.customerPhoneNumber == null &&
                          !isLoading) // Check !isLoading here
                        _buildDetailRow(
                          'Customer Info:',
                          'Details not available or not found.',
                        ),
                    ],
                    _buildDetailRow('Status:', displayOrder.orderStatus),
                    _buildDetailRow(
                      'Total Amount:',
                      'LKR ${displayOrder.totalAmount.toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Payment Method:',
                      displayOrder.paymentMethod,
                    ),
                    _buildDetailRow(
                      'Delivery Option:',
                      displayOrder.deliveryOption,
                    ),
                    if (displayOrder.deliveryAddress != null)
                      _buildDetailRow(
                        'Delivery Address:',
                        displayOrder.deliveryAddress!,
                      ),
                    if (displayOrder.deliveryTimeSlot != null)
                      _buildDetailRow(
                        'Time Slot:',
                        displayOrder.deliveryTimeSlot!,
                      ),
                    if (displayOrder.deliveryPartnerName != null)
                      _buildDetailRow(
                        'Delivery Partner:',
                        displayOrder.deliveryPartnerName!,
                      ),
                    if (displayOrder.deliveryPartnerPhone != null)
                      _buildDetailRow(
                        'Partner Phone:',
                        displayOrder.deliveryPartnerPhone!,
                      ),
                    const SizedBox(height: 10),
                    const SelectableText(
                      'Items:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...displayOrder.items.map(
                      (item) => ListTile(
                        title: SelectableText(
                          '${item.productName} (ID: ${item.productId})',
                        ),
                        subtitle: SelectableText(
                          '${item.quantity} ${item.unit} @ LKR ${item.price.toStringAsFixed(2)} each',
                        ),
                        trailing: SelectableText(
                          'LKR ${item.itemTotal.toStringAsFixed(2)}',
                        ),
                      ),
                    ),
                    if (displayOrder.orderStatus == 'Order Placed' ||
                        displayOrder.orderStatus == 'Order Processing') ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text('Modify Order'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _modifyOrder(displayOrder);
                            },
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Cancel Order'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _cancelOrder(displayOrder);
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
      },
    ).then((_) {
      // Ensure UI reflects any state changes if needed after dialog closes
      // This might be redundant if _fetchAndSetCustomerDetails already called setState
      // but good for ensuring consistency if the dialog itself modified state.
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _syncWithDatabase() async {
    setState(() {
      _isSyncing = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Synchronizing with database...')),
    );

    try {
      // Use the sync service instead of direct implementation
      final result = await _syncService.syncSupabaseToSQLite();

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: SelectableText('Database synchronized successfully'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText(
              'Sync completed with ${result.errors.length} errors',
            ),
            action: SnackBarAction(
              label: 'Details',
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const SelectableText('Sync Results'),
                        content: SingleChildScrollView(
                          child: SelectableText(result.summary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                );
              },
            ),
          ),
        );
      }

      // Reload orders from local database
      await _loadOrdersFromDatabase();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: SelectableText('Sync failed: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
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
            onPressed: _loadOrdersFromDatabase,
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            color: Colors.grey[200],
            child:
                _isSyncing
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Syncing database...'),
                          ],
                        ),
                      ),
                    )
                    : ElevatedButton.icon(
                      onPressed: _syncWithDatabase,
                      icon: const Icon(Icons.sync),
                      label: const Text('Database Sync'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
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
                      onFilterChange: (String? newValue) {
                        setState(() {
                          _selectedStatusFilter = newValue;
                          _filterOrders();
                        });
                      },
                      onShowDetails: _showOrderDetailsDialog,
                      getStatusColor: _getStatusColor,
                    ),
          ),
        ],
      ),
    );
  }
}
