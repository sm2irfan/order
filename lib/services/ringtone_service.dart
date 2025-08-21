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
  static bool _isAudioPreloaded = false;
  static Timer? _ringtoneTimer;
  static int _ringtoneCount = 0;

  /// Initialize the ringtone service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    print('🔔 Initializing RingtoneService with optimizations...');

    // Pre-configure and preload audio for faster playback
    await _preloadAudio();

    // Initialize notifications
    await _initializeNotifications();

    // Check if ringtone was previously enabled and restart if needed
    await _restoreRingtoneState();

    _isInitialized = true;
    print('✅ RingtoneService initialized with pre-loaded audio');
  }

  /// Pre-load audio for instant playback
  static Future<void> _preloadAudio() async {
    try {
      // Configure audio context once for all future playbacks
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true, // Keep device awake for audio
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationRingtone, // Specific for ringtones
            audioFocus: AndroidAudioFocus.gain, // Request full audio focus
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );

      // Pre-load the audio file to eliminate loading delay
      await _audioPlayer.setSource(AssetSource('sounds/notification.mp3'));
      await _audioPlayer.setVolume(1.0); // Maximum volume
      
      _isAudioPreloaded = true;
      print('🎵 Audio pre-loaded successfully - ready for instant playback');
    } catch (e) {
      print('❌ Error pre-loading audio: $e');
      _isAudioPreloaded = false;
    }
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

  /// Enable ringtone programmatically (for new order notifications)
  static Future<void> enableRingtone() async {
    final prefs = await SharedPreferences.getInstance();
    final currentState = await getRingtoneState();

    if (!currentState) {
      await prefs.setBool(_ringtoneToggleKey, true);
      await _startContinuousRingtone();
      print(
        '🔔 Ringtone automatically enabled for new order - will play every 20 seconds',
      );
    } else {
      print('🔔 Ringtone already enabled');
    }
    
    // Always play immediate ringtone for new orders (no delay)
    await playRingtoneImmediate();
  }

  /// Play ringtone immediately without waiting for timer
  static Future<void> playRingtoneImmediate() async {
    print('🚨 Playing IMMEDIATE ringtone for urgent notification');
    await playRingtone();
  }

  /// Start continuous ringtone (every 20 seconds for faster response)
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

    // Then schedule the next ones every 20 seconds (faster than 30)
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

  /// Schedule the next ringtone in 20 seconds (faster response)
  static Future<void> _scheduleNextRingtone() async {
    // Cancel any existing timer
    _ringtoneTimer?.cancel();

    // Create new timer for 20 seconds (reduced from 30)
    _ringtoneTimer = Timer(const Duration(seconds: 20), () async {
      // Check if ringtone is still enabled before playing
      final isStillEnabled = await getRingtoneState();
      if (isStillEnabled) {
        await playRingtone();
        // Schedule the next one (continuous loop)
        await _scheduleNextRingtone();
      }
    });

    print('⏰ Next ringtone scheduled for 20 seconds (count: $_ringtoneCount)');
  }

  /// Play the ringtone sound with optimized performance
  static Future<void> playRingtone() async {
    try {
      // Increment count for this play
      _ringtoneCount++;

      if (_isAudioPreloaded) {
        // Use pre-loaded audio for instant playback
        print('🎵 Using pre-loaded audio for instant playback (count: $_ringtoneCount)');
        
        // Reset to beginning and play immediately
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.resume();
      } else {
        // Fallback: Load and play (this will be slower)
        print('⚠️ Audio not pre-loaded, loading now (count: $_ringtoneCount)');
        
        // Stop any currently playing sound
        await _audioPlayer.stop();

        // Configure audio context
        await _audioPlayer.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: false,
              stayAwake: true,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.notificationRingtone,
              audioFocus: AndroidAudioFocus.gain,
            ),
            iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          ),
        );

        // Load and play the notification sound
        await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      }

      print('🎵 Ringtone played using ringtone volume (count: $_ringtoneCount)');

      // Show notification
      await _showNotification();
    } catch (e) {
      print('❌ Error playing ringtone: $e');
      // Try to reload audio on error
      if (_isAudioPreloaded) {
        print('🔄 Attempting to reload audio after error...');
        _isAudioPreloaded = false;
        await _preloadAudio();
      }
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
    final cycleTime = (elapsed % 20000); // 20 seconds in milliseconds
    final remainingMs = 20000 - cycleTime;

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
