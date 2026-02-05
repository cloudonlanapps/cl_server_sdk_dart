import 'dart:convert';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('ComputeClient Auth Integration', () {
    late ComputeClient client;
    late MockAuthProvider mockAuth;
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockAuth = MockAuthProvider();
      mockHttpClient = MockHttpClient();

      registerFallbackValue(Uri.parse('http://test.local'));

      when(() => mockAuth.refreshTokenIfNeeded()).thenAnswer((_) async {});

      // Setup getHeaders to return different values on subsequent calls
      var callCount = 0;
      when(() => mockAuth.getHeaders()).thenAnswer((_) {
        callCount++;
        return {'Authorization': 'Bearer token$callCount'};
      });

      client = ComputeClient(
        baseUrl: 'http://test.local',
        mqttUrl: 'mqtt://mqtt.local:1883',
        authProvider: mockAuth,
        client: mockHttpClient,
      );
    });

    test('test_dynamic_header_updates', () async {
      final responseBody = jsonEncode({
        'job_id': 'job1',
        'status': 'completed',
        'task_type': 'test',
        'created_at': 1234567890,
        'updated_at': 1234567890,
      });

      when(
        () => mockHttpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      // Make first request
      await client.getJob('job1');

      verify(
        () => mockHttpClient.get(
          any(that: predicate<Uri>((uri) => uri.path == '/jobs/job1')),
          headers: any(
            named: 'headers',
            that: containsPair('Authorization', 'Bearer token1'),
          ),
        ),
      ).called(1);

      // Make second request
      await client.getJob('job1');

      verify(
        () => mockHttpClient.get(
          any(that: predicate<Uri>((uri) => uri.path == '/jobs/job1')),
          headers: any(
            named: 'headers',
            that: containsPair('Authorization', 'Bearer token2'),
          ),
        ),
      ).called(1);

      verify(() => mockAuth.refreshTokenIfNeeded()).called(2);
    });
  });
}
