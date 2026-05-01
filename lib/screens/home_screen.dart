import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show startCallback;
import '../services/recording_service.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/recording_controls.dart';
import '../widgets/time_selector.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Home screen: camera preview, time selector, and record button.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final RecordingService _recordingService = RecordingService();
  int _recordingMinutes = 5;
  bool _isRecording = false;
  int _elapsedSeconds = 0;
  bool _permissionsGranted = false;
  bool _isInitializing = true;

  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  Timer? _accidentTimer;
  ValueNotifier<int>? _countdownNotifier;
  bool _isAccidentDialogShowing = false;

  static const String _prefKeyMinutes = 'recording_minutes';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _recordingService.onRecordingStateChanged = () {
      if (mounted) setState(() {});
    };
    _recordingService.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    };

    // Listen for data from the foreground task (elapsed time, stop requests)
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadSettings();
      await _requestPermissions();
      await _initializeCamera();
      _initForegroundService();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _accelSubscription?.cancel();
    _accidentTimer?.cancel();
    _countdownNotifier?.dispose();
    // Always dispose camera to avoid FlutterJNI crash
    _recordingService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _recordingService.controller;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_isRecording) {
        // Ripristina la luminosità per far vedere bene il navigatore in PiP
        try {
          ScreenBrightness().resetApplicationScreenBrightness();
        } catch (_) {}
      } else {
        // Dispose camera when app goes to background to prevent crash
        if (controller != null && controller.value.isInitialized) {
          _recordingService.dispose();
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isRecording) {
        // Riapplica la luminosità bassa quando l'app torna a schermo intero
        try {
          ScreenBrightness().setApplicationScreenBrightness(0.05);
        } catch (_) {}
      } else {
        // Reinitialize camera when app comes back
        _recordingService.initialize().then((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void _onReceiveTaskData(Object data) {
    if (data is Map<String, dynamic>) {
      final type = data['type'];

      if (type == 'tick') {
        setState(() {
          _elapsedSeconds = data['elapsedSeconds'] as int? ?? _elapsedSeconds;
        });
      } else if (type == 'stopRequested') {
        // User pressed STOP in the notification
        _stopRecording();
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recordingMinutes = prefs.getInt(_prefKeyMinutes) ?? 5;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyMinutes, _recordingMinutes);
  }

  Future<void> _requestPermissions() async {
    // Request camera and microphone permissions
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    // Check notification permission (Android 13+)
    if (Platform.isAndroid) {
      final notifPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notifPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // Request battery optimization exclusion
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }

    setState(() {
      _permissionsGranted =
          cameraStatus.isGranted && micStatus.isGranted;
    });
  }

  Future<void> _initializeCamera() async {
    if (!_permissionsGranted) {
      setState(() => _isInitializing = false);
      return;
    }

    await _recordingService.initialize();
    setState(() => _isInitializing = false);
  }

  void _initForegroundService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'dashcam_recording',
        channelName: 'DashCam Registrazione',
        channelDescription: 'Notifica durante la registrazione DashCam',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  void _startAccelerometer() {
    _accelSubscription?.cancel();
    _accelSubscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      if (!_isRecording || _isAccidentDialogShowing) return;

      final double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Soglia di decelerazione: 35 m/s^2 (circa 3.5 G)
      if (magnitude > 35.0) {
        _handleSuspectedAccident();
      }
    });
  }

  void _handleSuspectedAccident() {
    _isAccidentDialogShowing = true;
    _countdownNotifier = ValueNotifier<int>(15);

    _accidentTimer?.cancel();
    _accidentTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownNotifier!.value > 0) {
        _countdownNotifier!.value--;
      } else {
        timer.cancel();
        if (_isAccidentDialogShowing) {
          _isAccidentDialogShowing = false;
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          _stopRecording();
        }
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C0B0B),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sospetto Incidente',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'È stata rilevata una forte decelerazione.\nLa registrazione verrà interrotta per sicurezza.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ValueListenableBuilder<int>(
                valueListenable: _countdownNotifier!,
                builder: (context, value, child) {
                  return Text(
                    'Arresto tra: $value s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _accidentTimer?.cancel();
                _isAccidentDialogShowing = false;
                Navigator.pop(context);
              },
              child: const Text('Continua', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                _accidentTimer?.cancel();
                _isAccidentDialogShowing = false;
                Navigator.pop(context);
                _stopRecording();
              },
              child: const Text('Fermati Ora', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    setState(() {
      _isRecording = true;
      _elapsedSeconds = 0;
    });

    // Enable Auto PiP mode so leaving the app enters PiP automatically
    if (Platform.isAndroid) {
      SimplePip().setAutoPipMode(autoEnter: true);
    }

    // Start the camera recording
    await _recordingService.startRecording(_recordingMinutes);

    // Start the foreground service
    await FlutterForegroundTask.startService(
      serviceId: 100,
      notificationTitle: '🔴 DashCam - Registrazione in corso',
      notificationText: 'Durata: 00:00',
      notificationButtons: [
        const NotificationButton(id: 'btn_stop', text: 'STOP'),
      ],
      callback: startCallback,
    );
    
    _startAccelerometer();
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    if (Platform.isAndroid) {
      SimplePip().setAutoPipMode(autoEnter: false);
    }

    // Stop the foreground service
    await FlutterForegroundTask.stopService();

    // Stop accelerometer
    _accelSubscription?.cancel();
    _accidentTimer?.cancel();
    _isAccidentDialogShowing = false;

    // Stop recording and get the session
    final session = await _recordingService.stopRecording();

    setState(() {
      _isRecording = false;
      _elapsedSeconds = 0;
    });

    if (session != null && session.chunkPaths.isNotEmpty && mounted) {
      // Navigate to review screen
      Navigator.pushNamed(
        context,
        '/review',
        arguments: session,
      );
    }
  }

  String get _formattedElapsed {
    final minutes =
        (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds =
        (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionsGranted && !_isInitializing) {
      return _buildPermissionDeniedScreen();
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera preview (fullscreen background)
          Positioned.fill(
            child: CameraPreviewWidget(
              controller: _recordingService.controller,
              opacity: _isRecording ? 1.0 : 0.4,
            ),
          ),

          // UI elements (hidden when in PiP)
          Positioned.fill(
            child: PipWidget(
              pipBuilder: (context) => const SizedBox.shrink(),
              builder: (context) => Stack(
                children: [
                  // Dark gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // UI controls
                  Positioned.fill(
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _isRecording
                            ? _buildRecordingUI()
                            : _buildSetupUI(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupUI() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Column(
      children: [
        // App title bar
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE53935).withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, color: Color(0xFFE53935), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'DASHCAM',
                      style: TextStyle(
                        color: Color(0xFFE53935),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Main content: adapts to orientation
        Expanded(
          child: isLandscape
              ? _buildLandscapeContent()
              : _buildPortraitContent(),
        ),
      ],
    );
  }

  Widget _buildLandscapeContent() {
    return Row(
      children: [
        // Time selector on the left
        Expanded(
          child: Center(
            child: TimeSelector(
              minutes: _recordingMinutes,
              onChanged: (value) {
                setState(() => _recordingMinutes = value);
                _saveSettings();
              },
              enabled: !_isRecording,
            ),
          ),
        ),
        // Record button on the right
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: RecordingControls(
            isRecording: false,
            elapsedTime: '00:00',
            onStartStop: _startRecording,
            enabled: _recordingService.isInitialized,
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        // Time selector
        TimeSelector(
          minutes: _recordingMinutes,
          onChanged: (value) {
            setState(() => _recordingMinutes = value);
            _saveSettings();
          },
          enabled: !_isRecording,
        ),
        const SizedBox(height: 40),
        // Record button
        RecordingControls(
          isRecording: false,
          elapsedTime: '00:00',
          onStartStop: _startRecording,
          enabled: _recordingService.isInitialized,
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildRecordingUI() {
    return Center(
      child: RecordingControls(
        isRecording: true,
        elapsedTime: _formattedElapsed,
        onStartStop: _stopRecording,
      ),
    );
  }

  Widget _buildPermissionDeniedScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off,
                size: 80,
                color: Color(0xFFE53935),
              ),
              const SizedBox(height: 24),
              const Text(
                'Permessi Necessari',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'DashCam ha bisogno dei permessi di Fotocamera e Microfono per funzionare.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  await openAppSettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apri Impostazioni',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
