import 'package:mockito/annotations.dart';
import 'package:monolog/services/database_service.dart';
import 'package:monolog/services/file_service.dart';

/// Mockito mock generation for service interfaces.
///
/// Run `dart run build_runner build` to generate `mocks.mocks.dart`.
/// This creates `MockDatabaseService` and `MockFileService` classes.
@GenerateMocks([DatabaseService, FileService])
void main() {}
