import 'dart:io';
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
      return StoreManager.guest();
    }
  }

  static Future<File> getTestImage() async {
    final file = File('test_image.jpg');
    if (!file.existsSync()) {
      // Create a dummy image or download?
      // For now just create empty file to pass "File" check,
      // but server will fail if not valid image.
      // We assume integration environment sets up media.
      // Or we write simple bytes.
      await file.writeAsBytes(List.filled(100, 0));
    }
    return file;
  }

  static Future<void> cleanupStoreEntities() async {
    if (!IntegrationTestConfig.isAuthEnabled) return;

    final session = await createSession();
    final store = session.createStoreManager();

    // Delete all entities logic? StoreManager doesn't have deleteAll.
    // Python tests do bulk delete or list & delete.
    // We can implement list & delete loop.
    try {
      var result = await store.listEntities(pageSize: 100);
      while (result.isSuccess && result.data!.items.isNotEmpty) {
        for (final item in result.data!.items) {
          await store.deleteEntity(item.id);
        }
        result = await store.listEntities(pageSize: 100);
      }
    } on Object catch (e) {
      // ignore: avoid_print
      print('Cleanup warning: $e');
    } finally {
      await session.close();
    }
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
