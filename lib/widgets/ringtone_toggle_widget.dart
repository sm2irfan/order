import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ringtone_service.dart';

class RingtoneDialog extends StatefulWidget {
  const RingtoneDialog({super.key});

  @override
  State<RingtoneDialog> createState() => _RingtoneDialogState();
}

class _RingtoneDialogState extends State<RingtoneDialog> {
  bool _isEnabled = false;
  bool _isLoading = false;
  int? _remainingSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadRingtoneState();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRingtoneState() async {
    try {
      final state = await RingtoneService.getRingtoneState();
      if (mounted) {
        setState(() {
          _isEnabled = state;
        });

        if (state) {
          _startCountdown();
        }
      }
    } catch (e) {
      print('❌ Error loading ringtone state: $e');
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = await RingtoneService.getRemainingSeconds();
      if (mounted) {
        setState(() {
          _remainingSeconds = remaining;
        });

        if (remaining == null || remaining <= 0) {
          setState(() {
            _isEnabled = false;
            _remainingSeconds = null;
          });
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _toggleRingtone() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newState = await RingtoneService.toggleRingtone();
      if (mounted) {
        setState(() {
          _isEnabled = newState;
          _isLoading = false;
          _remainingSeconds = newState ? 30 : null;
        });

        if (newState) {
          _startCountdown();
        } else {
          _countdownTimer?.cancel();
        }

        // Show feedback to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newState
                  ? '🔔 Ringtone playing - will repeat every 30 seconds'
                  : '🔕 Ringtone cancelled',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: newState ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
      print('❌ Error toggling ringtone: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.notifications_active, color: Colors.blue, size: 24),
          const SizedBox(width: 8),
          const Text(
            'Ringtone Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Toggle the ringtone to play every 30 seconds:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color:
                      _isEnabled ? Colors.green.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isEnabled ? Colors.green : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: _isEnabled ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEnabled
                                ? 'Ringtone Enabled'
                                : 'Ringtone Disabled',
                            style: TextStyle(
                              color:
                                  _isEnabled
                                      ? Colors.green.shade800
                                      : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_isEnabled && _remainingSeconds != null)
                            Text(
                              'Next ringtone in: ${_remainingSeconds}s',
                              style: TextStyle(
                                color: Colors.green.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else if (_isEnabled)
                            Text(
                              'Ringtone will play every 30 seconds',
                              style: TextStyle(
                                color: Colors.green.shade600,
                                fontSize: 14,
                              ),
                            )
                          else
                            Text(
                              'No ringtone scheduled',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _isLoading ? null : _toggleRingtone,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 60,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color:
                              _isEnabled ? Colors.green : Colors.grey.shade400,
                        ),
                        child: Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 200),
                              left: _isEnabled ? 32 : 4,
                              top: 4,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child:
                                    _isLoading
                                        ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.grey,
                                          ),
                                        )
                                        : Icon(
                                          _isEnabled
                                              ? Icons.check
                                              : Icons.close,
                                          size: 16,
                                          color:
                                              _isEnabled
                                                  ? Colors.green
                                                  : Colors.grey,
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isEnabled)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ringtone will continue even when the app is in the background.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Close',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
