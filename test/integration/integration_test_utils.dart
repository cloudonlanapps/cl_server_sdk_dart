import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:cl_server_dart_client/cl_server_dart_client.dart';

class IntegrationTestConfig {
  static String get authUrl {
    if (Platform.environment.containsKey('CL_AUTH_URL')) {
      return Platform.environment['CL_AUTH_URL']!;
    }
    const fromEnv = String.fromEnvironment('CL_AUTH_URL');
    return fromEnv.isNotEmpty ? fromEnv : 'http://localhost:8010';
  }

  static String get computeUrl {
    if (Platform.environment.containsKey('CL_COMPUTE_URL')) {
      return Platform.environment['CL_COMPUTE_URL']!;
    }
    const fromEnv = String.fromEnvironment('CL_COMPUTE_URL');
    return fromEnv.isNotEmpty ? fromEnv : 'http://localhost:8012';
  }

  static String get storeUrl {
    if (Platform.environment.containsKey('CL_STORE_URL')) {
      return Platform.environment['CL_STORE_URL']!;
    }
    const fromEnv = String.fromEnvironment('CL_STORE_URL');
    return fromEnv.isNotEmpty ? fromEnv : 'http://localhost:8011';
  }

  static bool get computeAuthRequired {
    var val = 'true';
    if (Platform.environment.containsKey('CL_COMPUTE_AUTH_REQUIRED')) {
      val = Platform.environment['CL_COMPUTE_AUTH_REQUIRED']!;
    } else {
      const fromEnv = String.fromEnvironment('CL_COMPUTE_AUTH_REQUIRED');
      if (fromEnv.isNotEmpty) val = fromEnv;
    }
    return val.toLowerCase() == 'true';
  }

  static bool get computeGuestMode {
    var val = 'false';
    if (Platform.environment.containsKey('CL_COMPUTE_GUEST_MODE')) {
      val = Platform.environment['CL_COMPUTE_GUEST_MODE']!;
    } else {
      const fromEnv = String.fromEnvironment('CL_COMPUTE_GUEST_MODE');
      if (fromEnv.isNotEmpty) val = fromEnv;
    }
    return val.toLowerCase() == 'true';
  }

  static bool get storeGuestMode {
    var val = 'false';
    if (Platform.environment.containsKey('CL_STORE_GUEST_MODE')) {
      val = Platform.environment['CL_STORE_GUEST_MODE']!;
    } else {
      const fromEnv = String.fromEnvironment('CL_STORE_GUEST_MODE');
      if (fromEnv.isNotEmpty) val = fromEnv;
    }
    return val.toLowerCase() == 'true';
  }

  static String? get username {
    if (Platform.environment.containsKey('CL_USERNAME')) {
      return Platform.environment['CL_USERNAME'];
    }
    const fromEnv = String.fromEnvironment('CL_USERNAME');
    return fromEnv.isNotEmpty ? fromEnv : null;
  }

  static String? get password {
    if (Platform.environment.containsKey('CL_PASSWORD')) {
      return Platform.environment['CL_PASSWORD'];
    }
    const fromEnv = String.fromEnvironment('CL_PASSWORD');
    return fromEnv.isNotEmpty ? fromEnv : null;
  }

  static bool get isAuthEnabled => username != null && password != null;

  static ServerConfig get serverConfig => ServerConfig(
    authUrl: authUrl,
    computeUrl: computeUrl,
    storeUrl: storeUrl,
  );
}

class IntegrationHelper {
  static Future<SessionManager> createSession() async {
    final session = SessionManager(
      serverConfig: IntegrationTestConfig.serverConfig,
    );
    if (IntegrationTestConfig.isAuthEnabled) {
      await session.login(
        IntegrationTestConfig.username!,
        IntegrationTestConfig.password!,
      );
    }
    return session;
  }

  static Future<ComputeClient> createComputeClient([
    SessionManager? session,
  ]) async {
    session ??= await createSession();
    return session.createComputeClient();
  }

  static Future<StoreManager> createStoreManager([
    SessionManager? session,
  ]) async {
    session ??= await createSession();
    // StoreManager requires auth usually, unless guest mode
    if (IntegrationTestConfig.isAuthEnabled) {
      return session.createStoreManager();
    } else {
      return StoreManager.guest(baseUrl: IntegrationTestConfig.storeUrl);
    }
  }

  static String get testVectorsDir {
    if (Platform.environment.containsKey('TEST_VECTORS_DIR')) {
      return Platform.environment['TEST_VECTORS_DIR']!;
    }
    return '/Users/anandasarangaram/Work/cl_server_test_media';
  }

