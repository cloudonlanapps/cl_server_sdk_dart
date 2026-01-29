import 'dart:async';
import 'dart:convert';

import 'package:cl_server_dart_client/src/exceptions.dart';
import 'package:cl_server_dart_client/src/models/models.dart';
import 'package:cl_server_dart_client/src/mqtt_monitor.dart';
import 'package:cl_server_dart_client/src/config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:test/test.dart';
import 'package:typed_data/typed_buffers.dart';

class MockMqttServerClient extends Mock implements MqttServerClient {
  @override
  set port(int? port) {}
  @override
  set keepAlivePeriod(int? keepAlivePeriod) {}
  @override
  set autoReconnect(bool? autoReconnect) {}
  @override
  set onConnected(void Function()? onConnected) {}
  @override
  set onDisconnected(void Function()? onDisconnected) {}
  @override
  set onSubscribed(void Function(String)? onSubscribed) {}
  @override
  set connectionMessage(MqttConnectMessage? connectionMessage) {}
}

class MockMqttConnectionStatus extends Mock
    implements MqttClientConnectionStatus {}

void main() {
  setUpAll(() {
    registerFallbackValue(MqttQos.atLeastOnce);
  });

  group('MQTTJobMonitor', () {
    late MockMqttServerClient mockClient;
    late StreamController<List<MqttReceivedMessage<MqttMessage>>>
    updatesController;

    setUp(() {
      mockClient = MockMqttServerClient();
      updatesController = StreamController.broadcast();

      final status = MockMqttConnectionStatus();
      when(() => status.state).thenReturn(MqttConnectionState.connected);
      when(() => mockClient.connectionStatus).thenReturn(status);
      when(() => mockClient.connect()).thenAnswer((_) async => status);
      when(
        () => mockClient.updates,
      ).thenAnswer((_) => updatesController.stream);
      when(() => mockClient.subscribe(any(), any())).thenReturn(Subscription());
      when(() => mockClient.disconnect()).thenAnswer((_) {});
      when(() => mockClient.logging(on: any(named: 'on'))).thenReturn(null);
    });

    tearDown(() async {
      await updatesController.close();
    });

    MQTTJobMonitor createMonitor({String? broker, int? port}) {
      return MQTTJobMonitor(
        broker: broker ?? 'localhost',
        port: port ?? 1883,
        clientFactory: (b, cid) => mockClient,
      );
    }

    test('test_init_connects_to_broker', () async {
      final monitor = createMonitor();
      await monitor.connect();

      verify(() => mockClient.connect()).called(1);
      verify(
        () => mockClient.subscribe('inference/workers/+', MqttQos.atLeastOnce),
      ).called(1);
      verify(
        () => mockClient.subscribe('inference/events', MqttQos.atLeastOnce),
      ).called(1);
    });

    test('test_init_with_custom_broker', () async {
      final monitor = createMonitor(broker: 'custom-broker', port: 1234);
      expect(monitor.broker, equals('custom-broker'));
      expect(monitor.port, equals(1234));

      await monitor.connect();
      verify(() => mockClient.connect()).called(1);
    });

    test('test_subscribe_job_updates_returns_subscription_id', () {
      final monitor = createMonitor();
      final subId = monitor.subscribeJobUpdates('test-job-123');
      expect(subId, isA<String>());
      expect(subId.length, equals(36));
    });

    test('test_multiple_subscriptions_same_job', () {
      final monitor = createMonitor();
      final subId1 = monitor.subscribeJobUpdates('test-job-123');
      final subId2 = monitor.subscribeJobUpdates('test-job-123');
      expect(subId1, isNot(equals(subId2)));
    });

    test('test_unsubscribe_with_subscription_id', () {
      final monitor = createMonitor();
      final subId = monitor.subscribeJobUpdates('test-job-123');
      monitor.unsubscribe(subId);
      // We can't check internal _jobSubscriptions easily, but we can verify no crash
    });

    test('test_unsubscribe_keeps_topic_if_other_subs_exist', () {
      final monitor = createMonitor();
      final subId1 = monitor.subscribeJobUpdates('test-job-123');
      final subId2 = monitor.subscribeJobUpdates('test-job-123');

      monitor.unsubscribe(subId1);
      // Verify no MQTT unsubscribe call
      verifyNever(() => mockClient.unsubscribe(any()));

      monitor.unsubscribe(subId2);
      verifyNever(() => mockClient.unsubscribe(any()));
    });

    test('test_two_callback_system', () async {
      final monitor = createMonitor();
      await monitor.connect();

      const jobId = 'test-job-123';
      final progressCalls = <JobResponse>[];
      final completeCalls = <JobResponse>[];

      monitor.subscribeJobUpdates(
        jobId,
        onProgress: progressCalls.add,
        onComplete: completeCalls.add,
      );

      final processingPayload = jsonEncode({
        'job_id': jobId,
        'event_type': 'processing',
        'progress': 50,
        'timestamp': 1234567890,
      });

      final processingMsg = MqttPublishMessage()
        ..payload = (MqttPublishPayload()
          ..message = (Uint8Buffer()..addAll(utf8.encode(processingPayload))));

      updatesController.add([
        MqttReceivedMessage<MqttMessage>('inference/events', processingMsg),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(progressCalls.length, equals(1));
      expect(completeCalls.length, equals(0));

      final completedPayload = jsonEncode({
        'job_id': jobId,
        'event_type': 'completed',
        'progress': 100,
        'timestamp': 1234567891,
      });

      final completedMsg = MqttPublishMessage()
        ..payload = (MqttPublishPayload()
          ..message = (Uint8Buffer()..addAll(utf8.encode(completedPayload))));

      updatesController.add([
        MqttReceivedMessage<MqttMessage>('inference/events', completedMsg),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(progressCalls.length, equals(2));
      expect(completeCalls.length, equals(1));
    });

    test('test_worker_capability_tracking', () async {
      final monitor = createMonitor();
      await monitor.connect();

      const workerId = 'worker-123';
      final capabilityPayload = jsonEncode({
        'worker_id': workerId,
        'capabilities': ['clip_embedding', 'dino_embedding'],
        'idle_count': 1,
        'timestamp': 1234567890,
      });

      const topic = 'inference/workers/$workerId';
      final msg = MqttPublishMessage()
        ..payload = (MqttPublishPayload()
          ..message = (Uint8Buffer()..addAll(utf8.encode(capabilityPayload))));

      updatesController.add([MqttReceivedMessage<MqttMessage>(topic, msg)]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final workers = monitor.getWorkerCapabilities();
      expect(workers, contains(workerId));
      expect(workers[workerId]!.capabilities, contains('clip_embedding'));
    });

    test('test_worker_disconnect_lwt', () async {
      final monitor = createMonitor();
      await monitor.connect();

      const workerId = 'worker-123';
      const topic = 'inference/workers/$workerId';
      final payload = jsonEncode({
        'worker_id': workerId,
        'capabilities': ['test'],
        'idle_count': 1,
        'timestamp': 1234567890,
      });
      final msg = MqttPublishMessage()
        ..payload = (MqttPublishPayload()
          ..message = (Uint8Buffer()..addAll(utf8.encode(payload))));
      updatesController.add([MqttReceivedMessage<MqttMessage>(topic, msg)]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final emptyMsg = MqttPublishMessage()
        ..payload = (MqttPublishPayload()..message = Uint8Buffer());
      updatesController.add([
        MqttReceivedMessage<MqttMessage>(topic, emptyMsg),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(monitor.getWorkerCapabilities(), isNot(contains(workerId)));
    });

    test('test_subscribe_worker_updates', () async {
      final monitor = createMonitor();
      await monitor.connect();

      const workerId = 'worker-123';
      final callbackCalls = <String>[];
      monitor.subscribeWorkerUpdates((wid, cap) => callbackCalls.add(wid));

      final capabilityPayload = jsonEncode({
        'worker_id': workerId,
        'capabilities': ['test'],
        'idle_count': 1,
        'timestamp': 1234567890,
      });

      const topic = 'inference/workers/$workerId';
      final msg = MqttPublishMessage()
        ..payload = (MqttPublishPayload()
          ..message = (Uint8Buffer()..addAll(utf8.encode(capabilityPayload))));

      updatesController.add([MqttReceivedMessage<MqttMessage>(topic, msg)]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(callbackCalls, contains(workerId));
    });

    test('test_wait_for_capability_success', () async {
      final monitor = createMonitor();
      await monitor.connect();

      Future<void>.delayed(const Duration(milliseconds: 50), () {
        const workerId = 'worker-123';
        const topic = 'inference/workers/$workerId';
        final payload = jsonEncode({
          'worker_id': workerId,
          'capabilities': ['clip_embedding'],
          'idle_count': 1,
          'timestamp': 1234567890,
        });
        final msg = MqttPublishMessage()
          ..payload = (MqttPublishPayload()
            ..message = (Uint8Buffer()..addAll(utf8.encode(payload))));
        updatesController.add([MqttReceivedMessage<MqttMessage>(topic, msg)]);
      });

      final result = await monitor.waitForCapability(
        'clip_embedding',
        timeout: const Duration(seconds: 1),
      );
      expect(result, isTrue);
    });

    test('test_wait_for_capability_timeout', () async {
      final monitor = createMonitor();
      await monitor.connect();

      expect(
        () => monitor.waitForCapability(
          'clip_embedding',
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<WorkerUnavailableError>()),
      );
    });

    test('test_close', () async {
      final monitor = createMonitor();
      await monitor.connect();
      monitor.close();

      verify(() => mockClient.disconnect()).called(1);
      expect(monitor.isConnected, isFalse);
    });

    test('test_invalid_json_message_handling', () async {
      final monitor = createMonitor();
      await monitor.connect();

      final msg = MqttPublishMessage()
        ..payload = (MqttPublishPayload()
          ..message = (Uint8Buffer()..addAll(utf8.encode('invalid json {{'))));

      // Should not throw
      updatesController.add([
        MqttReceivedMessage<MqttMessage>('inference/events', msg),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    test('test_invalid_dict_message_handling', () async {
      final monitor = createMonitor();
      await monitor.connect();

      final msg = MqttPublishMessage()
        ..payload = (MqttPublishPayload()
          ..message = (Uint8Buffer()..addAll(utf8.encode('"not a dict"'))));

      // Should not throw
      updatesController.add([
        MqttReceivedMessage<MqttMessage>('inference/events', msg),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
  });
}
