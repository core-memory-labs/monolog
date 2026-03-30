import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'file_service.dart';

/// Local file system implementation of [FileService].
///
/// Stores attachment files in `{app_documents}/images/` directory.
/// Directory name kept as `images/` for backward compatibility with
/// existing image paths stored in the database (from Stage 3.1).
class LocalFileService implements FileService {
  /// Directory name inside app documents. Kept as `images/` so that existing
  /// absolute paths for images (from Stage 3.1) continue to resolve.
  static const _filesDirName = 'images';

  @override
  Future<String> saveFile(String sourcePath, {String? fileName}) async {
    final dir = await _ensureFilesDir();

    // Determine extension: prefer source path, fall back to fileName.
    var ext = p.extension(sourcePath).toLowerCase();
    if (ext.isEmpty && fileName != null) {
      ext = p.extension(fileName).toLowerCase();
    }
    if (ext.isEmpty) ext = '.bin';

    final destName = _generateFileName(ext);
    final destPath = p.join(dir.path, destName);

    await File(sourcePath).copy(destPath);
    return destPath;
  }

  @override
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<int> getFileSize(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return file.length();
    }
    return 0;
  }

  /// Returns the files directory, creating it if necessary.
  Future<Directory> _ensureFilesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _filesDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Generates a unique filename like `file_1700000000000_0042.pdf`.
  static String _generateFileName(String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'file_${timestamp}_$random$extension';
  }
}
