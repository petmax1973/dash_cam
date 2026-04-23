import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/recording_session.dart';
import '../services/storage_service.dart';

/// Review screen: shown after stopping the recording.
/// Displays video player, duration, and save/discard options.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  RecordingSession? _session;
  VideoPlayerController? _videoController;
  int _currentChunkIndex = 0;
  bool _isSaving = false;
  bool _saved = false;
  double _saveProgress = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is RecordingSession) {
        _session = args;
        _initVideoPlayer();
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideoPlayer() async {
    if (_session == null || _session!.chunkPaths.isEmpty) return;

    await _loadChunk(_currentChunkIndex);
  }

  Future<void> _loadChunk(int index) async {
    if (_session == null || index >= _session!.chunkPaths.length) return;

    // Dispose previous controller
    await _videoController?.dispose();

    final path = _session!.chunkPaths[index];
    _videoController = VideoPlayerController.file(File(path));

    await _videoController!.initialize();
    _videoController!.addListener(_onVideoProgress);
    await _videoController!.play();

    setState(() {
      _currentChunkIndex = index;
    });
  }

  void _onVideoProgress() {
    if (_videoController == null) return;

    // Auto-advance to next chunk when current one finishes
    if (_videoController!.value.position >= _videoController!.value.duration &&
        _videoController!.value.duration > Duration.zero) {
      if (_currentChunkIndex < _session!.chunkPaths.length - 1) {
        _loadChunk(_currentChunkIndex + 1);
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveToGallery() async {
    if (_session == null || _isSaving) return;

    setState(() {
      _isSaving = true;
      _saveProgress = 0;
    });

    // Check and request gallery permission
    if (!await StorageService.hasGalleryPermission()) {
      final granted = await StorageService.requestGalleryPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permesso galleria non concesso'),
              backgroundColor: Color(0xFFE53935),
            ),
          );
          setState(() => _isSaving = false);
        }
        return;
      }
    }

    final total = _session!.chunkPaths.length;
    int saved = 0;

    for (int i = 0; i < total; i++) {
      final path = _session!.chunkPaths[i];
      try {
        final file = File(path);
        if (await file.exists()) {
          await StorageService.saveChunksToGallery([path]);
          saved++;
        }
      } catch (_) {}

      setState(() {
        _saveProgress = (i + 1) / total;
      });
    }

    setState(() {
      _isSaving = false;
      _saved = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$saved file salvati in Galleria! 📸'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _discardAndGoHome() async {
    // Clean up chunk files
    if (_session != null) {
      await StorageService.deleteChunks(_session!.chunkPaths);
    }

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(
        body: Center(child: Text('Nessuna registrazione')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Video player
            Expanded(
              child: _buildVideoPlayer(),
            ),

            // Chunk navigation
            if (_session!.chunkPaths.length > 1) _buildChunkNav(),

            // Progress bar
            if (_videoController != null &&
                _videoController!.value.isInitialized)
              _buildProgressBar(),

            // Info + Actions
            _buildInfoAndActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, color: Colors.white54, size: 18),
                SizedBox(width: 6),
                Text(
                  'RIEPILOGO',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _discardAndGoHome(),
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE53935)),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
        setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),

          // Play/Pause overlay
          if (!_videoController!.value.isPlaying)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChunkNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_session!.chunkPaths.length, (index) {
          final isActive = index == _currentChunkIndex;
          return GestureDetector(
            onTap: () => _loadChunk(index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 32 : 24,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: isActive
                    ? const Color(0xFFE53935)
                    : Colors.white.withValues(alpha: 0.2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildProgressBar() {
    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            _formatDuration(position),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFFE53935),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                thumbColor: const Color(0xFFE53935),
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: duration.inMilliseconds > 0
                    ? position.inMilliseconds / duration.inMilliseconds
                    : 0,
                onChanged: (v) {
                  _videoController!.seekTo(
                    Duration(
                        milliseconds:
                            (v * duration.inMilliseconds).round()),
                  );
                },
              ),
            ),
          ),
          Text(
            _formatDuration(duration),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoAndActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Duration info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoItem(
                icon: Icons.timer,
                label: 'DURATA',
                value: _session!.formattedDuration,
              ),
              _buildInfoItem(
                icon: Icons.video_file,
                label: 'FRAMMENTI',
                value: '${_session!.chunkCount}',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Save progress
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _saveProgress,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFE53935)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Salvataggio in corso... ${(_saveProgress * 100).toInt()}%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Action buttons
          Row(
            children: [
              // Discard button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _discardAndGoHome,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Scarta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white60,
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Save button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (_isSaving || _saved) ? null : _saveToGallery,
                  icon: Icon(
                    _saved ? Icons.check : Icons.save_alt,
                    size: 20,
                  ),
                  label: Text(_saved ? 'Salvato!' : 'Salva in Galleria'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _saved
                        ? Colors.green.shade700
                        : const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFE53935), size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
