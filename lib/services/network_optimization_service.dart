import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class NetworkOptimizationService {
  static Timer? _keepAliveTimer;
  static bool _isActive = false;

  /// Start network keep-alive to maintain warm connections
  static Future<void> startNetworkOptimization() async {
    if (_isActive) return;

    print('🌐 Starting network optimization...');

    // Perform initial connection warmup
    await _warmupConnection();

    // Schedule periodic keep-alive pings every 30 seconds
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _keepConnectionAlive();
    });

    _isActive = true;
    print('✅ Network optimization active - connection will stay warm');
  }

  /// Stop network optimization
  static void stopNetworkOptimization() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _isActive = false;
    print('🛑 Network optimization stopped');
  }

  /// Warm up the Supabase connection
  static Future<void> _warmupConnection() async {
    try {
      // Ping Supabase to establish and warm up the connection
      await Supabase.instance.client.from('orders').select('count').limit(1);

      print('🔥 Supabase connection warmed up');
    } catch (e) {
      print('❌ Connection warmup failed: $e');
    }
  }

  /// Keep connection alive with lightweight ping
  static Future<void> _keepConnectionAlive() async {
    try {
      // Lightweight query to keep connection active
      await Supabase.instance.client.from('orders').select('id').limit(1);

      print('💓 Connection keep-alive ping successful');
    } catch (e) {
      print('❌ Keep-alive ping failed: $e');
      // Try to re-establish connection
      await _warmupConnection();
    }
  }

  /// Force immediate connection optimization
  static Future<void> optimizeNow() async {
    print('🚀 Forcing immediate connection optimization...');
    await _warmupConnection();
  }

  /// Check if network optimization is active
  static bool get isActive => _isActive;
}
