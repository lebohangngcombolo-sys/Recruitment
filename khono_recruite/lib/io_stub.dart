import 'dart:typed_data';

/// Stub for web: dart:io is not available. [File] is only used when kIsWeb is false.
/// On web, profile image bytes are used directly via MemoryImage.
class File {
  File(this._path);
  final String _path;
  String get path => _path;
  Uint8List readAsBytesSync() =>
      throw UnsupportedError('dart:io File is not available on web');
}
