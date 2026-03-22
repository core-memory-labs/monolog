import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages image files on disk: saving picked images to the app's private
/// directory and deleting them when entries are removed.
class ImageService {
  static const _imagesDirName = 'images';

  /// Copies the image at [sourcePath] into the app's images directory
  /// with a unique filename. Returns the destination path.
  Future<String> saveImage(String sourcePath) async {
    final dir = await _ensureImagesDir();
    final ext = p.extension(sourcePath).toLowerCase();
    final fileName = _generateFileName(ext.isEmpty ? '.jpg' : ext);
    final destPath = p.join(dir.path, fileName);

    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Deletes the image file at [path] if it exists.
  Future<void> deleteImage(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Returns the images directory, creating it if necessary.
  Future<Directory> _ensureImagesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _imagesDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Generates a unique filename like `img_1700000000000_0042.jpg`.
  static String _generateFileName(String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'img_${timestamp}_$random$extension';
  }
}
