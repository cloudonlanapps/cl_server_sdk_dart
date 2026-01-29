import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:uuid/uuid.dart';

import 'exceptions.dart';
import 'models/models.dart';

/// Payload for job events.
class JobEventPayload {
  JobEventPayload({
    required this.jobId,
    required this.eventType,
    required this.timestamp,
    this.progress,
  });

  factory JobEventPayload.fromMap(Map<String, dynamic> map) {
    return JobEventPayload(
      jobId: map['job_id'] as String,
      eventType: map['event_type'] as String,
      timestamp: map['timestamp'] as int,
      progress: map['progress'] as num?,
    );
  }
  final String jobId;
  final String eventType;
  final int timestamp;
  final num? progress;
}

/// Payload for entity status broadcast.
class EntityStatusPayload {
  EntityStatusPayload({
    required this.entityId,
    required this.status,
    required this.timestamp,
    this.faceDetection,
    this.faceCount,
    this.clipEmbedding,
    this.dinoEmbedding,
    this.faceEmbeddings,
  });

  factory EntityStatusPayload.fromMap(Map<String, dynamic> map) {
    return EntityStatusPayload(
      entityId: map['entity_id'] as int,
      status: map['status'] as String,
      timestamp: map['timestamp'] as int,
      faceDetection: map['face_detection'] as String?,
      faceCount: map['face_count'] as int?,
      clipEmbedding: map['clip_embedding'] as String?,
      dinoEmbedding: map['dino_embedding'] as String?,
      faceEmbeddings: map['face_embeddings'] != null
          ? List<String>.from(map['face_embeddings'] as List)
          : null,
    );
  }
  final int entityId;
  final String status;
  final int timestamp;
  final String? faceDetection;
  final int? faceCount;
  final String? clipEmbedding;
  final String? dinoEmbedding;
  final List<String>? faceEmbeddings;
}

/// MQTT monitor for job status and worker capabilities.
class MQTTJobMonitor {
  MQTTJobMonitor({
    this.broker = 'localhost',
    this.port = 1883,
    this.keepAlive = 60,
    MqttServerClient Function(String, String)? clientFactory,
  }) : _clientFactory = clientFactory;
  final String broker;
  final int port;
  final int keepAlive;

  MqttServerClient? _client;
  bool _connected = false;
  static const _uuid = Uuid();

  // Job subscriptions: sub_id -> callback
  final Map<String, _JobSubscription> _jobSubscriptions = {};

  // Worker capabilities
  final Map<String, WorkerCapability> _workers = {};
  final List<void Function(String, WorkerCapability?)> _workerCallbacks = [];

  // Entity subscriptions
  final Map<String, _EntitySubscription> _entitySubscriptions = {};

  final MqttServerClient Function(String broker, String clientId)?
  _clientFactory;

  bool get isConnected => _connected;

  Future<void>? _connectFuture;

  Future<void> connect() async {
    if (_connected) return;
    if (_connectFuture != null) return _connectFuture;

    _connectFuture = _doConnect();
    try {
      await _connectFuture;
    } finally {
      _connectFuture = null;
    }
  }

