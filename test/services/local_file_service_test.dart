import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monolog/services/local_file_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../helpers/test_helpers.dart';

void main() {
  late LocalFileService fileService;
  late Directory tempDir;

  setUp(() {
    fileService = LocalFileService();
    tempDir = createTestTempDir();

    // Override path_provider to use our temp directory.
    PathProviderPlatform.instance = FakePathProvider(
      docsPath: tempDir.path,
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  // =========================================================================
  // saveFile
  // =========================================================================

  group('saveFile', () {
    test('copies file to destination with unique name', () async {
      // Create a source file.
      final sourceFile = File(p.join(tempDir.path, 'original.txt'));
      await sourceFile.writeAsString('hello');

      final savedPath = await fileService.saveFile(sourceFile.path);

      expect(File(savedPath).existsSync(), isTrue);
      expect(await File(savedPath).readAsString(), 'hello');
      // Should be in the images/ subdirectory.
      expect(savedPath, contains('images'));
    });

    test('preserves file extension from source path', () async {
      final sourceFile = File(p.join(tempDir.path, 'doc.pdf'));
      await sourceFile.writeAsBytes(fakePdfBytes());

      final savedPath = await fileService.saveFile(sourceFile.path);

      expect(p.extension(savedPath), '.pdf');
    });

    test('uses fileName extension as fallback', () async {
      // Source path without extension.
      final sourceFile = File(p.join(tempDir.path, 'noext'));
      await sourceFile.writeAsString('data');

      final savedPath = await fileService.saveFile(
        sourceFile.path,
        fileName: 'document.xlsx',
      );

      expect(p.extension(savedPath), '.xlsx');
    });

    test('defaults to .bin when no extension available', () async {
      final sourceFile = File(p.join(tempDir.path, 'noext'));
      await sourceFile.writeAsString('data');

      final savedPath = await fileService.saveFile(sourceFile.path);

      expect(p.extension(savedPath), '.bin');
    });

    test('generates unique filenames for same source', () async {
      final sourceFile = File(p.join(tempDir.path, 'photo.jpg'));
      await sourceFile.writeAsBytes(fakePngBytes());

      final path1 = await fileService.saveFile(sourceFile.path);
      final path2 = await fileService.saveFile(sourceFile.path);

      expect(path1, isNot(path2));
      expect(File(path1).existsSync(), isTrue);
      expect(File(path2).existsSync(), isTrue);
    });
  });

  // =========================================================================
  // deleteFile
  // =========================================================================

  group('deleteFile', () {
    test('deletes existing file', () async {
      final file = File(p.join(tempDir.path, 'delete_me.txt'));
      await file.writeAsString('bye');
      expect(file.existsSync(), isTrue);

      await fileService.deleteFile(file.path);

      expect(file.existsSync(), isFalse);
    });

    test('does not throw for non-existent file', () async {
      // Should not throw.
      await fileService.deleteFile('/nonexistent/path/file.txt');
    });
  });

  // =========================================================================
  // getFileSize
  // =========================================================================

  group('getFileSize', () {
    test('returns correct size for existing file', () async {
      final file = File(p.join(tempDir.path, 'sized.txt'));
      await file.writeAsBytes(List.filled(42, 0));

      final size = await fileService.getFileSize(file.path);

      expect(size, 42);
    });

    test('returns 0 for non-existent file', () async {
      final size = await fileService.getFileSize('/nonexistent/file.txt');

      expect(size, 0);
    });
  });
}
