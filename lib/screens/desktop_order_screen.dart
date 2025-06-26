import 'package:flutter/material.dart';
import 'package:order_management/models/order_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:order_management/utils/file_export_utils.dart';
import 'package:order_management/services/order_status_history_service.dart';
import 'package:order_management/screens/desktop_order_screen_component/order_status.dart'; // Add this import
import 'package:process_run/shell.dart';
import 'dart:io';

class DesktopOrderScreen extends StatefulWidget {
  final List<Order> allOrders;
  final List<Order> filteredOrders;
  final Order? selectedOrder;
  final String? selectedStatusFilter;
  final List<String> orderStatuses;
  final TextEditingController searchController;
  final Function(Order) onOrderSelect;
  final Function() onDeselectOrder;
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
    required this.onDeselectOrder,
    required this.onModifyOrder,
    required this.onCancelOrder,
    required this.getStatusColor,
    required this.calculateSubtotal,
    required this.calculateDiscount,
    required this.buildDetailRow,
  });

  @override
  State<DesktopOrderScreen> createState() => _DesktopOrderScreenState();
}

class _DesktopOrderScreenState extends State<DesktopOrderScreen> {
  bool _isPanelOpenedByClick = false;
  // Add a variable to store the default save location
  String? _defaultSaveLocation = '/home/irfan/Desktop/daily-log/order_item';

