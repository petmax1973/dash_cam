import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/recording_session.dart';

/// Service that manages camera initialization, recording, and cyclic chunk logic.
class RecordingService {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  CameraController? _controller;
  List<CameraDescription>? _cameras;
  RecordingSession? _currentSession;
  Timer? _chunkTimer;
  bool _isRecording = false;
  bool _isSwitchingChunk = false;

  // Callbacks for UI updates
  VoidCallback? onRecordingStateChanged;
  ValueChanged<String>? onChunkSaved;
  ValueChanged<String>? onError;

  /// The current camera controller (may be null if not initialized).
  CameraController? get controller => _controller;

  /// Whether the camera is initialized and ready.
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Whether we are currently recording.
  bool get isRecording => _isRecording;

  /// The current recording session.
  RecordingSession? get currentSession => _currentSession;

  /// Duration of each chunk in seconds.
  static const int chunkDurationSeconds = 60;

  /// Initialize the camera preferring ultra-wide (widest FOV).
  /// Uses medium resolution for better thermal performance.
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        onError?.call('Nessuna fotocamera trovata');
        return;
      }

      // Find all back cameras
      final backCameras = _cameras!
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .toList();

      if (backCameras.isEmpty) {
        onError?.call('Nessuna fotocamera posteriore trovata');
        return;
      }

      // Prefer the last back camera — on most phones,
      // the ultra-wide (widest FOV) is listed after the main camera.
      final selectedCamera = backCameras.last;

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium, // Lower res = wider FOV on some sensors
        enableAudio: true,
        fps: 30,
      );

      await _controller!.initialize();
      onRecordingStateChanged?.call();
    } catch (e) {
      onError?.call('Errore inizializzazione fotocamera: $e');
    }
  }

  /// Get the temp directory for storing chunks.
  Future<String> get _chunksDirectory async {
    final tempDir = await getTemporaryDirectory();
    final chunksDir = Directory('${tempDir.path}/dashcam_chunks');
    if (!await chunksDir.exists()) {
      await chunksDir.create(recursive: true);
    }
    return chunksDir.path;
  }

  /// Generate a filename for a new chunk.
  String _generateChunkFilename() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMdd_HHmmss');
    return 'dashcam_chunk_${formatter.format(now)}.mp4';
  }

  /// Start cyclic recording with the given max duration in minutes.
  Future<void> startRecording(int maxMinutes) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      onError?.call('Fotocamera non inizializzata');
      return;
    }

    if (_isRecording) return;

    try {
      _currentSession = RecordingSession(
        startTime: DateTime.now(),
        maxDurationMinutes: maxMinutes,
      );

      // Start the first chunk
      await _startNewChunk();
      _isRecording = true;

      // Set up timer to rotate chunks every chunkDurationSeconds
      _chunkTimer = Timer.periodic(
        const Duration(seconds: chunkDurationSeconds),
        (_) => _rotateChunk(),
      );

      onRecordingStateChanged?.call();
    } catch (e) {
      onError?.call('Errore avvio registrazione: $e');
    }
  }

  /// Start recording a new chunk file.
  Future<void> _startNewChunk() async {
    if (_controller == null) return;

    try {
      await _controller!.startVideoRecording();
    } catch (e) {
      onError?.call('Errore avvio chunk: $e');
    }
  }

  /// Rotate: stop current chunk, delete oldest if needed, start new chunk.
  Future<void> _rotateChunk() async {
    if (!_isRecording || _isSwitchingChunk) return;
    _isSwitchingChunk = true;

    try {
      // Stop current chunk and save it
      final file = await _controller!.stopVideoRecording();

      // Move file to our chunks directory with proper name
      final chunksDir = await _chunksDirectory;
      final newPath = '$chunksDir/${_generateChunkFilename()}';
      final savedFile = await File(file.path).copy(newPath);
      await File(file.path).delete();

      _currentSession?.addChunk(savedFile.path);
      onChunkSaved?.call(savedFile.path);

      // Delete oldest chunk if we exceeded max duration
      if (_currentSession != null &&
          _currentSession!.chunkCount > _currentSession!.maxDurationMinutes) {
        final oldPath = _currentSession!.removeOldestChunk();
        if (oldPath != null) {
          final oldFile = File(oldPath);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        }
      }

      // Start next chunk
      await _startNewChunk();
    } catch (e) {
      onError?.call('Errore rotazione chunk: $e');
    } finally {
      _isSwitchingChunk = false;
    }
  }

  /// Stop recording gracefully, saving the last chunk.
  Future<RecordingSession?> stopRecording() async {
    if (!_isRecording) return null;

    _chunkTimer?.cancel();
    _chunkTimer = null;
    _isRecording = false;

    try {
      // Save the last chunk (in progress)
      if (_controller != null && _controller!.value.isRecordingVideo) {
        final file = await _controller!.stopVideoRecording();

        final chunksDir = await _chunksDirectory;
        final newPath = '$chunksDir/${_generateChunkFilename()}';
        final savedFile = await File(file.path).copy(newPath);
        await File(file.path).delete();

        _currentSession?.addChunk(savedFile.path);

        // Delete oldest if exceeded max
        if (_currentSession != null &&
            _currentSession!.chunkCount > _currentSession!.maxDurationMinutes) {
          final oldPath = _currentSession!.removeOldestChunk();
          if (oldPath != null) {
            final oldFile = File(oldPath);
            if (await oldFile.exists()) {
              await oldFile.delete();
            }
          }
        }
      }
    } catch (e) {
      onError?.call('Errore stop registrazione: $e');
    }

    _currentSession?.stop();
    onRecordingStateChanged?.call();

    final session = _currentSession;
    return session;
  }

  /// Release camera resources.
  Future<void> dispose() async {
    _chunkTimer?.cancel();
    _chunkTimer = null;

    if (_controller != null) {
      if (_controller!.value.isRecordingVideo) {
        try {
          await _controller!.stopVideoRecording();
        } catch (_) {}
      }
      await _controller!.dispose();
      _controller = null;
    }
  }

  /// Reinitialize the camera (e.g., after coming back from background).
  Future<void> reinitialize() async {
    if (_controller != null && !_controller!.value.isInitialized) {
      await dispose();
      await initialize();
    }
  }
}
