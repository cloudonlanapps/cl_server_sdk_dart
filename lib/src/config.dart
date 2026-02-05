/// Configuration for compute client.
class ComputeClientConfig {
  // Server Connection
  static const Duration defaultTimeout = Duration(seconds: 60);

  // MQTT Configuration
  static const String mqttCapabilityTopicPrefix = 'inference/workers';
  static const String mqttJobEventsTopic = 'inference/events';

  // Core API Endpoints
  static String endpointGetJob(String jobId) => '/jobs/$jobId';
  static String endpointDeleteJob(String jobId) => '/jobs/$jobId';
  static String endpointGetJobFile(String jobId, String filePath) =>
      '/jobs/$jobId/files/$filePath';
  static const String endpointCapabilities = '/capabilities';

  // Plugin Endpoints
  static const Map<String, String> pluginEndpoints = {
    'clip_embedding': '/jobs/clip_embedding',
    'dino_embedding': '/jobs/dino_embedding',
    'exif': '/jobs/exif',
    'face_detection': '/jobs/face_detection',
    'face_embedding': '/jobs/face_embedding',
    'hash': '/jobs/hash',
    'hls_streaming': '/jobs/hls_streaming',
    'image_conversion': '/jobs/image_conversion',
    'media_thumbnail': '/jobs/media_thumbnail',
  };

  // Job Monitoring Configuration
  static const Duration defaultPollInterval = Duration(milliseconds: 1000);
  static const Duration maxPollBackoff = Duration(seconds: 10);
  static const double pollBackoffMultiplier = 1.5;

  // Worker Validation
  static const Duration workerWaitTimeout = Duration(seconds: 30);
  static const Duration workerCapabilityCheckInterval = Duration(
    milliseconds: 1000,
  );

  static String getPluginEndpoint(String taskType) {
    if (!pluginEndpoints.containsKey(taskType)) {
      throw ArgumentError(
        'Unknown task type: $taskType. '
        'Available: ${pluginEndpoints.keys.toList()}',
      );
    }
    return pluginEndpoints[taskType]!;
  }
}
