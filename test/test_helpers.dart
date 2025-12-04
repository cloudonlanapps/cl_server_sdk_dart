import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;

// Test configuration constants
const String authServiceBaseUrl = 'http://localhost:8000';
const String storeServiceBaseUrl = 'http://localhost:8001';
const String computeServiceBaseUrl = 'http://localhost:8001';

/// Reusable mock HTTP client for testing
class MockHttpClient extends http.BaseClient {
  MockHttpClient(this.responses);

  final Map<String, http.Response> responses;
  late http.BaseRequest lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    final key = '${request.method} ${request.url}';
    final response = responses[key];

    if (response != null) {
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }

    return http.StreamedResponse(
      Stream.value([]),
      404,
      request: request,
    );
  }
}

/// Factory for creating ServerConfig for tests
ServerConfig createTestServerConfig({
  String? authUrl,
  String? storeUrl,
  String? computeUrl,
}) {
  return ServerConfig(
    authServiceBaseUrl: authUrl ?? authServiceBaseUrl,
    storeServiceBaseUrl: storeUrl ?? storeServiceBaseUrl,
    computeServiceBaseUrl: computeUrl ?? computeServiceBaseUrl,
  );
}
