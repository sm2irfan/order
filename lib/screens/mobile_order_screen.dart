import 'package:flutter/material.dart';
import 'package:order_management/models/order_model.dart';

class MobileOrderScreen extends StatelessWidget {
  final List<Order> filteredOrders;
  final String? selectedStatusFilter;
  final List<String> orderStatuses;
  final TextEditingController searchController;
  final Function(String?) onFilterChange;
  final Function(BuildContext, Order) onShowDetails;
  final Color Function(String) getStatusColor;
  final Function(Order) onOrderUpdate;
  final Function(Order) onOrderSelect;
  final Function(Order, String)? onStatusChange;

  const MobileOrderScreen({
    super.key,
    required this.filteredOrders,
    required this.selectedStatusFilter,
    required this.orderStatuses,
    required this.searchController,
    required this.onFilterChange,
    required this.onShowDetails,
    required this.getStatusColor,
    required this.onOrderUpdate,
    required this.onOrderSelect,
    this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          // Search and Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 250,
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(
                      fontSize: 16,
                    ), // Added larger font size
                    decoration: InputDecoration(
                      labelText: 'Search by Order ID',
                      labelStyle: const TextStyle(
                        fontSize: 16,
                      ), // Added larger label font
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedStatusFilter,
                  icon: const Icon(Icons.filter_list),
                  elevation: 16,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 16, // Increased from default
                    fontWeight: FontWeight.w500,
                  ),
                  underline: Container(
                    height: 2,
                    color: Theme.of(context).primaryColorDark,
                  ),
                  onChanged: onFilterChange,
                  items:
                      orderStatuses.map<DropdownMenuItem<String>>((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: SelectableText(
                            value,
                            style: const TextStyle(
                              fontSize: 16, // Added larger font size
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Order List
          Expanded(
            child:
                filteredOrders.isEmpty
                    ? const Center(
                      child: SelectableText(
                        'No orders found.',
                        style: TextStyle(
                          fontSize: 18, // Added larger font size
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: getStatusColor(
                                    order.orderStatus,
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long,
                                    color: Colors.white,
                                  ),
                                ),
                                title: SelectableText(
                                  'Order ID: ${order.id}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18, // Increased from default
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    // Status indicator now shows current status with change button
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: getStatusColor(
                                                order.orderStatus,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: SelectableText(
                                              order.orderStatus,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize:
                                                    14, // Increased from 12
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap:
                                                () => _showStatusChangeDialog(
                                                  context,
                                                  order,
                                                ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.edit,
                                                    color: Colors.white,
                                                    size: 12,
                                                  ),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    'Change',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize:
                                                          14, // Increased from 12
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      'Total: LKR ${order.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16, // Increased from default
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (order.customerName != null)
                                      SelectableText(
                                        'Customer: ${order.customerName}',
                                        style: TextStyle(
                                          fontSize: 14, // Increased from 12
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    SelectableText(
                                      'Date: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                                      style: TextStyle(
                                        fontSize: 14, // Increased from 12
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                isThreeLine: true,
                                onTap: () => onShowDetails(context, order),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  // Method to show status change dialog
  void _showStatusChangeDialog(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text(
              'Change Order Status',
              style: TextStyle(
                fontSize: 20, // Increased font size
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ID: ${order.id}',
                  style: const TextStyle(
                    fontSize: 16, // Increased font size
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Status: ${order.orderStatus}',
                  style: const TextStyle(
                    fontSize: 16, // Increased font size
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select New Status:',
                  style: TextStyle(
                    fontSize: 16, // Increased font size
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...orderStatuses
                    .where(
                      (status) =>
                          status != 'All' && status != order.orderStatus,
                    )
                    .map(
                      (status) => ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: getStatusColor(status),
                          radius: 12,
                          child: const Icon(
                            Icons.circle,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          status,
                          style: const TextStyle(
                            fontSize: 16, // Increased font size
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _handleStatusChange(context, order, status);
                        },
                      ),
                    ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16, // Increased font size
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // Method to handle status change with password check for cancellation
  void _handleStatusChange(
    BuildContext context,
    Order order,
    String newStatus,
  ) {
    // If changing to "Order Cancelled", require password
    if (newStatus == "Order Cancelled") {
      _showPasswordDialog(context, order, newStatus);
    } else {
      // For other status changes, proceed directly
      if (onStatusChange != null) {
        onStatusChange!(order, newStatus);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status change functionality not implemented yet'),
          ),
        );
      }
    }
  }

  // Method to show password dialog for order cancellation
  void _showPasswordDialog(
    BuildContext context,
    Order order,
    String newStatus,
  ) {
    showDialog(
      context: context,
      builder:
          (BuildContext context) => _PasswordDialog(
            order: order,
            newStatus: newStatus,
            onStatusChange: onStatusChange,
          ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  final Order order;
  final String newStatus;
  final Function(Order, String)? onStatusChange;

  const _PasswordDialog({
    required this.order,
    required this.newStatus,
    this.onStatusChange,
  });

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Password Required',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter your password to cancel Order ${widget.order.id}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(fontSize: 16),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final password = _passwordController.text.trim();
            Navigator.of(context).pop();

            if (password.isNotEmpty) {
              // Here you can add password validation logic
              // For now, we'll proceed with any non-empty password
              if (widget.onStatusChange != null) {
                widget.onStatusChange!(widget.order, widget.newStatus);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Status change functionality not implemented yet',
                    ),
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Password is required to cancel an order',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text(
            'Cancel Order',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
