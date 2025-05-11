// filepath: /home/irfan/StudioProjects/Order/order_management/lib/main.dart
import 'package:flutter/material.dart';
import 'package:order_management/order_management_screen.dart'; // Assuming this path

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Order Management',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.green[600],
        ),
      ),
      home: const OrderManagementScreen(),
    );
  }
}
