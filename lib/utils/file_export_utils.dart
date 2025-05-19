import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:order_management/models/order_model.dart';

/// Utility class to handle exporting orders as files
class OrderFileExport {
  /// Saves order details as a text file
  ///
  /// Returns the path where the file was saved, or null if the operation was canceled or failed
  static Future<String?> saveOrderAsTextFile({
    required Order order,
    required BuildContext context,
    required double Function(Order) calculateSubtotal,
    String? defaultSaveLocation,
    Function()? onSetDefaultLocationRequested,
  }) async {
    print('DEBUG: saveOrderAsTextFile called for order ID: ${order.id}');

    // Log platform information
    if (kIsWeb) {
      print('DEBUG: Running on Web platform');
    } else {
      print('DEBUG: Running on ${Platform.operatingSystem} platform');
    }

    try {
      print('DEBUG: Preparing text content...');

      // Prepare text content
      final StringBuffer buffer = StringBuffer();

      // Header
      buffer.writeln('====== ORDER RECEIPT ======');
      buffer.writeln('Order ID: ${order.id}');
      // buffer.writeln(
      //   'Date: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
      // );
      // buffer.writeln('Status: ${order.orderStatus}');
      buffer.writeln('');

      // // Customer information
      // buffer.writeln('CUSTOMER INFORMATION:');
      // if (order.customerName != null) {
      //   buffer.writeln('Name: ${order.customerName}');
      // }
      // if (order.customerPhoneNumber != null) {
      //   buffer.writeln('Phone: ${order.customerPhoneNumber}');
      // }
      // if (order.deliveryAddress != null) {
      //   buffer.writeln('Address: ${order.deliveryAddress}');
      // }
      // buffer.writeln('');

      // Order details
      buffer.writeln('ORDER DETAILS:');
      buffer.writeln('Payment Method: ${order.paymentMethod}');
      buffer.writeln('Delivery Option: ${order.deliveryOption}');
      if (order.deliveryTimeSlot != null) {
        buffer.writeln('Delivery Time: ${order.deliveryTimeSlot}');
      }
      buffer.writeln('');

      // Item table
      buffer.writeln('ITEMS:');
      buffer.writeln('-'.padRight(60, '-'));
      buffer.writeln(
        'Product'.padRight(30) +
            'Qty'.padRight(10) +
            'Unit'.padRight(10) +
            'Price'.padRight(10),
      );
      buffer.writeln('-'.padRight(60, '-'));

      for (var item in order.items) {
        buffer.writeln(
          item.productName.padRight(30) +
              item.quantity.toString().padRight(10) +
              item.unit.padRight(10) +
              '${item.price.toStringAsFixed(2)} Rs'.padRight(10),
        );
      }

      buffer.writeln('-'.padRight(60, '-'));
      buffer.writeln('');

      // Summary
      buffer.writeln('SUMMARY:');
      buffer.writeln(
        'Subtotal: LKR ${calculateSubtotal(order).toStringAsFixed(2)}',
      );
      buffer.writeln('Delivery Charge: 50 Rs');
      buffer.writeln('Total: LKR ${order.totalAmount.toStringAsFixed(2)}');
      buffer.writeln('');
      buffer.writeln('Thank you for your order!');

      print('DEBUG: Text content prepared, attempting to save...');

      // Try FilePicker first
      try {
        print('DEBUG: Trying FilePicker.platform.saveFile...');
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Order Details',
          fileName: 'order_${order.id}.txt',
          type: FileType.custom,
          allowedExtensions: ['txt'],
        );

        print('DEBUG: File picker returned: $outputFile');

        if (outputFile != null) {
          print('DEBUG: Creating file object at path: $outputFile');
          final file = File(outputFile);

          print('DEBUG: Writing text content to file...');
          await file.writeAsString(buffer.toString());

          print('DEBUG: File saved successfully to: $outputFile');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order details saved to: $outputFile')),
          );
          return outputFile; // Return the file path on successful save
        } else {
          print(
            'DEBUG: User cancelled the file picker dialog or FilePicker returned null',
          );
          // Continue to fallback approach
        }
      } catch (filePickerError) {
        print('DEBUG: FilePicker error: $filePickerError');
        // Continue to fallback approach
      }

      // Fallback approach: Save to a predetermined location
      print('DEBUG: Using fallback file saving approach...');
      if (!kIsWeb) {
        String savePath;
        final fileName =
            'order_${order.id}_${DateTime.now().millisecondsSinceEpoch}.txt';

        // Use the default save location if available, otherwise use app documents directory
        if (defaultSaveLocation != null) {
          savePath = defaultSaveLocation;
          print('DEBUG: Using configured default save location: $savePath');
        } else {
          // Get application documents directory
          final directory =
              await path_provider.getApplicationDocumentsDirectory();
          savePath = directory.path;
          print('DEBUG: Using application documents directory: $savePath');
        }

        final filePath = '$savePath/$fileName';

        print('DEBUG: Saving file to: $filePath');

        final file = File(filePath);
        await file.writeAsString(buffer.toString());

        print('DEBUG: File saved successfully to: $filePath');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order details saved to: $filePath'),
            action:
                defaultSaveLocation == null &&
                        onSetDefaultLocationRequested != null
                    ? SnackBarAction(
                      label: 'Set Default Location',
                      onPressed: onSetDefaultLocationRequested,
                    )
                    : null,
          ),
        );
        return filePath; // Return the file path on successful save
      } else {
        throw Exception(
          'Cannot save files directly on web platform without user interaction',
        );
      }
    } catch (e, stackTrace) {
      print('ERROR saving order as text file: $e');
      print('ERROR stack trace: $stackTrace');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save text file: $e')));
      return null; // Return null on failure
    }
  }
}
