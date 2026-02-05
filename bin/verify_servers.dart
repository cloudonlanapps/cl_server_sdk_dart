import 'dart:io';

import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;

void main() async {
  final urls = {
    'Auth': Platform.environment['CL_AUTH_URL'] ?? 'http://localhost:8010',
    'Store': Platform.environment['CL_STORE_URL'] ?? 'http://localhost:8011',
    'Compute': Platform.environment['CL_COMPUTE_URL'] ?? 'http://localhost:8012',
  };
  final mqttUrl = Platform.environment['CL_MQTT_URL'] ?? 'mqtt://localhost:1883';

  print('--- Health Check ---');
  for (final entry in urls.entries) {
    try {
      final response = await http
          .get(Uri.parse(entry.value))
          .timeout(const Duration(seconds: 5));
      print('${entry.key}: SUCCESS (${response.statusCode})');
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      print('${entry.key}: FAILED ($e)');
    }
  }

  print('\n--- Store Manager Test ---');
  final session = SessionManager(
    serverConfig: ServerConfig(
      authUrl: urls['Auth']!,
      storeUrl: urls['Store']!,
      computeUrl: urls['Compute']!,
      mqttUrl: mqttUrl,
    ),
  );

  try {
    print('Logging in...');
    await session.login('admin', 'admin');
    print('Login success.');

    final store = session.createStoreManager();
    print('Created store manager.');

    print('Listing entities...');
    final listRes = await store.listEntities(pageSize: 5);
    if (listRes.isSuccess) {
      print('List success. Found ${listRes.data?.items.length} entities.');
    } else {
      print('List failed: ${listRes.error}');
    }
    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    print('Caught exception: $e');
  } finally {
    await session.close();
  }
}
