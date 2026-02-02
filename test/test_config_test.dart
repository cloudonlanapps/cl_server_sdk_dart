import 'package:cl_server_dart_client/src/config.dart';
import 'package:test/test.dart';

void main() {
  group('ComputeClientConfig', () {
    test('test_default_values', () {
      expect(ComputeClientConfig.defaultHost, equals('localhost'));
      expect(ComputeClientConfig.defaultPort, equals(8012));
      expect(
        ComputeClientConfig.defaultBaseUrl,
        equals('http://localhost:8012'),
      );
      expect(ComputeClientConfig.defaultTimeout.inSeconds, equals(30));
    });

    test('test_mqtt_config', () {
      expect(
        ComputeClientConfig.defaultMqttUrl,
        equals('mqtt://localhost:1883'),
      );
      expect(
        ComputeClientConfig.mqttCapabilityTopicPrefix,
        equals('inference/workers'),
      );
      expect(
        ComputeClientConfig.mqttJobEventsTopic,
        equals('inference/events'),
      );
    });

    test('test_core_endpoints', () {
      expect(ComputeClientConfig.endpointGetJob('id'), equals('/jobs/id'));
      expect(ComputeClientConfig.endpointDeleteJob('id'), equals('/jobs/id'));
      expect(
        ComputeClientConfig.endpointGetJobFile('id', 'path'),
        equals('/jobs/id/files/path'),
      );
      expect(ComputeClientConfig.endpointCapabilities, equals('/capabilities'));
    });

    test('test_plugin_endpoints', () {
      const plugins = ComputeClientConfig.pluginEndpoints;
      final expectedPlugins = [
        'clip_embedding',
        'dino_embedding',
        'exif',
        'face_detection',
        'face_embedding',
        'hash',
        'hls_streaming',
        'image_conversion',
        'media_thumbnail',
      ];

      for (final plugin in expectedPlugins) {
        expect(plugins.containsKey(plugin), isTrue);
        expect(plugins[plugin]!.startsWith('/jobs/'), isTrue);
      }
    });

    test('test_get_plugin_endpoint_success', () {
      expect(
        ComputeClientConfig.getPluginEndpoint('clip_embedding'),
        equals('/jobs/clip_embedding'),
      );
      expect(
        ComputeClientConfig.getPluginEndpoint('media_thumbnail'),
        equals('/jobs/media_thumbnail'),
      );
    });

    test('test_get_plugin_endpoint_invalid', () {
      try {
        ComputeClientConfig.getPluginEndpoint('unknown_plugin');
        fail('Should have thrown ArgumentError');
      } on Object catch (e) {
        expect(e, isA<ArgumentError>());
        final msg = e.toString();
        expect(msg.contains('Unknown task type'), isTrue);
        expect(msg.contains('unknown_plugin'), isTrue);
        expect(msg.contains('Available:'), isTrue);
      }
    });

    test('test_job_monitoring_config', () {
      expect(
        ComputeClientConfig.defaultPollInterval.inMilliseconds,
        equals(1000),
      );
      expect(ComputeClientConfig.maxPollBackoff.inSeconds, equals(10));
      expect(ComputeClientConfig.pollBackoffMultiplier, equals(1.5));
    });

    test('test_worker_validation_config', () {
      expect(ComputeClientConfig.workerWaitTimeout.inSeconds, equals(30));
      expect(
        ComputeClientConfig.workerCapabilityCheckInterval.inMilliseconds,
        equals(1000),
      );
    });
  });
}