  @override
  void didUpdateWidget(covariant DesktopOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOrder == null && oldWidget.selectedOrder != null) {
      if (_isPanelOpenedByClick) {
        setState(() {
          _isPanelOpenedByClick = false;
        });
      }
    }
  }

  void _handleOrderSelection(Order order) {
    widget.onOrderSelect(order);
    if (mounted) {
      setState(() {
        _isPanelOpenedByClick = true;
      });
    }
  }

  void _handleDeselectOrder() {
    widget.onDeselectOrder();
    if (mounted) {
      setState(() {
        _isPanelOpenedByClick = false;
      });
    }
  }

  // Add a method to set the default save location
  Future<void> _setDefaultSaveLocation() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Default Save Location',
      );

      if (selectedDirectory != null) {
        setState(() {
          _defaultSaveLocation = selectedDirectory;
        });
        print('DEBUG: Default save location set to: $_defaultSaveLocation');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Default save location set to: $_defaultSaveLocation',
            ),
          ),
        );
      }
    } catch (e) {
      print('ERROR setting default save location: $e');
    }
  }

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SelectableText(
                    'Filters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: widget.searchController,
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
                    value: widget.selectedStatusFilter,
                    items:
                        widget.orderStatuses.map((String value) {
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
                    widget.allOrders.length.toString(),
                  ),
                  _buildStatisticsCard(
                    'Delivered',
                    widget.allOrders
                        .where((o) => o.orderStatus == 'Delivered')
                        .length
                        .toString(),
                  ),
                  _buildStatisticsCard(
                    'Placed',
                    widget.allOrders
                        .where((o) => o.orderStatus == 'Order Placed')
                        .length
                        .toString(),
                  ),
                  _buildStatisticsCard(
                    'Processing',
                    widget.allOrders
                        .where((o) => o.orderStatus == 'Order Processing')
                        .length
                        .toString(),
                  ),
                  _buildStatisticsCard(
                    'Shipped',
                    widget.allOrders
                        .where((o) => o.orderStatus == 'Order Shipped')
                        .length
                        .toString(),
                  ),
                  _buildStatisticsCard(
                    'Out for Delivery',
                    widget.allOrders
                        .where((o) => o.orderStatus == 'Out for Delivery')
                        .length
                        .toString(),
                  ),
                  _buildStatisticsCard(
                    'Cancelled', // Added this
                    widget.allOrders
                        .where((o) => o.orderStatus == 'Order Cancelled')
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
                      'Orders (${widget.filteredOrders.length})',
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
                    widget.filteredOrders.isEmpty
                        ? const Center(
                          child: SelectableText('No orders found.'),
                        )
                        : _buildOrderDataTable(),
              ),
            ],
          ),
        ),

        // Right panel for order details
        if (widget.selectedOrder != null && _isPanelOpenedByClick)
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: Colors.grey[300]!)),
              ),
              child: _buildOrderDetailsPanel(widget.selectedOrder!),
            ),
          ),
      ],
    );
  }

  Widget _buildOrderDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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
              widget.filteredOrders.map((order) {
                final isSelected =
                    _isPanelOpenedByClick &&
                    widget.selectedOrder == order; // Modified condition
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
                          color: widget.getStatusColor(order.orderStatus),
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
                            onPressed: () => _handleOrderSelection(order),
                          ),
                          if (order.orderStatus == 'Order Placed' ||
                              order.orderStatus == 'Order Processing')
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              tooltip: 'Edit Order',
                              onPressed: () => widget.onModifyOrder(order),
                            ),
                        ],
                      ),
                    ),
                  ],
                  onSelectChanged: (isSelected) {
                    if (isSelected == true) {
                      _handleOrderSelection(order);
                    } else {
                      // If a row can be deselected by clicking it again (currently not the primary flow here)
                      // you might want to call _handleDeselectOrder() or ensure selectedOrder becomes null.
                      // However, current logic selects on true, and panel close button handles deselect.
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
                child: SelectableText(
                  'Order #${order.id}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _handleDeselectOrder,
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
                  color: widget.getStatusColor(order.orderStatus),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              SelectableText(
                order.orderStatus,
                style: TextStyle(
                  color: widget.getStatusColor(order.orderStatus),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Customer Information Section
          // Show loading or data
          _buildDetailSection('Customer Information', [
            if (order.userId != null &&
                order.customerName == null &&
                order.customerPhoneNumber == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(width: 8),
                    SelectableText("Loading..."),
                  ],
                ),
              )
            else ...[
              if (order.customerName != null)
                widget.buildDetailRow('Name', order.customerName!),
              if (order.customerPhoneNumber != null)
                widget.buildDetailRow('Phone', order.customerPhoneNumber!),
              if (order.customerName == null &&
                  order.customerPhoneNumber == null &&
                  order.userId != null)
                widget.buildDetailRow(
                  'Customer:',
                  'Details not found or no user ID.',
                ),
              if (order.userId == null)
                widget.buildDetailRow(
                  'Customer:',
                  'No user ID associated with order.',
                ),
            ],
          ]),
          const SizedBox(height: 24),

          // Order information section
          _buildDetailSection('Order Information', [
            widget.buildDetailRow(
              'Order Date',
              '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
            ),
            widget.buildDetailRow('Payment Method', order.paymentMethod),
            widget.buildDetailRow(
              'Total Amount',
              'LKR ${order.totalAmount.toStringAsFixed(2)}',
            ),
          ]),

          const SizedBox(height: 24),

          // Delivery information section
          _buildDetailSection('Delivery Information', [
            widget.buildDetailRow('Delivery Method', order.deliveryOption),
            if (order.deliveryAddress != null)
              widget.buildDetailRow('Delivery Address', order.deliveryAddress!),
            if (order.deliveryTimeSlot != null)
              widget.buildDetailRow('Delivery Time', order.deliveryTimeSlot!),
            if (order.deliveryPartnerName != null)
              widget.buildDetailRow(
                'Delivery Partner',
                order.deliveryPartnerName!,
              ),
            if (order.deliveryPartnerPhone != null)
              widget.buildDetailRow(
                'Partner Phone',
                order.deliveryPartnerPhone!,
              ),
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
                        flex: 2, // Reduced from 3
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
                        flex: 1, // Reduced from 2
                        child: SelectableText(
                          'Price',
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
                                flex: 2, // Reduced from 3
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
                                flex: 1, // Reduced from 2
                                child: SelectableText(
                                  '${item.price.toStringAsFixed(0)} Rs',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),

                  const Divider(height: 24),

                  // Summary rows
                  // Row(
                  //   children: [
                  //     const Spacer(flex: 5),
                  //     const Expanded(
                  //       flex: 2,
                  //       child: SelectableText('Subtotal:'),
                  //     ),
                  //     Expanded(
                  //       flex: 2,
                  //       child: SelectableText(
                  //         'LKR ${calculateSubtotal(order).toStringAsFixed(2)}',
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(flex: 5),
                      const Expanded(
                        flex: 2,
                        child: SelectableText('Delivery charge:'),
                      ),
                      Expanded(
                        flex: 2,
                        child: SelectableText(
                          '50 Rs',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(
                        flex: 5,
                      ), // Adjust spacer flex if needed based on new item flex sum (2+1+1+1=5)
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
                          'Rs ${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Add Save as Text File and Print buttons
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.description),
                        label: const Text('Save as Text File'),
                        onPressed: () => _saveAsTextFile(order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('Print'),
                        onPressed: () => _printOrder(order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Actions section - Redesigned to match the image
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Modify Order Button - Full width
              OutlinedButton(
                onPressed: () => widget.onModifyOrder(order),
                child: const Text('Modify Order'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              // Status controls in a row
              Row(
                children: [
                  Expanded(
                    child: OrderStatus(
                      order: order,
                      onOrderUpdate: widget.onModifyOrder,
                      onOrderSelect: widget.onOrderSelect,
                      getStatusColor: widget.getStatusColor,
                    ),
                  ),
                ],
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

  // Add this method to save order details as text file
  void _saveAsTextFile(Order order) async {
    await OrderFileExport.saveOrderAsTextFile(
      order: order,
      context: context,
      calculateSubtotal: widget.calculateSubtotal,
      defaultSaveLocation: _defaultSaveLocation,
      onSetDefaultLocationRequested: _setDefaultSaveLocation,
    );
  }

  // Add a placeholder for the print method
  void _printOrder(Order order) async {
    try {
      // First save the order as text file to get the file path
      String? filePath = await OrderFileExport.saveOrderAsTextFile(
        order: order,
        context: context,
        calculateSubtotal: widget.calculateSubtotal,
        defaultSaveLocation: _defaultSaveLocation,
        onSetDefaultLocationRequested: _setDefaultSaveLocation,
      );

      if (filePath != null) {
        // Create PowerShell script content
        String psScript = '''
# Define paths
\$sourceFile = "$filePath"
\$tempFile = "\$env:TEMP\\print_temp.txt"

# Read content from source file and trim whitespace
\$content = Get-Content \$sourceFile | ForEach-Object { \$_.Trim() }
\$content -join "`r`n" | Out-File -FilePath \$tempFile -Encoding utf8

# Set default printer
\$printerName = "EPSON TM-T81III Receipt"
(New-Object -ComObject WScript.Network).SetDefaultPrinter(\$printerName)

# Force close existing Notepad instances to apply new settings
Get-Process notepad -ErrorAction SilentlyContinue | Stop-Process -Force

# Configure Notepad settings via registry
\$registryPath = "HKCU:\\Software\\Microsoft\\Notepad"

# Set ZERO margins
Set-ItemProperty -Path \$registryPath -Name "fSavePageSettings" -Value 1 -Force
Set-ItemProperty -Path \$registryPath -Name "iMarginTop"    -Value 0 -Force
Set-ItemProperty -Path \$registryPath -Name "iMarginBottom" -Value 0 -Force
Set-ItemProperty -Path \$registryPath -Name "iMarginLeft"   -Value 0 -Force
Set-ItemProperty -Path \$registryPath -Name "iMarginRight"  -Value 0 -Force

# Set bold font with clearer visibility
Set-ItemProperty -Path \$registryPath -Name "lfFaceName"    -Value "Courier New" -Force
Set-ItemProperty -Path \$registryPath -Name "iPointSize"    -Value 80           -Force
Set-ItemProperty -Path \$registryPath -Name "lfWeight"      -Value 700           -Force

# Print using Notepad
Start-Process -FilePath notepad.exe -ArgumentList "/p \$tempFile" -Wait

# Cleanup
Remove-Item \$tempFile -Force

Write-Host "Printed with ZERO margins and BOLD text!"
''';

        // Save PowerShell script to temp file
        final tempDir = Directory.systemTemp;
        final scriptFile = File('${tempDir.path}\\print_order_${order.id}.ps1');
        await scriptFile.writeAsString(psScript);

        // Execute PowerShell script
        var shell = Shell();
        await shell.run(
          'powershell.exe -ExecutionPolicy Bypass -File "${scriptFile.path}"',
        );

        // Cleanup script file
        await scriptFile.delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order ${order.id} sent to printer')),
          );
        }
      }
    } catch (e) {
      print('ERROR printing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not print order: $e')));
      }
    }
  }
}
