import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RingtoneService {
  static const String _ringtoneToggleKey = 'ringtone_toggle';
  static const String _ringtoneStartTimeKey = 'ringtone_start_time';

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static bool _isInitialized = false;
  static Timer? _ringtoneTimer;
  static int _ringtoneCount = 0;

  /// Initialize the ringtone service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize notifications
    await _initializeNotifications();

    // Check if ringtone was previously enabled and restart if needed
    await _restoreRingtoneState();

    _isInitialized = true;
    print('🔔 RingtoneService initialized');
  }

  /// Initialize local notifications
  static Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification tapped: ${response.payload}');
      },
    );

    // Request notification permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Restore ringtone state on app restart
  static Future<void> _restoreRingtoneState() async {
    final isEnabled = await getRingtoneState();
    if (isEnabled) {
      print('🔄 Restoring ringtone state - resuming continuous ringtone');
      await _startContinuousRingtone();
    }
  }

  /// Toggle the ringtone on/off
  static Future<bool> toggleRingtone() async {
    final prefs = await SharedPreferences.getInstance();
    final currentState = await getRingtoneState();
    final newState = !currentState;

    await prefs.setBool(_ringtoneToggleKey, newState);

    if (newState) {
      // Turn on - start continuous ringtone
      await _startContinuousRingtone();
      print('🔔 Ringtone enabled - will play every 30 seconds');
    } else {
      // Turn off - stop continuous ringtone
      await _stopContinuousRingtone();
      print('🔕 Ringtone disabled');
    }

    return newState;
  }

  /// Get current ringtone state
  static Future<bool> getRingtoneState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ringtoneToggleKey) ?? false;
  }

  /// Start continuous ringtone (every 30 seconds)
  static Future<void> _startContinuousRingtone() async {
    // Cancel any existing timer
    _ringtoneTimer?.cancel();

    // Save start time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _ringtoneStartTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    _ringtoneCount = 0;

    // Play the first ringtone immediately
    await playRingtone();

    // Then schedule the next ones every 30 seconds
    await _scheduleNextRingtone();
  }

  /// Stop continuous ringtone
  static Future<void> _stopContinuousRingtone() async {
    // Cancel timer
    _ringtoneTimer?.cancel();
    _ringtoneTimer = null;

    // Stop any currently playing audio immediately
    try {
      await _audioPlayer.stop();
      print('🛑 Stopped currently playing ringtone');
    } catch (e) {
      print('⚠️ Error stopping audio: $e');
    }

    // Clear notifications
    await _notificationsPlugin.cancelAll();

    // Update preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ringtoneToggleKey, false);
    await prefs.remove(_ringtoneStartTimeKey);

    _ringtoneCount = 0;
  }

  /// Schedule the next ringtone in 30 seconds
  static Future<void> _scheduleNextRingtone() async {
    // Cancel any existing timer
    _ringtoneTimer?.cancel();

    // Create new timer for 30 seconds
    _ringtoneTimer = Timer(const Duration(seconds: 30), () async {
      // Check if ringtone is still enabled before playing
      final isStillEnabled = await getRingtoneState();
      if (isStillEnabled) {
        await playRingtone();
        // Schedule the next one (continuous loop)
        await _scheduleNextRingtone();
      }
    });

    print('⏰ Next ringtone scheduled for 30 seconds (count: $_ringtoneCount)');
  }

  /// Play the ringtone sound
  static Future<void> playRingtone() async {
    try {
      // Increment count for this play
      _ringtoneCount++;
      
      // Stop any currently playing sound
      await _audioPlayer.stop();

      // Play the notification sound
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      print('🎵 Playing ringtone (count: $_ringtoneCount)');

      // Show notification
      await _showNotification();
    } catch (e) {
      print('❌ Error playing ringtone: $e');
    }
  }

  /// Show notification when ringtone plays
  static Future<void> _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'ringtone_channel',
          'Ringtone Notifications',
          channelDescription: 'Notifications for ringtone alerts',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          ongoing: true, // Make it persistent
          autoCancel: false, // Don't auto dismiss
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      1, // Fixed ID to replace previous notification
      'Order Management Alert',
      'Ringtone #$_ringtoneCount - ${DateTime.now().toString().substring(11, 19)}',
      platformChannelSpecifics,
    );
  }

  /// Get remaining time until next ringtone plays (for UI display)
  static Future<int?> getRemainingSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final isToggled = prefs.getBool(_ringtoneToggleKey) ?? false;
    final startTime = prefs.getInt(_ringtoneStartTimeKey);

    if (!isToggled || startTime == null) {
      return null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - startTime;
    final cycleTime = (elapsed % 30000); // 30 seconds in milliseconds
    final remainingMs = 30000 - cycleTime;

    return (remainingMs / 1000).round();
  }

  /// Get the total number of ringtones played
  static int getRingtoneCount() {
    return _ringtoneCount;
  }

  /// Check if ringtone service is currently active
  static bool get isActive {
    return _ringtoneTimer != null && _ringtoneTimer!.isActive;
  }
}
