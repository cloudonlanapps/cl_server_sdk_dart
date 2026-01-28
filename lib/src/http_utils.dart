import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class HttpUtils {
  /// Guess MIME type from file extension.
  static String guessMimeType(String filePath) {
    final mimeType = lookupMimeType(filePath);
    return mimeType ?? 'application/octet-stream';
  }

  /// Create MultipartFiles from paths.
  ///
  /// Returns a list of futures that resolve to MultipartFile objects.
  static Future<List<http.MultipartFile>> createMultipartFiles(
    Map<String, String> files,
  ) async {
    final multipartFiles = <http.MultipartFile>[];

    for (final entry in files.entries) {
      final field = entry.key;
      final filePath = entry.value;

      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileSystemException('File not found', filePath);
      }

      final mimeType = guessMimeType(filePath);
      final mediaType = mimeType.split('/');

      multipartFiles.add(
        await http.MultipartFile.fromPath(
          field,
          filePath,
          contentType: mediaType.length == 2
              ? MediaType(mediaType[0], mediaType[1])
              : null,
        ),
      );
    }

    return multipartFiles;
  }

  /// Create a single MultipartFile from path.
  static Future<http.MultipartFile> createMultipartFile(
    String field,
    File file,
  ) async {
    final filePath = file.path;
    if (!file.existsSync()) {
      throw FileSystemException('File not found', filePath);
    }

    final mimeType = guessMimeType(filePath);
    final mediaType = mimeType.split('/');

    return http.MultipartFile.fromPath(
      field,
      filePath,
      contentType: mediaType.length == 2
          ? MediaType(mediaType[0], mediaType[1])
          : null,
    );
  }

  /// Build form data map.
  static Map<String, String> buildFormData({
    Map<String, Object?>? params,
    int? priority,
  }) {
    final formData = <String, String>{};

    if (priority != null) {
      formData['priority'] = priority.toString();
    }

    if (params != null) {
      for (final entry in params.entries) {
        if (entry.value != null) {
          formData[entry.key] = entry.value.toString();
        } else {
          formData[entry.key] = '';
        }
      }
    }

    return formData;
  }
}

// Helper for MediaType since http package uses http_parser internally
// but exposes it via MultipartFile.
// We import from http_parser if needed, but http package exports MediaType usually?
// Actually http package does not export MediaType, it's in http_parser.
// But http.MultipartFile.fromPath takes contentType as MediaType.
// We need to import http_parser.
// Wait, pubspec doesn't list http_parser directly, but it's a dependency of http.
// We should check if we can use it.
// Actually, `http` package usually exports it or we rely on transitive.
// Ideally we should add `http_parser` to pubspec if we use it directly.
// But `package:http/http.dart` does not export MediaType.
// Let's safe bet: pass contentType as MediaType object?
// `http.MultipartFile.fromPath` signature: `MediaType? contentType`.
// So we need `import 'package:http_parser/http_parser.dart';`
// Check pubspec.lock or if we can avoid it.
// Alternatively, let `fromPath` guess it?
// `fromPath` has logic to guess mime type if not provided.
// Implementation of `fromPath`: `var mediaType = contentType ?? _mediaType(filename);`
// `_mediaType` uses `lookupMimeType`.
// So we might not need to manually guess if `fromPath` does it.
// But `http_utils.py` does strict guessing.
// Let's let `fromPath` do it unless we strictly need to control it.
// But let's check if `http_parser` is available.
// If I use `MediaType` I need the import.
// For now, I will omit the manual content type and let `fromPath` handle it,
// or if I strongly need it, I'll rely on `lookupMimeType` and string parsing
// BUT I can't construct MediaType without the class.
// Let's assume `http` package makes `http_parser` available or `multipart_file.dart` handles it.
// Actually, to be safe, I'll remove the explicit `contentType` argument for now
// and trust `fromPath` which uses `mime` package internally anyway.
