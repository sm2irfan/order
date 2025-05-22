import 'package:flutter/material.dart';
import 'package:order_management/models/order_model.dart';
import 'package:order_management/services/order_status_history_service.dart';

class OrderStatus extends StatefulWidget {
  final Order order;
  final Function(Order) onOrderUpdate;
  final Function(Order) onOrderSelect;
  final Color Function(String) getStatusColor;

  const OrderStatus({
    Key? key,
    required this.order,
    required this.onOrderUpdate,
    required this.onOrderSelect,
    required this.getStatusColor,
  }) : super(key: key);

  @override
  State<OrderStatus> createState() => _OrderStatusState();
}

class _OrderStatusState extends State<OrderStatus> {
  bool _isUpdatingStatus = false;
  final List<String> _statusOptions = [
    'Order Placed',
    'Order Processing',
    'Order Shipped',
    'Out for Delivery',
    'Delivered',
    'Order Cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Status dropdown
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonFormField<String>(
              value: widget.order.orderStatus,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                border: InputBorder.none,
                isDense: true,
              ),
              items:
                  _statusOptions.map((String status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
              onChanged: (String? newStatus) {
                if (newStatus != null &&
                    newStatus != widget.order.orderStatus) {
                  _updateOrderStatus(widget.order, newStatus);
                }
              },
              dropdownColor: Colors.white,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // History icon button
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View Status History',
            onPressed: () => _showStatusHistory(widget.order.id),
            color: Colors.blue[800],
            iconSize: 20,
          ),
        ),
      ],
    );
  }

  // Add method to show status history
  Future<void> _showStatusHistory(String orderId) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Fetch order status history
      final List<Map<String, dynamic>> history =
          await OrderStatusHistoryService.getOrderStatusHistory(orderId);

      // Dismiss loading dialog
      Navigator.of(context).pop();

      // Show history dialog
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Order #$orderId Status History'),
              content: SizedBox(
                width: double.maxFinite,
                child:
                    history.isEmpty
                        ? const Center(child: Text('No status history found.'))
                        : ListView.separated(
                          shrinkWrap: true,
                          itemCount: history.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = history[index];
                            final DateTime timestamp = DateTime.parse(
                              item['created_at'],
                            );

                            // Get updated_by_name if available
                            final String? updatedByName =
                                item['updated_by_name'];

                            return ListTile(
                              leading: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: widget.getStatusColor(
                                    item['order_status'],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: Text(item['order_status']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                                  ),
                                  if (updatedByName != null &&
                                      updatedByName.isNotEmpty)
                                    Text(
                                      'Updated by: $updatedByName',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                ],
                              ),
                              dense: true,
                              isThreeLine:
                                  updatedByName != null &&
                                  updatedByName.isNotEmpty,
                            );
                          },
                        ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    } catch (e) {
      // Dismiss loading dialog if error occurs
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading status history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateOrderStatus(Order order, String newStatus) async {
    // Special handling for order cancellation - require order ID confirmation
    if (newStatus == 'Order Cancelled') {
      await _showCancellationConfirmDialog(order, newStatus);
      return;
    }

    // Create updated order with new status
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

    // Set the flag to indicate we're updating status
    setState(() {
      _isUpdatingStatus = true;
    });

    // Update the order
    widget.onOrderUpdate(updatedOrder);

    // First delay to reselect the order
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        widget.onOrderSelect(updatedOrder);
      }
    });

    // Record status history
    try {
      await OrderStatusHistoryService.addStatusHistory(
        orderId: order.id,
        orderStatus: newStatus,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order status updated and history recorded'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Handle errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated but failed to record history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Use a longer delay before we clear the updating flag
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    });
  }

  // Add a confirmation dialog for order cancellation
  Future<void> _showCancellationConfirmDialog(
    Order order,
    String newStatus,
  ) async {
    final TextEditingController idController = TextEditingController();
    // Track dialog position
    final screenSize = MediaQuery.of(context).size;
    Offset dialogOffset = Offset(
      screenSize.width / 2 - 150, // Center horizontally (300/2 = 150)
      screenSize.height / 2 -
          150, // Center vertically (approximate dialog height/2)
    );

    // Create a stateful dialog with dragging capability
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Stack(
              children: [
                Positioned(
                  left: dialogOffset.dx,
                  top: dialogOffset.dy,
                  child: Material(
                    color: Colors.transparent,
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Draggable header
                          GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                dialogOffset += details.delta;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning, color: Colors.red),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Confirm Order Cancellation',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.drag_indicator,
                                    color: Colors.grey[600],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Dialog content
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Please enter the order ID to confirm cancellation:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: 300, // Fixed width for the dialog
                                  child: TextField(
                                    controller: idController,
                                    decoration: const InputDecoration(
                                      labelText: 'Order ID',
                                      border: OutlineInputBorder(),
                                    ),
                                    autofocus: true,
                                  ),
                                ),

                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      child: const Text('Cancel'),
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop(false);
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Confirm Cancellation'),
                                      onPressed: () {
                                        final enteredId =
                                            idController.text.trim();
                                        if (enteredId == order.id) {
                                          Navigator.of(dialogContext).pop(true);
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Order ID does not match. Cancellation aborted.',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          Navigator.of(
                                            dialogContext,
                                          ).pop(false);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // Proceed with status update if confirmed
    if (confirmed == true) {
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

      // Set the flag to indicate we're updating status
      setState(() {
        _isUpdatingStatus = true;
      });

      // Update the order
      widget.onOrderUpdate(updatedOrder);

      // First delay to reselect the order
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          widget.onOrderSelect(updatedOrder);
        }
      });

      // Record status history
      try {
        await OrderStatusHistoryService.addStatusHistory(
          orderId: order.id,
          orderStatus: newStatus,
        );

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order cancelled and history recorded'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // Handle errors
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status updated but failed to record history: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      // Use a longer delay before we clear the updating flag
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _isUpdatingStatus = false;
          });
        }
      });
    }
  }
}
