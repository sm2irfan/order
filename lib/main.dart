// filepath: /home/irfan/StudioProjects/Order/order_management/lib/main.dart
import 'package:flutter/material.dart';
import 'package:order_management/order_management_screen.dart';
import 'package:order_management/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for SQLite on desktop platforms
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory
    databaseFactory = databaseFactoryFfi;
    print('Using FFI SQLite implementation');
  }

  // Initialize the database
  await DatabaseHelper.instance.database;

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
