import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'test/integration/integration_test_utils.dart';

void main() async {
  log('--- Environment Variables ---');
  log('CL_AUTH_URL: ${Platform.environment['CL_AUTH_URL']}');
  log('CL_COMPUTE_URL: ${Platform.environment['CL_COMPUTE_URL']}');
  log('CL_STORE_URL: ${Platform.environment['CL_STORE_URL']}');
  log('CL_USERNAME: ${Platform.environment['CL_USERNAME']}');

  log('\n--- IntegrationTestConfig ---');
  printConfig();

  log('\n--- Connectivity Checks ---');
  await checkUrl('Auth', IntegrationTestConfig.authUrl);
  await checkUrl('Compute', IntegrationTestConfig.computeUrl);
  await checkUrl('Store', IntegrationTestConfig.storeUrl);
}

Future<void> checkUrl(String name, String url) async {
  log('Checking $name at $url...');
  try {
    final response = await http.get(Uri.parse(url));
    log('  Status: ${response.statusCode}');
    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    log('  Error: $e');
  }
}
