import 'package:flutter/material.dart';
import 'package:order_management/models/order_model.dart';

class DesktopOrderScreen extends StatelessWidget {
  final List<Order> allOrders;
  final List<Order> filteredOrders;
  final Order? selectedOrder;
  final String? selectedStatusFilter;
  final List<String> orderStatuses;
  final TextEditingController searchController;
  final Function(Order) onOrderSelect;
  final Function() onDeselectOrder; // Add this parameter
  final Function(Order) onModifyOrder;
  final Function(Order) onCancelOrder;
  final Color Function(String) getStatusColor;
  final double Function(Order) calculateSubtotal;
  final double Function(Order) calculateDiscount;
  final Widget Function(String, String) buildDetailRow;

  const DesktopOrderScreen({
    super.key,
    required this.allOrders,
    required this.filteredOrders,
    required this.selectedOrder,
    required this.selectedStatusFilter,
    required this.orderStatuses,
    required this.searchController,
    required this.onOrderSelect,
    required this.onDeselectOrder, // Add this to the constructor
    required this.onModifyOrder,
    required this.onCancelOrder,
    required this.getStatusColor,
    required this.calculateSubtotal,
    required this.calculateDiscount,
    required this.buildDetailRow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left sidebar for filters
        Container(
          width: 250,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(right: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              // Add ScrollView to fix overflow
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SelectableText(
                    'Filters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search by Order ID',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SelectableText('Order Status'),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedStatusFilter,
                    items:
                        orderStatuses.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: SelectableText(value),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      // This will be handled by the parent widget
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Summary statistics
                  const SelectableText(
                    'Order Statistics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildStatisticsCard(
                    'Total Orders',
                    allOrders.length.toString(),
                  ),
                  _buildStatisticsCard(
                    'Delivered',
                    allOrders
                        .where((o) => o.orderStatus == 'Delivered')
                        .length
                        .toString(),
                  ),
                  _buildStatisticsCard(
                    'Placed',
                    allOrders
                        .where((o) => o.orderStatus == 'Order Placed')
                        .length
                        .toString(),
                  ),
                  _buildStatisticsCard(
                    'Processing',
                    allOrders
                        .where((o) => o.orderStatus == 'Order Processing')
                        .length
                        .toString(),
                  ),
                  _buildStatisticsCard(
                    'Shipped',
                    allOrders
                        .where((o) => o.orderStatus == 'Order Shipped')
                        .length
                        .toString(),
                  ),
                  _buildStatisticsCard(
                    'Out for Delivery',
                    allOrders
                        .where((o) => o.orderStatus == 'Out for Delivery')
                        .length
                        .toString(),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Center panel for order list
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[200],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SelectableText(
                      'Orders (${filteredOrders.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        // Sort option
                        DropdownButton<String>(
                          hint: const SelectableText('Sort by'),
                          items: const [
                            DropdownMenuItem(
                              value: 'date',
                              child: SelectableText('Date'),
                            ),
                            DropdownMenuItem(
                              value: 'amount',
                              child: SelectableText('Amount'),
                            ),
                            DropdownMenuItem(
                              value: 'status',
                              child: SelectableText('Status'),
                            ),
                          ],
                          onChanged: (String? value) {
                            // Implement sorting
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('New Order'),
                          onPressed: () {
                            // Create new order
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    filteredOrders.isEmpty
                        ? const Center(
                          child: SelectableText('No orders found.'),
                        )
                        : _buildOrderDataTable(),
              ),
            ],
          ),
        ),

        // Right panel for order details
        if (selectedOrder != null)
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: Colors.grey[300]!)),
              ),
              child: _buildOrderDetailsPanel(selectedOrder!),
            ),
          ),
      ],
    );
  }

  Widget _buildOrderDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, // Enable horizontal scrolling
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 16, // Reduce column spacing
          horizontalMargin: 12, // Reduce horizontal margins
          columns: const [
            DataColumn(label: Expanded(child: SelectableText('Order ID'))),
            DataColumn(label: Expanded(child: SelectableText('Date'))),
            DataColumn(label: Expanded(child: SelectableText('Status'))),
            DataColumn(label: Expanded(child: SelectableText('Amount'))),
            DataColumn(label: Expanded(child: SelectableText('Delivery'))),
            DataColumn(label: Expanded(child: SelectableText('Actions'))),
          ],
          rows:
              filteredOrders.map((order) {
                final isSelected = selectedOrder == order;
                return DataRow(
                  selected: isSelected,
                  color: MaterialStateProperty.resolveWith<Color?>((
                    Set<MaterialState> states,
                  ) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.green.withOpacity(0.08);
                    }
                    return null;
                  }),
                  cells: [
                    DataCell(
                      SelectableText(
                        order.id,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(
                      SelectableText(
                        '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: getStatusColor(order.orderStatus),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          order.orderStatus,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    DataCell(
                      SelectableText(
                        'LKR ${order.totalAmount.toStringAsFixed(2)}',
                      ),
                    ),
                    DataCell(SelectableText(order.deliveryOption)),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 18),
                            tooltip: 'View Details',
                            onPressed: () => onOrderSelect(order),
                          ),
                          if (order.orderStatus == 'Order Placed' ||
                              order.orderStatus == 'Order Processing')
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              tooltip: 'Edit Order',
                              onPressed: () => onModifyOrder(order),
                            ),
                        ],
                      ),
                    ),
                  ],
                  onSelectChanged: (isSelected) {
                    if (isSelected == true) {
                      onOrderSelect(order);
                    }
                  },
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrderDetailsPanel(Order order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                // Add Expanded to constrain the text width
                child: SelectableText(
                  'Order #${order.id}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  // overflow: TextOverflow.ellipsis, // Add overflow handling
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onDeselectOrder,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Order status with color indicator
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: getStatusColor(order.orderStatus),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              SelectableText(
                order.orderStatus,
                style: TextStyle(
                  color: getStatusColor(order.orderStatus),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Order information section
          _buildDetailSection('Order Information', [
            buildDetailRow(
              'Order Date',
              '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
            ),
            buildDetailRow('Payment Method', order.paymentMethod),
            buildDetailRow(
              'Total Amount',
              'LKR ${order.totalAmount.toStringAsFixed(2)}',
            ),
          ]),

          const SizedBox(height: 24),

          // Delivery information section
          _buildDetailSection('Delivery Information', [
            buildDetailRow('Delivery Method', order.deliveryOption),
            if (order.deliveryAddress != null)
              buildDetailRow('Delivery Address', order.deliveryAddress!),
            if (order.deliveryTimeSlot != null)
              buildDetailRow('Delivery Time', order.deliveryTimeSlot!),
            if (order.deliveryPartnerName != null)
              buildDetailRow('Delivery Partner', order.deliveryPartnerName!),
            if (order.deliveryPartnerPhone != null)
              buildDetailRow('Partner Phone', order.deliveryPartnerPhone!),
          ]),

          const SizedBox(height: 24),

          // Order items section
          _buildDetailSection('Order Items', [], hasItems: true),

          // Item rows in Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Header row
                  Row(
                    children: const [
                      Expanded(
                        flex: 3,
                        child: SelectableText(
                          'Product',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: SelectableText(
                          'Qty',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: SelectableText(
                          'Unit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: SelectableText(
                          'Price',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: SelectableText(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Item rows
                  ...order.items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: SelectableText(item.productName),
                              ),
                              Expanded(
                                flex: 1,
                                child: SelectableText('${item.quantity}'),
                              ),
                              Expanded(
                                flex: 1,
                                child: SelectableText(item.unit),
                              ),
                              Expanded(
                                flex: 2,
                                child: SelectableText(
                                  'LKR ${item.price.toStringAsFixed(2)}',
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: SelectableText(
                                  'LKR ${item.itemTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),

                  const Divider(height: 24),

                  // Summary rows
                  Row(
                    children: [
                      const Spacer(flex: 5),
                      const Expanded(
                        flex: 2,
                        child: SelectableText('Subtotal:'),
                      ),
                      Expanded(
                        flex: 2,
                        child: SelectableText(
                          'LKR ${calculateSubtotal(order).toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(flex: 5),
                      const Expanded(
                        flex: 2,
                        child: SelectableText('Discount:'),
                      ),
                      Expanded(
                        flex: 2,
                        child: SelectableText(
                          '-LKR ${calculateDiscount(order).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(flex: 5),
                      const Expanded(
                        flex: 2,
                        child: SelectableText(
                          'Total:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: SelectableText(
                          'LKR ${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Actions
          if (order.orderStatus == 'Order Placed' ||
              order.orderStatus == 'Order Processing')
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => onModifyOrder(order),
                  child: const Text('Modify Order'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => onCancelOrder(order),
                  child: const Text('Cancel Order'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(
    String title,
    List<Widget> children, {
    bool hasItems = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (!hasItems) ...children,
      ],
    );
  }

  Widget _buildStatisticsCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SelectableText(label),
            SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
