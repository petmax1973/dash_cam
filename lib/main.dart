import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/foreground_task_handler.dart';
import 'services/storage_service.dart';

/// Top-level callback for the foreground service.
/// Must be a top-level or static function.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(DashCamTaskHandler());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize communication port for foreground task
  FlutterForegroundTask.initCommunicationPort();

  // Initialize shared preferences
  await SharedPreferences.getInstance();

  // Clean up orphaned chunks from previous sessions
  await StorageService.cleanupOrphanedChunks();

  runApp(const DashCamApp());
}
