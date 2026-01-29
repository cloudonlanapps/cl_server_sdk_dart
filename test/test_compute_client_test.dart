import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockMQTTJobMonitor extends Mock implements MQTTJobMonitor {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group('ComputeClient', () {
    late MockHttpClient mockHttpClient;
    late MockMQTTJobMonitor mockMqttMonitor;
    late ComputeClient client;

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockMqttMonitor = MockMQTTJobMonitor();

      // Default stubbing for close/cleanup
      when(() => mockMqttMonitor.connect()).thenAnswer((_) async {});
      when(() => mockMqttMonitor.isConnected).thenReturn(true);
      when(() => mockMqttMonitor.broker).thenReturn('localhost');
      when(() => mockMqttMonitor.port).thenReturn(1883);
      when(() => mockMqttMonitor.close()).thenReturn(null);

      client = ComputeClient(
        client: mockHttpClient,
        mqttMonitor: mockMqttMonitor,
        baseUrl: 'http://localhost:8012',
      );
    });

    tearDown(() async {
      await client.close();
    });

    test('test_init_with_defaults', () async {
      final c = ComputeClient(mqttMonitor: mockMqttMonitor);
      expect(c.baseUrl, equals('http://localhost:8012'));
      expect(c.timeout.inSeconds, equals(30));
      expect(c.auth, isA<NoAuthProvider>());
      await c.close();
    });

    test('test_init_with_custom_parameters', () async {
      final auth = JWTAuthProvider(token: 'test-token');
      final c = ComputeClient(
        baseUrl: 'http://custom:9000',
        timeout: const Duration(seconds: 60),
        authProvider: auth,
        mqttMonitor: mockMqttMonitor,
      );
      expect(c.baseUrl, equals('http://custom:9000'));
      expect(c.timeout.inSeconds, equals(60));
      expect(c.auth, equals(auth));
      await c.close();
    });

    test('test_init_with_server_config', () async {
      final config = ServerConfig(
        computeUrl: 'https://compute.example.com',
        mqttBroker: 'mqtt.example.com',
        mqttPort: 8883,
      );
      final c = ComputeClient(
        serverConfig: config,
        mqttMonitor: mockMqttMonitor,
      );
      expect(c.baseUrl, equals('https://compute.example.com'));
      await c.close();
    });

    test('test_init_with_server_config_and_overrides', () async {
      final config = ServerConfig(
        computeUrl: 'https://config.example.com',
        mqttBroker: 'config-broker',
        mqttPort: 1883,
      );
      final c = ComputeClient(
        baseUrl: 'https://override.example.com',
        serverConfig: config,
        mqttMonitor: mockMqttMonitor,
      );
      expect(c.baseUrl, equals('https://override.example.com'));
      await c.close();
    });

    test('test_init_backward_compatibility', () async {
      final c = ComputeClient(mqttMonitor: mockMqttMonitor);
      expect(c.baseUrl, isNotNull);
      expect(c.timeout.inSeconds, equals(30));
      expect(c.auth, isA<NoAuthProvider>());
      await c.close();
    });

    test('test_get_job_success', () async {
      final jobData = {
        'job_id': 'test-123',
        'task_type': 'clip_embedding',
        'status': 'completed',
        'progress': 100,
        'created_at': 1234567890,
        'params': <String, dynamic>{},
      };

      when(
        () => mockHttpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(jsonEncode(jobData), 200));

      final job = await client.getJob('test-123');

      expect(job.jobId, equals('test-123'));
      expect(job.taskType, equals('clip_embedding'));
      expect(job.status, equals('completed'));

      verify(
        () => mockHttpClient.get(
          Uri.parse('http://localhost:8012/jobs/test-123'),
          headers: any(named: 'headers'),
        ),
      ).called(1);
    });

    test('test_get_job_invalid_response', () async {
      // In Dart, FormatException or TypeError if mapping fails
      when(
        () => mockHttpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(jsonEncode('not a dict'), 200));

      expect(
        () => client.getJob('test-123'),
        throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
      );
    });

    test('test_delete_job_success', () async {
      when(
        () => mockHttpClient.delete(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 204));

      await client.deleteJob('test-123');

      verify(
        () => mockHttpClient.delete(
          Uri.parse('http://localhost:8012/jobs/test-123'),
          headers: any(named: 'headers'),
        ),
      ).called(1);
    });

    test('test_download_job_file_success', () async {
      final fileContent = 'test file content'.codeUnits;

      when(
        () => mockHttpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response.bytes(fileContent, 200));

      final tempDir = Directory.systemTemp.createTempSync();
      final dest = File('${tempDir.path}/output.txt');

      await client.downloadJobFile('test-123', 'output/result.txt', dest);

      expect(dest.existsSync(), isTrue);
      expect(dest.readAsBytesSync(), equals(fileContent));

      verify(
        () => mockHttpClient.get(
          Uri.parse(
            'http://localhost:8012/jobs/test-123/files/output/result.txt',
          ),
          headers: any(named: 'headers'),
        ),
      ).called(1);

      tempDir.deleteSync(recursive: true);
    });

    test('test_get_capabilities_success', () async {
      final capsData = {
        'num_workers': 2,
        'capabilities': {'clip_embedding': 1, 'exif': 1},
      };

      when(
        () => mockHttpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(jsonEncode(capsData), 200));

      final caps = await client.getCapabilities();

      expect(caps.numWorkers, equals(2));
      expect(caps.capabilities['clip_embedding'], equals(1));

      verify(
        () => mockHttpClient.get(
          Uri.parse('http://localhost:8012/capabilities'),
          headers: any(named: 'headers'),
        ),
      ).called(1);
    });

    test('test_wait_for_workers_success', () async {
      when(
        () => mockMqttMonitor.waitForCapability(any()),
      ).thenAnswer((_) async => true);

      final result = await client.waitForWorkers(
        requiredCapabilities: ['clip_embedding', 'exif'],
      );

      expect(result, isTrue);
      verify(
        () => mockMqttMonitor.waitForCapability('clip_embedding'),
      ).called(1);
      verify(() => mockMqttMonitor.waitForCapability('exif')).called(1);
    });

    test('test_wait_for_workers_no_requirements', () async {
      final result = await client.waitForWorkers(requiredCapabilities: []);
      expect(result, isTrue);
      verifyNever(() => mockMqttMonitor.waitForCapability(any()));
    });

    test('test_wait_for_workers_timeout', () async {
      when(
        () => mockMqttMonitor.waitForCapability('clip_embedding'),
      ).thenThrow(WorkerUnavailableError('clip_embedding', {}));

      expect(
        () => client.waitForWorkers(requiredCapabilities: ['clip_embedding']),
        throwsA(isA<WorkerUnavailableError>()),
      );
    });

    test('test_subscribe_job_updates', () {
      when(
        () => mockMqttMonitor.subscribeJobUpdates(
          any(),
          onProgress: any(named: 'onProgress'),
          onComplete: any(named: 'onComplete'),
          taskType: any(named: 'taskType'),
        ),
      ).thenReturn('sub-123');

      void onProgress(JobResponse j) {}
      void onComplete(JobResponse j) {}

      final subId = client.mqttSubscribeJobUpdates(
        'test-123',
        onProgress: onProgress,
        onComplete: onComplete,
      );

      expect(subId, equals('sub-123'));
      verify(
        () => mockMqttMonitor.subscribeJobUpdates(
          'test-123',
          onProgress: onProgress,
          onComplete: onComplete,
        ),
      ).called(1);
    });

    test('test_unsubscribe', () {
      when(() => mockMqttMonitor.unsubscribe(any())).thenReturn(null);
      client.unsubscribe('sub-123');
      verify(() => mockMqttMonitor.unsubscribe('sub-123')).called(1);
    });

    test('test_wait_for_job_success', () async {
      final jobInProgress = {
        'job_id': 'test-123',
        'task_type': 'test',
        'status': 'processing',
        'progress': 50,
        'created_at': 1234567890,
        'params': <String, dynamic>{},
      };
      final jobCompleted = {
        'job_id': 'test-123',
        'task_type': 'test',
        'status': 'completed',
        'progress': 100,
        'created_at': 1234567890,
        'params': <String, dynamic>{},
      };

      var callCount = 0;
      when(
        () => mockHttpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(jsonEncode(jobInProgress), 200);
        } else {
          return http.Response(jsonEncode(jobCompleted), 200);
        }
      });

      final job = await client.waitForJob(
        'test-123',
        pollInterval: const Duration(milliseconds: 50),
      );

      expect(job.status, equals('completed'));
      expect(callCount, greaterThanOrEqualTo(2));
    });

    test('test_wait_for_job_timeout', () async {
      final jobInProgress = {
        'job_id': 'test-123',
        'task_type': 'test',
        'status': 'processing',
        'progress': 50,
        'created_at': 1234567890,
        'params': <String, dynamic>{},
      };

      when(
        () => mockHttpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(jsonEncode(jobInProgress), 200));

      expect(
        () => client.waitForJob(
          'test-123',
          pollInterval: const Duration(milliseconds: 10),
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('test_close', () async {
      await client.close();
      verify(() => mockHttpClient.close()).called(1);
      verify(() => mockMqttMonitor.close()).called(1);
    });

    test('test_async_context_manager', () async {
      // Dart doesn't have 'with', but we can verify cleanup after usage
      final c = ComputeClient(
        client: mockHttpClient,
        mqttMonitor: mockMqttMonitor,
      );
      await c.close();
      verify(() => mockHttpClient.close()).called(1);
      verify(() => mockMqttMonitor.close()).called(1);
    });
  });
}
