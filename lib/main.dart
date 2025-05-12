// filepath: /home/irfan/StudioProjects/Order/order_management/lib/main.dart
import 'package:flutter/material.dart';
import 'package:order_management/screens/login_screen.dart';
import 'package:order_management/order_management_screen.dart';
import 'package:order_management/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:order_management/services/supabase_realtime_service.dart';

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

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://lhytairgnojpzgbgjhod.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxoeXRhaXJnbm9qcHpnYmdqaG9kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1MDI4MjYsImV4cCI6MjA1NzA3ODgyNn0.uDxpy6lcB4STumSknuDmrjwZDuSekcY4i1A07nHCQdM',
  );

  // Initialize the database
  await DatabaseHelper.instance.database;

  // Initialize and subscribe to real-time updates
  final supabaseClient = Supabase.instance.client;
  final realtimeService = SupabaseRealtimeService(supabaseClient);
  realtimeService.subscribeToOrdersTable();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Order Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final supabase = Supabase.instance.client;

    // Check if we already have a session
    final session = supabase.auth.currentSession;

    setState(() {
      _isAuthenticated = session != null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isAuthenticated) {
      return const OrderManagementScreen();
    } else {
      return const LoginScreen();
    }
  }
}