  static Future<File> getTestImage([
    String name = 'test_image_1920x1080.jpg',
  ]) async {
    final file = File('$testVectorsDir/images/$name');
    if (file.existsSync()) return file;

    // Fallback/Fallback
    final fallback = File(name);
    if (!fallback.existsSync()) {
      await fallback.writeAsBytes(List.filled(100, 0));
    }
    return fallback;
  }

  static Future<File> getTestVideo([
    String name = 'test_video_1080p_10s.mp4',
  ]) async {
    final file = File('$testVectorsDir/videos/$name');
    if (file.existsSync()) return file;

    final fallback = File(name);
    if (!fallback.existsSync()) {
      await fallback.writeAsBytes(List.filled(100, 0));
    }
    return fallback;
  }

  static Future<void> cleanupStoreEntities() async {
    if (!IntegrationTestConfig.isAuthEnabled) return;

    final session = await createSession();
    final store = session.createStoreManager();

    // Delete all entities logic? StoreManager doesn't have deleteAll.
    // Python tests do bulk delete or list & delete.
    // We can implement list & delete loop.
    try {
      // Try minimal bulk delete first (exposed via client)
      await store.storeClient.deleteAllEntities();
      print('Called deleteAllEntities()');
    } catch (_) {
      // Fallback to individual
    }

    try {
      var deletedCount = 0;
      var result = await store.listEntities(pageSize: 100);
      while (result.isSuccess && result.data!.items.isNotEmpty) {
        for (final item in result.data!.items) {
          try {
            await store.deleteEntity(item.id);
            deletedCount++;
          } catch (e) {
            print('Cleanup error deleting ${item.id}: $e');
          }
        }
        result = await store.listEntities(pageSize: 100);
      }
      if (deletedCount > 0) print('Cleaned up $deletedCount entities.');
    } on Object catch (e) {
      // ignore: avoid_print
      print('Cleanup warning: $e');
    } finally {
      await session.close();
    }
  }

  /// Create a unique copy of a file.
  /// If it's an image, we modify pixels to ensure perceptual hash changes.
  /// Fallback to appending bytes for non-images or on error.
  static Future<File> createUniqueCopy(
    File source,
    File dest, {
    int offset = 0,
  }) async {
    try {
      final bytes = await source.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image != null) {
        // Modify last 16 pixels to ensure unique perceptual hash
        // (Matching Python SDK logic)
        final random = Random();
        final uniqueBytes = List<int>.generate(16, (_) => random.nextInt(256));
        final totalPixels = image.width * image.height;

        for (var i = 0; i < uniqueBytes.length; i++) {
          final idx = totalPixels - 1 - i;
          if (idx < 0) break;

          final x = idx % image.width;
          final y = idx ~/ image.width;

          // Get current pixel
          final pixel = image.getPixel(x, y);

          // Modify red channel (or first channel)
          // Note: image 3.x uses int for colors typically 0xAABBGGRR or similar
          // We'll just set a new color to ensure change
          final newColor = img.getColor(
            uniqueBytes[i],
            img.getGreen(pixel),
            img.getBlue(pixel),
            img.getAlpha(pixel),
          );

          image.setPixel(x, y, newColor);
        }

        // Save as JPG (assuming test images are mostly JPG/PNG, re-encoding as JPG is safe for tests)
        // or re-encode same format. For simplicity sticking to JPG for test inputs.
        final encoded = img.encodeJpg(image, quality: 95);
        await dest.writeAsBytes(encoded);
        return dest;
      }
    } catch (e) {
      print(
        'Warning: Failed to modify image pixels: $e. Falling back to append.',
      );
    }

    // Fallback: simple copy + append
    await source.copy(dest.path);
    final random = Random();
    final appendBytes = List<int>.generate(
      16 + (offset % 16),
      (_) => random.nextInt(256),
    );
    await dest.writeAsBytes(appendBytes, mode: FileMode.append);
    return dest;
  }
}

void printConfig() {
  // ignore: avoid_print
  print('Integration Test Config:');
  // ignore: avoid_print
  print('Auth URL: ${IntegrationTestConfig.authUrl}');
  // ignore: avoid_print
  print('Compute URL: ${IntegrationTestConfig.computeUrl}');
  // ignore: avoid_print
  print('Store URL: ${IntegrationTestConfig.storeUrl}');
  // ignore: avoid_print
  print('User: ${IntegrationTestConfig.username}');
}
