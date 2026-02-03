import 'dart:io';
import 'dart:math';
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
    final home = Platform.environment['HOME'] ?? '';
    return home.isNotEmpty
        ? '$home/cl_server_test_media'
        : '/tmp/cl_server_test_media';
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
      // var deletedCount = 0;
      var result = await store.listEntities(pageSize: 100);
      while (result.isSuccess && result.data!.items.isNotEmpty) {
        for (final item in result.data!.items) {
          try {
            await store.deleteEntity(item.id);
            // deletedCount++;
          } catch (e) {
            print('Cleanup error deleting ${item.id}: $e');
          }
        }
        result = await store.listEntities(pageSize: 100);
      }
      //if (deletedCount > 0) print('Cleaned up $deletedCount entities.');
    } on Object catch (_) {
      //print('Cleanup warning: $e');
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
    // Attempt to use python side-car for high-quality uniqueness (pixel modification + file size reduction)
    try {
      final scriptPath =
          '${Directory.current.path}/test/integration/make_unique.py';
      // Use uv run to ensure dependencies (Pillow) are available from the workspace environment
      final result = await Process.run('uv', [
        'run',
        'python',
        scriptPath,
        source.path,
        dest.path,
      ]);

      if (result.exitCode == 0 && dest.existsSync()) {
        return dest;
      } else {
        print(
          'Python make_unique failed or dest missing. Exit code: ${result.exitCode}',
        );
        if (result.stderr.toString().isNotEmpty) {
          print('Error: ${result.stderr}');
        }
      }
    } catch (e) {
      print('Error calling python make_unique: $e');
    }

    // Fallback to simple file append strategy if script fails
    await source.copy(dest.path);
    final random = Random(DateTime.now().microsecondsSinceEpoch);
    final appendBytes = List<int>.generate(
      16 + (offset % 16),
      (_) => random.nextInt(256),
    );
    await dest.writeAsBytes(appendBytes, mode: FileMode.append);
    return dest;
  }
}

void printConfig() {
  print('Integration Test Config:');

  print('Auth URL: ${IntegrationTestConfig.authUrl}');

  print('Compute URL: ${IntegrationTestConfig.computeUrl}');

  print('Store URL: ${IntegrationTestConfig.storeUrl}');

  print('User: ${IntegrationTestConfig.username}');
}
