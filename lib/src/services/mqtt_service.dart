import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../core/exceptions.dart';
import '../core/models/compute_models.dart';

/// MQTT service for real-time job status monitoring
///
/// Provides lightweight JobStatus tracking (NOT full Job objects).
/// Clients must call ComputeService.getJob() to fetch full Job with results.
///
/// Architecture:
/// - Subscribes to MQTT topic for job events
/// - Parses messages to lightweight JobStatus objects
/// - Maintains status cache for query
/// - Provides broadcast stream for real-time updates
/// - NO dependency on ComputeService
///
/// Example workflow:
/// ```dart
/// // 1. Create and connect MQTT service
/// final mqttService = MqttService(
///   brokerUrl: 'localhost',
///   brokerPort: 1883,
///   topic: 'inference/events',
/// );
/// await mqttService.connect();
///
/// // 2. Create job via ComputeService
/// final response = await computeService.createJob(...);
///
/// // 3. Wait for MQTT completion (returns jobId only)
/// final completedJobId = await mqttService.waitForCompletion(
///   jobId: response.jobId,
///   timeout: Duration(minutes: 2),
/// );
///
/// // 4. Fetch full Job from API
/// final job = await computeService.getJob(completedJobId);
///
/// // 5. Access output/error
/// print(job.taskOutput);
/// print(job.errorMessage);
/// ```
class MqttService {
  /// Create MQTT service
  ///
  /// [brokerUrl] - MQTT broker hostname (e.g., 'localhost')
  /// [brokerPort] - MQTT broker port (default: 1883)
  /// [topic] - Topic to subscribe to (default: 'inference/events')
  MqttService({
    required this.brokerUrl,
    this.brokerPort = 1883,
    this.topic = 'inference/events',
  });

  final String brokerUrl;
  final int brokerPort;
  final String topic;

  MqttServerClient? _client;
  StreamController<JobStatus>? _statusStreamController;
  final Map<String, JobStatus> _statusCache = {};
  bool _isConnected = false;

  /// Check if connected to MQTT broker
  bool get isConnected => _isConnected;

  /// Stream of job status updates (broadcast)
  ///
  /// Emits JobStatus whenever a job status update is received from MQTT.
  /// Multiple listeners can subscribe to this stream.
  Stream<JobStatus> get statusStream {
    _statusStreamController ??= StreamController<JobStatus>.broadcast();
    return _statusStreamController!.stream;
  }

  /// Connect to MQTT broker
  ///
  /// Establishes connection and subscribes to the configured topic.
  ///
  /// Throws [MqttConnectionException] if connection fails.
  Future<void> connect() async {
    if (_isConnected) {
      return; // Already connected
    }

    try {
      // Create client with unique ID
      final clientId = 'dart_mqtt_${DateTime.now().millisecondsSinceEpoch}';
      _client = MqttServerClient(brokerUrl, clientId);
      _client!.port = brokerPort;
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 60;
      _client!.autoReconnect = true;

      // Connect
      await _client!.connect();

      if (_client!.connectionStatus?.state != MqttConnectionState.connected) {
        throw MqttConnectionException(
          'Failed to connect to MQTT broker at $brokerUrl:$brokerPort',
        );
      }

      _isConnected = true;

      // Subscribe to topic with QoS 1 (at least once)
      _client!.subscribe(topic, MqttQos.atLeastOnce);

      // Setup message handler
      _client!.updates!.listen(
        _handleMessage,
        onError: (Object error) {
          // Log error but don't crash
          // ignore: avoid_print
          print('MQTT error: $error');
        },
      );
    } catch (e) {
      _isConnected = false;
      throw MqttConnectionException(
        'MQTT connection failed: $e',
      );
    }
  }

  /// Disconnect from MQTT broker
  ///
  /// Closes connection and cleans up resources.
  Future<void> disconnect() async {
    if (!_isConnected || _client == null) {
      return;
    }

    _client!.disconnect();
    _isConnected = false;
    await _statusStreamController?.close();
    _statusStreamController = null;
    _statusCache.clear();
  }

  /// Wait for job completion
  ///
  /// Returns jobId when job reaches 'completed' or 'failed' status.
  /// Does NOT return full Job object - client must fetch via ComputeService.
  ///
  /// [jobId] - Job ID to wait for
  /// [timeout] - Maximum time to wait (default: 5 minutes)
  ///
  /// Returns the jobId when finished
  ///
  /// Throws [TimeoutException] if timeout is reached
  Future<String> waitForCompletion({
    required String jobId,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final completer = Completer<String>();
    late StreamSubscription<JobStatus> subscription;

    subscription = statusStream.listen(
      (status) {
        if (status.jobId == jobId && status.isFinished) {
          if (!completer.isCompleted) {
            completer.complete(jobId);
            subscription.cancel();
          }
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
          subscription.cancel();
        }
      },
    );

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        subscription.cancel();
        throw TimeoutException(
          'Timeout waiting for job completion: $jobId',
          timeout,
        );
      },
    );
  }

  /// Get cached status for a job
  ///
  /// Returns the most recent JobStatus for the given jobId, or null if
  /// not found.
  ///
  /// [jobId] - Job ID to query
  ///
  /// Returns cached JobStatus or null
  JobStatus? getStatus(String jobId) {
    return _statusCache[jobId];
  }

  /// Handle incoming MQTT messages
  ///
  /// Parses messages to JobStatus and broadcasts to listeners.
  void _handleMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final recMessage = message.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        recMessage.payload.message,
      );

      final status = _parseMessageToStatus(payload);
      if (status != null) {
        // Update cache
        _statusCache[status.jobId] = status;

        // Broadcast to listeners
        _statusStreamController?.add(status);
      }
    }
  }

  /// Parse MQTT message payload to JobStatus
  ///
  /// Returns JobStatus if parsing succeeds, null otherwise.
  /// Handles malformed JSON gracefully (logs but doesn't crash).
  JobStatus? _parseMessageToStatus(String payload) {
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      return JobStatus.fromMqttMessage(json);
    } catch (e) {
      // Log error but don't crash - malformed messages are ignored
      // ignore: avoid_print
      print('Failed to parse MQTT message: $e');
      return null;
    }
  }
}
