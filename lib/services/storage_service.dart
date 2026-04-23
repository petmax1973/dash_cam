import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing storage: saving to gallery and cleaning up temp files.
class StorageService {
  /// Save all chunk files to the device gallery.
  /// Returns the number of files successfully saved.
  static Future<int> saveChunksToGallery(List<String> chunkPaths) async {
    int savedCount = 0;

    for (final path in chunkPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await Gal.putVideo(path, album: 'DashCam');
          savedCount++;
        }
      } catch (e) {
        // Continue with other files if one fails
        continue;
      }
    }

    return savedCount;
  }

  /// Delete all chunk files for a session.
  static Future<void> deleteChunks(List<String> chunkPaths) async {
    for (final path in chunkPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  /// Clean up any orphaned chunks from previous sessions.
  /// Called at app startup.
  static Future<void> cleanupOrphanedChunks() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final chunksDir = Directory('${tempDir.path}/dashcam_chunks');

      if (await chunksDir.exists()) {
        final files = await chunksDir.list().toList();
        for (final entity in files) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (_) {
      // Ignore cleanup errors on startup
    }
  }

  /// Check if gallery save permission is granted.
  static Future<bool> hasGalleryPermission() async {
    return await Gal.hasAccess();
  }

  /// Request gallery save permission.
  static Future<bool> requestGalleryPermission() async {
    return await Gal.requestAccess();
  }
}
