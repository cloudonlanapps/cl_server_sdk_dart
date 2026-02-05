import 'dart:io';
import 'package:http/http.dart' as http;
import 'test/integration/integration_test_utils.dart';

void main() async {
  print('--- Environment Variables ---');
  print('CL_AUTH_URL: ${Platform.environment['CL_AUTH_URL']}');
  print('CL_COMPUTE_URL: ${Platform.environment['CL_COMPUTE_URL']}');
  print('CL_STORE_URL: ${Platform.environment['CL_STORE_URL']}');
  print('CL_USERNAME: ${Platform.environment['CL_USERNAME']}');

  print('\n--- IntegrationTestConfig ---');
  printConfig();

  print('\n--- Connectivity Checks ---');
  await checkUrl('Auth', IntegrationTestConfig.authUrl);
  await checkUrl('Compute', IntegrationTestConfig.computeUrl);
  await checkUrl('Store', IntegrationTestConfig.storeUrl);
}

Future<void> checkUrl(String name, String url) async {
  print('Checking $name at $url...');
  try {
    final response = await http.get(Uri.parse(url));
    print('  Status: ${response.statusCode}');
    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    print('  Error: $e');
  }
}
