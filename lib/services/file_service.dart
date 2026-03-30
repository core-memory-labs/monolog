/// Abstract interface for file operations on disk.
///
/// Manages attachment files: saving picked images/files to the app's
/// private directory and deleting them when entries are removed.
///
/// Extracted as an abstract class to allow mock implementations in unit tests.
abstract class FileService {
  /// Copies the file at [sourcePath] into the app's files directory
  /// with a unique filename. Returns the destination path.
  ///
  /// The original file extension is preserved. If [fileName] is provided,
  /// its extension is used as a fallback when [sourcePath] has none.
  Future<String> saveFile(String sourcePath, {String? fileName});

  /// Deletes the file at [path] if it exists.
  Future<void> deleteFile(String path);

  /// Returns the size of the file at [path] in bytes, or 0 if not found.
  Future<int> getFileSize(String path);
}
