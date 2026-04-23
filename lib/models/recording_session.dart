/// Model representing a recording session with its chunk files.
class RecordingSession {
  final DateTime startTime;
  final List<String> chunkPaths;
  final int maxDurationMinutes;
  DateTime? endTime;

  RecordingSession({
    required this.startTime,
    required this.maxDurationMinutes,
    List<String>? chunkPaths,
    this.endTime,
  }) : chunkPaths = chunkPaths ?? [];

  /// Whether this session is still actively recording.
  bool get isActive => endTime == null;

  /// Total duration of all saved chunks.
  Duration get totalDuration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return DateTime.now().difference(startTime);
  }

  /// Number of chunks currently saved.
  int get chunkCount => chunkPaths.length;

  /// Formatted duration string (e.g., "05:23").
  String get formattedDuration {
    final d = totalDuration;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// End this session.
  void stop() {
    endTime = DateTime.now();
  }

  /// Add a chunk path to this session.
  void addChunk(String path) {
    chunkPaths.add(path);
  }

  /// Remove the oldest chunk (for cyclic recording).
  String? removeOldestChunk() {
    if (chunkPaths.isNotEmpty) {
      return chunkPaths.removeAt(0);
    }
    return null;
  }
}
