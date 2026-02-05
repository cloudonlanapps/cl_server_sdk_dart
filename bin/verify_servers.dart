import 'dart:developer';
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

  log('--- Health Check ---');
  for (final entry in urls.entries) {
    try {
      final response = await http
          .get(Uri.parse(entry.value))
          .timeout(const Duration(seconds: 5));
      log('${entry.key}: SUCCESS (${response.statusCode})');
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      log('${entry.key}: FAILED ($e)');
    }
  }

  log('\n--- Store Manager Test ---');
  final session = SessionManager(
    serverConfig: ServerConfig(
      authUrl: urls['Auth']!,
      storeUrl: urls['Store']!,
      computeUrl: urls['Compute']!,
      mqttUrl: mqttUrl,
    ),
  );

  try {
    log('Logging in...');
    await session.login('admin', 'admin');
    log('Login success.');

    final store = session.createStoreManager();
    log('Created store manager.');

    log('Listing entities...');
    final listRes = await store.listEntities(pageSize: 5);
    if (listRes.isSuccess) {
      log('List success. Found ${listRes.data?.items.length} entities.');
    } else {
      log('List failed: ${listRes.error}');
    }
    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    log('Caught exception: $e');
  } finally {
    await session.close();
  }
}