  Future<void> _doConnect() async {
    final clientIdentifier = 'dart_client_${_uuid.v4()}';
    _client = _clientFactory != null
        ? _clientFactory(broker, clientIdentifier)
        : MqttServerClient(broker, clientIdentifier);
    _client!.port = port;
    _client!.keepAlivePeriod = keepAlive;
    _client!.autoReconnect = true;
    _client!.logging(on: false);

    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean() // Non persistent session
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
    } on Object catch (e) {
      _disconnect();
      throw Exception('MQTT connection failed: $e');
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      _connected = true;
      _setupSubscriptions();
      _client!.updates!.listen(_onMessage);
    } else {
      _disconnect();
      throw Exception('MQTT connection failed - invalid status');
    }
  }

  void _disconnect() {
    _client?.disconnect();
    _connected = false;
  }

  void close() {
    _disconnect();
  }

  void _onConnected() {
    _connected = true;
  }

  void _onDisconnected() {
    _connected = false;
  }

  void _onSubscribed(String topic) {}

  void _setupSubscriptions() {
    // Worker capabilities
    const capabilityTopic = 'inference/workers/+';
    _client!.subscribe(capabilityTopic, MqttQos.atLeastOnce);

    // Job events
    const eventsTopic = 'inference/events';
    _client!.subscribe(eventsTopic, MqttQos.atLeastOnce);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> c) {
    if (c.isEmpty) return;
    final recvMsg = c[0].payload as MqttPublishMessage;
    final topic = c[0].topic;
    final pt = MqttPublishPayload.bytesToStringAsString(
      recvMsg.payload.message,
    );

    //print('MQTT RECV [$topic]');

    try {
      if (topic.startsWith('inference/workers/')) {
        _handleWorkerCapability(topic, pt);
      } else if (topic == 'inference/events') {
        _handleJobEvent(pt);
      } else if (topic.contains('entity_item_status')) {
        _handleEntityStatus(topic, pt);
      }
    } on Object catch (e) {
      // ignore: avoid_print
      print('Error handling MQTT message on $topic: $e');
    }
  }

  void _handleWorkerCapability(String topic, String payload) {
    final workerId = topic.split('/').last;

    if (payload.isEmpty) {
      // LWT or disconnect
      if (_workers.containsKey(workerId)) {
        _workers.remove(workerId);
        for (final cb in _workerCallbacks) {
          cb(workerId, null);
        }
      }
      return;
    }

    try {
      final jsonMap = json.decode(payload) as Map<String, dynamic>;
      final capability = WorkerCapability.fromMap(jsonMap);
      _workers[workerId] = capability;
      for (final cb in _workerCallbacks) {
        cb(workerId, capability);
      }
    } on Object catch (_) {
      // Ignore invalid
    }
  }

  void _handleJobEvent(String payload) {
    try {
      final jsonMap = json.decode(payload) as Map<String, dynamic>;
      final event = JobEventPayload.fromMap(jsonMap);

      for (final sub in _jobSubscriptions.values) {
        if (sub.jobId != event.jobId) continue;

        final job = JobResponse(
          jobId: event.jobId,
          taskType: sub.taskType,
          status: event.eventType,
          progress: event.progress?.toInt() ?? 0,
          createdAt: event.timestamp,
        );

        sub.onProgress?.call(job);

        if (event.eventType == 'completed' ||
            event.eventType == 'failed' ||
            event.eventType == 'error') {
          sub.onComplete?.call(job);
        }
      }
    } on Object catch (_) {
      // Ignore
    }
  }

  void _handleEntityStatus(String topic, String payload) {
    try {
      final jsonMap = json.decode(payload) as Map<String, dynamic>;
      final status = EntityStatusPayload.fromMap(jsonMap);

      for (final sub in _entitySubscriptions.values) {
        if (sub.entityId != status.entityId) continue;
        sub.onUpdate(status);
      }
    } on Object catch (_) {
      // Ignore
    }
  }

  // ===================================
  // Public API
  // ===================================

  Map<String, WorkerCapability> getWorkerCapabilities() =>
      Map.unmodifiable(_workers);

  Future<bool> waitForCapability(
    String taskType, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final completer = Completer<bool>();
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          WorkerUnavailableError(
            taskType,
            _workers.map((k, v) => MapEntry(k, v.idleCount)),
          ),
        );
      }
    });

    void check() {
      for (final w in _workers.values) {
        if (w.capabilities.contains(taskType) && w.idleCount > 0) {
          if (!completer.isCompleted) completer.complete(true);
          return;
        }
      }
    }

    check();
    if (completer.isCompleted) {
      timer.cancel();
      return true;
    }

    subscribeWorkerUpdates((id, cap) {
      if (!completer.isCompleted) check();
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      // Cleanup listener if implemented removal mechanism
    }
  }

  String subscribeJobUpdates(
    String jobId, {
    void Function(JobResponse)? onProgress,
    void Function(JobResponse)? onComplete,
    String taskType = 'unknown',
  }) {
    final id = _uuid.v4();
    _jobSubscriptions[id] = _JobSubscription(
      jobId,
      onProgress,
      onComplete,
      taskType,
    );
    return id;
  }

  void unsubscribe(String subscriptionId) {
    _jobSubscriptions.remove(subscriptionId);
  }

  void subscribeWorkerUpdates(
    void Function(String, WorkerCapability?) callback,
  ) {
    _workerCallbacks.add(callback);
  }

  String subscribeEntityStatus(
    int entityId,
    int storePort,
    void Function(EntityStatusPayload) onUpdate,
  ) {
    final id = _uuid.v4();
    _entitySubscriptions[id] = _EntitySubscription(entityId, onUpdate);

    // Subscribe to topic if connected
    final topic = 'mInsight/$storePort/entity_item_status/$entityId';
    // ignore: avoid_print
    print('Subscribing to MQTT topic: $topic (connected: $_connected)');
    if (_connected) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }

    return id;
  }

  void unsubscribeEntityStatus(String subscriptionId) {
    // Note: We don't unsubscribe from MQTT topic because other subs might need it,
    // and maintaining ref counts per topic adds complexity for this port.
    _entitySubscriptions.remove(subscriptionId);
  }
}

class _JobSubscription {
  _JobSubscription(this.jobId, this.onProgress, this.onComplete, this.taskType);
  final String jobId;
  final void Function(JobResponse)? onProgress;
  final void Function(JobResponse)? onComplete;
  final String taskType;
}

class _EntitySubscription {
  _EntitySubscription(this.entityId, this.onUpdate);
  final int entityId;
  final void Function(EntityStatusPayload) onUpdate;
}

// Registry
final Map<String, _MonitorRef> _registry = {};

class _MonitorRef {
  _MonitorRef(this.monitor, this.refCount);
  final MQTTJobMonitor monitor;
  int refCount;
}

MQTTJobMonitor getMqttMonitor({String broker = 'localhost', int port = 1883}) {
  final key = '$broker:$port';
  if (_registry.containsKey(key)) {
    final ref = _registry[key]!;
    ref.refCount++;
    return ref.monitor;
  }

  final monitor = MQTTJobMonitor(broker: broker, port: port);
  // We assume caller will await connect()
  _registry[key] = _MonitorRef(monitor, 1);
  return monitor;
}

void releaseMqttMonitor(MQTTJobMonitor monitor) {
  final key = '${monitor.broker}:${monitor.port}';
  if (_registry.containsKey(key)) {
    final ref = _registry[key]!;
    ref.refCount--;
    if (ref.refCount <= 0) {
      monitor.close();
      _registry.remove(key);
    }
  } else {
    monitor.close();
  }
}
