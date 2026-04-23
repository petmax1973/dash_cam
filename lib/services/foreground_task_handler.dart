import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// TaskHandler for the foreground service.
///
/// Runs in a separate isolate. Updates the notification with elapsed time
/// and handles stop commands from the notification button.
class DashCamTaskHandler extends TaskHandler {
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _elapsedSeconds = 0;

    // Use a local timer to count seconds accurately
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;

      final minutes =
          (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
      final seconds =
          (_elapsedSeconds % 60).toString().padLeft(2, '0');

      FlutterForegroundTask.updateService(
        notificationTitle: '🔴 DashCam - Registrazione in corso',
        notificationText: 'Durata: $minutes:$seconds',
      );

      // Send elapsed time to main isolate
      FlutterForegroundTask.sendDataToMain({
        'type': 'tick',
        'elapsedSeconds': _elapsedSeconds,
      });
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // We use our own timer instead of the repeat event
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map && data['type'] == 'stop') {
      // Signal from main isolate to stop
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_stop') {
      // User pressed STOP in notification
      FlutterForegroundTask.sendDataToMain({
        'type': 'stopRequested',
      });
    }
  }

  @override
  void onNotificationPressed() {
    // User tapped on the notification — bring app to foreground
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {
    // Notification cannot be dismissed while service is running
  }
}
