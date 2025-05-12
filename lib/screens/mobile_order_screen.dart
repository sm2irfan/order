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

  const MobileOrderScreen({
    super.key,
    required this.filteredOrders,
    required this.selectedStatusFilter,
    required this.orderStatuses,
    required this.searchController,
    required this.onFilterChange,
    required this.onShowDetails,
    required this.getStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          // Search and Filter Bar
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by Order ID',
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
                style: TextStyle(color: Theme.of(context).primaryColor),
                underline: Container(
                  height: 2,
                  color: Theme.of(context).primaryColorDark,
                ),
                onChanged: onFilterChange,
                items:
                    orderStatuses.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: SelectableText(value),
                      );
                    }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Order List
          Expanded(
            child:
                filteredOrders.isEmpty
                    ? const Center(child: SelectableText('No orders found.'))
                    : ListView.builder(
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: getStatusColor(
                                order.orderStatus,
                              ),
                              child: Icon(
                                Icons.receipt_long,
                                color: Colors.white,
                              ),
                            ),
                            title: SelectableText(
                              'Order ID: ${order.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
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
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: SelectableText(
                                        order.orderStatus,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  'Total: LKR ${order.totalAmount.toStringAsFixed(2)}',
                                ),
                                SelectableText(
                                  'Date: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            isThreeLine: true,
                            onTap: () => onShowDetails(context, order),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
