import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;

void main() async {
  final urls = {
    'Auth': 'http://localhost:8010',
    'Store': 'http://localhost:8011',
    'Compute': 'http://localhost:8012',
  };

  print('--- Health Check ---');
  for (var entry in urls.entries) {
    try {
      final response = await http
          .get(Uri.parse(entry.value))
          .timeout(Duration(seconds: 5));
      print('${entry.key}: SUCCESS (${response.statusCode})');
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
  } catch (e) {
    print('Caught exception: $e');
  } finally {
    await session.close();
  }
}
