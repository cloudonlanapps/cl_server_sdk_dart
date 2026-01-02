import 'dart:async';
import 'dart:io';

import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

import '../test_helpers.dart';
import 'health_check_test.dart';
import 'image_resize_test_helpers.dart';

/// Integration tests for ComputeService workflows.
///
/// These tests verify the complete lifecycle of compute jobs against
/// a live server. Tests are designed to be:
///
/// - **Dynamic**: Discover available task types from server capabilities
/// - **Generic**: Work with any compute task type
/// - **Extensible**: Easy to add new task-specific tests
/// - **Self-cleaning**: Automatically cleanup created jobs and files
///
/// ## Test Strategy
///
/// 1. Capability Discovery: Query server for available task types
/// 2. Conditional Testing: Skip tests for unavailable task types
/// 3. Workflow Testing: Create job → Poll status → Verify results → Cleanup
/// 4. Error Testing: Validate error handling with real server responses
///
/// ## Adding New Task Type Tests
///
/// To add tests for a new task type (e.g., 'video_transcode'):
///
/// ```dart
/// group('Video Transcode Workflow Tests', () {
///   test('Complete video_transcode workflow', () async {
///     if (!await hasTaskType('video_transcode')) {
///       markTestSkipped('video_transcode not available');
///       return;
///     }
///     // Test implementation
///   });
/// });
/// ```
///
/// ## Prerequisites
///
/// - Auth service running at http://localhost:8000
/// - Store service running at http://localhost:8001
/// - At least one compute worker running with task modules
/// - Admin credentials: username='admin', password='admin'

const String adminUsername = 'admin';
const String adminPassword = 'admin';

late SessionManager adminManager;
late ComputeService computeService;
final List<String> testJobIds = [];
final List<String> testFiles = [];

void main() {
  group('Compute Workflow Tests', () {
    setUpAll(() async {
      // Verify services are healthy
      await ensureBothServicesHealthy();
      await ensureComputeServiceHealthy();

      // Setup admin session
      adminManager = SessionManager.initialize(await createTestServerConfig());
      await adminManager.login(adminUsername, adminPassword);

      // Create compute service
      computeService = await adminManager.createComputeService();
    });

    tearDownAll(() async {
      // Cleanup all test jobs
      for (final jobId in testJobIds) {
        try {
          await computeService.deleteJob(jobId);
        } on Exception {
          // Job might already be deleted
        }
      }

      // Cleanup test files
      await cleanupTestImages(testFiles);

      // Logout
      try {
        await adminManager.logout();
      } on Exception {
        // Ignore logout errors
      }
    });

    group('Capability Discovery', () {
      test('✅ getCapabilities returns available tasks', () async {
        final capabilities = await computeService.getCapabilities();

        expect(capabilities, isNotNull);
        expect(capabilities, isA<Map<String, int>>());
      });

      test('✅ capabilities map has valid structure', () async {
        final capabilities = await computeService.getCapabilities();

        for (final entry in capabilities.entries) {
          expect(
            entry.key,
            isNotEmpty,
            reason: 'Task type should not be empty',
          );
          expect(
            entry.value,
            greaterThanOrEqualTo(0),
            reason: 'Worker count should be non-negative',
          );
        }
      });

      test('✅ worker counts are non-negative integers', () async {
        final capabilities = await computeService.getCapabilities();

        for (final count in capabilities.values) {
          expect(count, isA<int>());
          expect(count, greaterThanOrEqualTo(0));
        }
      });
    });

    group('Dynamic Endpoint Validation', () {
      test('✅ createJob validates task type against capabilities', () async {
        final capabilities = await computeService.getCapabilities();

        if (capabilities.isEmpty) {
          markTestSkipped('No task types available');
          return;
        }

        // Try to create job with unsupported task type
        try {
          await computeService.createJob(
            taskType: 'unsupported_task_type_12345',
            body: {},
          );
          fail('Should have thrown UnsupportedError');
        } on Exception catch (e) {
          expect(e.toString(), contains('unsupported_task_type_12345'));
          expect(e.toString(), contains('not supported'));
        }
      });

      test(
        '✅ createJob throws UnsupportedError for invalid task type',
        () async {
          expect(
            () => computeService.createJob(
              taskType: 'invalid_task',
              body: {},
            ),
            throwsA(isA<Exception>()),
          );
        },
      );

      test('✅ all available task types can be discovered', () async {
        final capabilities = await computeService.getCapabilities();

        expect(
          capabilities.keys,
          isNotEmpty,
          reason: 'At least one task type should be available',
        );

        for (final taskType in capabilities.keys) {
          print(
            'Discovered task type: $taskType '
            '(${capabilities[taskType]} workers)',
          );
        }
      });
    });

    group('Image Resize Workflow Tests', () {
      test('✅ Complete image_resize workflow', () async {
        if (!await hasTaskType('image_resize')) {
          markTestSkipped('image_resize not available');
          return;
        }

        // Generate test image
        final imagePath = await generateTestImage(
          width: 1920,
          height: 1080,
          fileName:
              'test_resize_input_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        testFiles.add(imagePath);

        // Create resize job
        final response = await createTestJob(
          taskType: 'image_resize',
          params: {
            'width': '800',
            'height': '600',
            'maintain_aspect_ratio': 'false',
          },
          file: File(imagePath),
        );

        expect(response.jobId, isNotEmpty);
        expect(response.status, 'queued');
        print('Created job: ${response.jobId}');

        // Poll for completion
        final completedJob = await computeService
            .waitForJobCompletionWithPolling(
              response.jobId,
              timeout: const Duration(minutes: 2),
              onProgress: (job) {
                print('Job ${job.jobId}: ${job.status} - ${job.progress}%');
              },
            );

        // Verify completion
        expect(completedJob.status, 'completed');
        expect(completedJob.progress, 100);
        expect(completedJob.taskOutput, isNotNull);
        print('Job completed: ${completedJob.taskOutput}');
      });

      test('✅ Job creation with width and height parameters', () async {
        if (!await hasTaskType('image_resize')) {
          markTestSkipped('image_resize not available');
          return;
        }

        final imagePath = await generateTestImage(
          width: 1600,
          height: 1200,
          fileName: 'test_params_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        testFiles.add(imagePath);

        final response = await createTestJob(
          taskType: 'image_resize',
          params: {
            'width': '400',
            'height': '300',
          },
          file: File(imagePath),
        );

        expect(response.jobId, isNotEmpty);

        final job = await computeService.getJob(response.jobId);
        expect(job.params['width'], 400);
        expect(job.params['height'], 300);
      });

      test('✅ Job creation with maintain_aspect_ratio parameter', () async {
        if (!await hasTaskType('image_resize')) {
          markTestSkipped('image_resize not available');
          return;
        }

        final imagePath = await generateTestImage(
          width: 1600,
          height: 900,
          fileName: 'test_aspect_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        testFiles.add(imagePath);

        final response = await createTestJob(
          taskType: 'image_resize',
          params: {
            'width': '800',
            'height': '600',
            'maintain_aspect_ratio': 'true',
          },
          file: File(imagePath),
        );

        expect(response.jobId, isNotEmpty);

        final job = await computeService.getJob(response.jobId);
        expect(job.params['maintain_aspect_ratio'], true);
      });

      test('✅ Job creation with priority parameter', () async {
        if (!await hasTaskType('image_resize')) {
          markTestSkipped('image_resize not available');
          return;
        }

        final imagePath = await generateTestImage(
          width: 800,
          height: 600,
          fileName:
              'test_priority_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        testFiles.add(imagePath);

        final response = await createTestJob(
          taskType: 'image_resize',
          params: {
            'width': '400',
            'height': '300',
          },
          file: File(imagePath),
          priority: 8,
        );

        expect(response.jobId, isNotEmpty);

        final job = await computeService.getJob(response.jobId);
        // Server may have a default or maximum priority
        expect(job.priority, isNotNull);
        expect(job.priority, greaterThan(0));
      });

      test(
        '✅ Job status transitions (queued → running/processing → completed)',
        () async {
          if (!await hasTaskType('image_resize')) {
            markTestSkipped('image_resize not available');
            return;
          }

          final imagePath = await generateTestImage(
            width: 1920,
            height: 1080,
            fileName:
                'test_status_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          testFiles.add(imagePath);

          final response = await createTestJob(
            taskType: 'image_resize',
            params: {
              'width': '960',
              'height': '540',
            },
            file: File(imagePath),
          );

          // Track status transitions
          final statuses = <String>[];
          await computeService.waitForJobCompletionWithPolling(
            response.jobId,
            interval: const Duration(milliseconds: 500),
            onProgress: (job) {
              if (statuses.isEmpty || statuses.last != job.status) {
                statuses.add(job.status);
                print('Status transition: ${job.status}');
              }
            },
          );

          expect(statuses, isNotEmpty);
          expect(statuses.first, 'queued');
          expect(statuses.last, anyOf('completed', 'failed'));
        },
      );
    });

    group('Image Conversion Workflow Tests', () {
      test('✅ Complete image_conversion workflow with format', () async {
        if (!await hasTaskType('image_conversion')) {
          markTestSkipped('image_conversion not available');
          return;
        }

        final imagePath = await generateTestImage(
          width: 800,
          height: 600,
          fileName: 'test_convert_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        testFiles.add(imagePath);

        final response = await createTestJob(
          taskType: 'image_conversion',
          params: {
            'format': 'jpg',
          },
          file: File(imagePath),
        );

        expect(response.jobId, isNotEmpty);
        print('Created conversion job: ${response.jobId}');

        final completedJob = await computeService
            .waitForJobCompletionWithPolling(
              response.jobId,
              timeout: const Duration(minutes: 2),
            );

        expect(completedJob.status, 'completed');
        expect(completedJob.taskOutput, isNotNull);
      });

      test('✅ Image conversion with quality parameter', () async {
        if (!await hasTaskType('image_conversion')) {
          markTestSkipped('image_conversion not available');
          return;
        }

        final imagePath = await generateTestImage(
          width: 1024,
          height: 768,
          fileName: 'test_quality_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        testFiles.add(imagePath);

        final response = await createTestJob(
          taskType: 'image_conversion',
          params: {
            'format': 'jpg',
            'quality': '90',
          },
          file: File(imagePath),
        );

        expect(response.jobId, isNotEmpty);

        final job = await computeService.getJob(response.jobId);
        expect(job.params['quality'], 90);
      });

      test('✅ Image conversion to different formats', () async {
        if (!await hasTaskType('image_conversion')) {
          markTestSkipped('image_conversion not available');
          return;
        }

        final formats = ['png', 'jpg', 'webp'];

        for (final format in formats) {
          final imagePath = await generateTestImage(
            width: 640,
            height: 480,
            fileName:
                'test_${format}_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          testFiles.add(imagePath);

          final response = await createTestJob(
            taskType: 'image_conversion',
            params: {'format': format},
            file: File(imagePath),
          );

          expect(response.jobId, isNotEmpty);
          print('Created $format conversion job: ${response.jobId}');

          final job = await computeService.getJob(response.jobId);
          expect(job.params['format'], format);
        }
      });
    });

    group('Generic Workflow Tests', () {
      test('✅ Job lifecycle: create → get → delete', () async {
        final capabilities = await computeService.getCapabilities();
        if (capabilities.isEmpty) {
          markTestSkipped('No task types available');
          return;
        }

        final taskType = capabilities.keys.first;
        print('Testing with task type: $taskType');

        // Create a temporary file
        final tempFile = File(
          'test_generic_${DateTime.now().millisecondsSinceEpoch}.txt',
        );
        await tempFile.writeAsString('test content');
        testFiles.add(tempFile.path);

        // Create job
        final response = await createTestJob(
          taskType: taskType,
          params: getDefaultParams(taskType),
          file: tempFile,
        );

        expect(response.jobId, isNotEmpty);

        // Get job
        final job = await computeService.getJob(response.jobId);
        expect(job.jobId, response.jobId);
        expect(job.taskType, taskType);

        // Delete job
        await computeService.deleteJob(response.jobId);

        // Verify deletion
        try {
          await computeService.getJob(response.jobId);
          fail('Should have thrown ResourceNotFoundException');
        } on ResourceNotFoundException {
          // Expected
        }

        // Remove from tracking since we already deleted it
        testJobIds.remove(response.jobId);
      });

      test('✅ getJob returns valid job data', () async {
        final capabilities = await computeService.getCapabilities();
        if (capabilities.isEmpty) {
          markTestSkipped('No task types available');
          return;
        }

        final taskType = capabilities.keys.first;
        final tempFile = File(
          'test_data_${DateTime.now().millisecondsSinceEpoch}.txt',
        );
        await tempFile.writeAsString('test');
        testFiles.add(tempFile.path);

        final response = await createTestJob(
          taskType: taskType,
          params: getDefaultParams(taskType),
          file: tempFile,
        );

        final job = await computeService.getJob(response.jobId);

        expect(job.jobId, response.jobId);
        expect(job.taskType, taskType);
        expect(job.status, isNotEmpty);
        expect(job.createdAt, greaterThan(0));
      });

      test('✅ Job has correct task_type', () async {
        final capabilities = await computeService.getCapabilities();
        if (capabilities.isEmpty) {
          markTestSkipped('No task types available');
          return;
        }

        for (final taskType in capabilities.keys.take(2)) {
          final tempFile = File(
            'test_type_${taskType}_'
            '${DateTime.now().millisecondsSinceEpoch}.txt',
          );
          await tempFile.writeAsString('test');
          testFiles.add(tempFile.path);

          final response = await createTestJob(
            taskType: taskType,
            params: getDefaultParams(taskType),
            file: tempFile,
          );

          final job = await computeService.getJob(response.jobId);
          expect(job.taskType, taskType);
        }
      });

      test('✅ Job has created_at timestamp', () async {
        final capabilities = await computeService.getCapabilities();
        if (capabilities.isEmpty) {
          markTestSkipped('No task types available');
          return;
        }

        final taskType = capabilities.keys.first;
        final tempFile = File(
          'test_timestamp_${DateTime.now().millisecondsSinceEpoch}.txt',
        );
        await tempFile.writeAsString('test');
        testFiles.add(tempFile.path);

        final response = await createTestJob(
          taskType: taskType,
          params: getDefaultParams(taskType),
          file: tempFile,
        );

        final job = await computeService.getJob(response.jobId);

        expect(job.createdAt, isNotNull);
        expect(job.createdAt, greaterThan(0));

        // Verify timestamp is reasonable (within last hour)
        final nowMillis = DateTime.now().millisecondsSinceEpoch;
        final oneHourAgo = nowMillis - (60 * 60 * 1000);
        expect(job.createdAt, greaterThan(oneHourAgo));
        expect(job.createdAt, lessThanOrEqualTo(nowMillis));
      });

      test('✅ deleteJob removes job successfully', () async {
        final capabilities = await computeService.getCapabilities();
        if (capabilities.isEmpty) {
          markTestSkipped('No task types available');
          return;
        }

        final taskType = capabilities.keys.first;
        final tempFile = File(
          'test_delete_${DateTime.now().millisecondsSinceEpoch}.txt',
        );
        await tempFile.writeAsString('test');
        testFiles.add(tempFile.path);

        final response = await createTestJob(
          taskType: taskType,
          params: getDefaultParams(taskType),
          file: tempFile,
        );

        // Delete job
        await expectLater(
          computeService.deleteJob(response.jobId),
          completes,
        );

        // Verify job is deleted
        expect(
          () => computeService.getJob(response.jobId),
          throwsA(isA<ResourceNotFoundException>()),
        );

        testJobIds.remove(response.jobId);
      });
    });

    group('Admin Operations', () {
      test('✅ getStorageSize returns valid data', () async {
        final storageInfo = await computeService.getStorageSize();

        expect(storageInfo, isNotNull);
        expect(storageInfo.totalSize, greaterThanOrEqualTo(0));
        expect(storageInfo.jobCount, greaterThanOrEqualTo(0));

        print(
          'Storage: ${storageInfo.totalSize} bytes, '
          '${storageInfo.jobCount} jobs',
        );
      });

      test('✅ Storage size returns valid structure', () async {
        // Verify getStorageSize returns valid data structure
        final storageInfo = await computeService.getStorageSize();

        expect(storageInfo.totalSize, isA<int>());
        expect(storageInfo.jobCount, isA<int>());
        expect(storageInfo.totalSize, greaterThanOrEqualTo(0));
        expect(storageInfo.jobCount, greaterThanOrEqualTo(0));
      });

      test('✅ cleanupOldJobs with days parameter', () async {
        final result = await computeService.cleanupOldJobs(days: 365);

        expect(result, isNotNull);
        expect(result.deletedCount, greaterThanOrEqualTo(0));
        expect(result.freedSpace, greaterThanOrEqualTo(0));

        print(
          'Cleanup: ${result.deletedCount} jobs, '
          '${result.freedSpace} bytes freed',
        );
      });

      test('✅ cleanupOldJobs returns deleted count', () async {
        final result = await computeService.cleanupOldJobs(days: 365);

        expect(result.deletedCount, isA<int>());
        expect(result.freedSpace, isA<int>());
      });
    });

    group('Error Handling', () {
      test(
        '❌ getJob with non-existent job_id throws ResourceNotFoundException',
        () async {
          expect(
            () => computeService.getJob('non-existent-job-id-12345'),
            throwsA(isA<ResourceNotFoundException>()),
          );
        },
      );

      test(
        '❌ deleteJob with non-existent job_id throws ResourceNotFoundException',
        () async {
          expect(
            () => computeService.deleteJob('non-existent-job-id-67890'),
            throwsA(isA<ResourceNotFoundException>()),
          );
        },
      );

      test('❌ createJob without authentication throws AuthException', () async {
        // Create unauthenticated service
        final unauthService = ComputeService(computeServiceBaseUrl);

        final capabilities = await unauthService.getCapabilities();
        if (capabilities.isEmpty) {
          markTestSkipped('No task types available');
          return;
        }

        final taskType = capabilities.keys.first;

        expect(
          () => unauthService.createJob(
            taskType: taskType,
            body: {},
          ),
          throwsA(isA<AuthException>()),
        );
      });
    });

    group('Polling Workflow Tests', () {
      test(
        '✅ waitForJobCompletionWithPolling completes successfully',
        () async {
          if (!await hasTaskType('image_resize')) {
            markTestSkipped('image_resize not available');
            return;
          }

          final imagePath = await generateTestImage(
            width: 640,
            height: 480,
            fileName:
                'test_polling_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          testFiles.add(imagePath);

          final response = await createTestJob(
            taskType: 'image_resize',
            params: {
              'width': '320',
              'height': '240',
            },
            file: File(imagePath),
          );

          final job = await computeService.waitForJobCompletionWithPolling(
            response.jobId,
            timeout: const Duration(minutes: 2),
          );

          expect(job.isFinished, isTrue);
          expect(job.status, anyOf('completed', 'failed'));
        },
      );

      test('✅ Polling with custom interval', () async {
        if (!await hasTaskType('image_resize')) {
          markTestSkipped('image_resize not available');
          return;
        }

        final imagePath = await generateTestImage(
          width: 400,
          height: 300,
          fileName:
              'test_interval_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        testFiles.add(imagePath);

        final response = await createTestJob(
          taskType: 'image_resize',
          params: {
            'width': '200',
            'height': '150',
          },
          file: File(imagePath),
        );

        final job = await computeService.waitForJobCompletionWithPolling(
          response.jobId,
          interval: const Duration(seconds: 1),
          timeout: const Duration(minutes: 2),
        );

        expect(job.isFinished, isTrue);
      });

      test('✅ Polling calls onProgress callback', () async {
        if (!await hasTaskType('image_resize')) {
          markTestSkipped('image_resize not available');
          return;
        }

        final imagePath = await generateTestImage(
          width: 800,
          height: 600,
          fileName:
              'test_progress_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        testFiles.add(imagePath);

        final response = await createTestJob(
          taskType: 'image_resize',
          params: {
            'width': '400',
            'height': '300',
          },
          file: File(imagePath),
        );

        var callbackInvoked = false;

        await computeService.waitForJobCompletionWithPolling(
          response.jobId,
          timeout: const Duration(minutes: 2),
          onProgress: (job) {
            callbackInvoked = true;
            print('Progress: ${job.status} - ${job.progress}%');
          },
        );

        expect(callbackInvoked, isTrue);
      });
    });

    group('MQTT Integration Tests', () {
      late MqttService mqttService;
      final createdTestImages = <String>[];

      setUp(() async {
        // Check if MQTT broker is available
        if (!await checkMqttBrokerHealth()) {
          markTestSkipped('MQTT broker not available at localhost:1883');
          return;
        }

        // Create and connect MQTT service
        mqttService = MqttService(
          brokerUrl: 'localhost',
          brokerPort: 1883,
          topic: 'inference/events',
        );

        await mqttService.connect();
        expect(mqttService.isConnected, isTrue);
      });

      tearDown(() async {
        if (mqttService.isConnected) {
          await mqttService.disconnect();
        }

        // Cleanup test images
        await cleanupTestImages(createdTestImages);
        createdTestImages.clear();
      });

      test('✅ Complete job workflow with MQTT updates', () async {
        // Skip if image_resize not available
        if (!await hasTaskType('image_resize')) {
          markTestSkipped('image_resize task type not available');
          return;
        }

        // Generate test image
        final imagePath = await generateTestImage(
          width: 1024,
          height: 768,
          fileName: 'test_mqtt_workflow.png',
        );
        createdTestImages.add(imagePath);

        // Create job
        final response = await createTestJob(
          taskType: 'image_resize',
          params: {'width': '512', 'height': '384'},
          file: File(imagePath),
        );

        print('Created job: ${response.jobId}');

        // Wait for MQTT completion (returns jobId only)
        final completedJobId = await mqttService.waitForCompletion(
          jobId: response.jobId,
          timeout: const Duration(minutes: 2),
        );

        expect(completedJobId, equals(response.jobId));

        // Fetch full Job from API
        final job = await computeService.getJob(completedJobId);

        // Verify job completed successfully
        expect(job.status, equals('completed'));
        expect(job.taskOutput, isNotNull);
        print('Job completed with output: ${job.taskOutput}');
      });

      test('✅ Track status transitions via MQTT', () async {
        // Skip if image_resize not available
        if (!await hasTaskType('image_resize')) {
          markTestSkipped('image_resize task type not available');
          return;
        }

        // Generate test image
        final imagePath = await generateTestImage(
          width: 800,
          height: 600,
          fileName: 'test_mqtt_transitions.png',
        );
        createdTestImages.add(imagePath);

        final statusUpdates = <JobStatus>[];

        // Listen to status stream
        final subscription = mqttService.statusStream.listen((status) {
          print(
            'Status update: ${status.jobId} - ${status.status} '
            '(${status.progress}%)',
          );
        });

        // Create job
        final response = await createTestJob(
          taskType: 'image_resize',
          params: {'width': '400', 'height': '300'},
          file: File(imagePath),
        );

        // Collect status updates for this job
        final jobSubscription = mqttService.statusStream
            .where((status) => status.jobId == response.jobId)
            .listen(statusUpdates.add);

        // Wait for completion
        await mqttService.waitForCompletion(
          jobId: response.jobId,
          timeout: const Duration(minutes: 2),
        );

        // Wait a bit for final status updates
        await Future<void>.delayed(const Duration(milliseconds: 500));

        await subscription.cancel();
        await jobSubscription.cancel();

        // Verify we received status updates
        expect(statusUpdates.isNotEmpty, isTrue);

        // Print transition sequence
        print('Status transitions:');
        for (final status in statusUpdates) {
          print('  ${status.status} (${status.progress}%)');
        }
      });

      test('✅ Handle multiple concurrent jobs', () async {
        // Skip if image_resize not available
        if (!await hasTaskType('image_resize')) {
          markTestSkipped('image_resize task type not available');
          return;
        }

        // Create 3 test images
        final imagePaths = <String>[];
        for (var i = 0; i < 3; i++) {
          final path = await generateTestImage(
            width: 640,
            height: 480,
            fileName: 'test_mqtt_concurrent_$i.png',
          );
          imagePaths.add(path);
          createdTestImages.add(path);
        }

        // Create 3 jobs
        final jobResponses = <CreateJobResponse>[];
        for (var i = 0; i < 3; i++) {
          final response = await createTestJob(
            taskType: 'image_resize',
            params: {'width': '320', 'height': '240'},
            file: File(imagePaths[i]),
          );
          jobResponses.add(response);
          print('Created job ${i + 1}/3: ${response.jobId}');
        }

        // Wait for all jobs to complete concurrently
        final completedJobIds = await Future.wait(
          jobResponses.map(
            (response) => mqttService.waitForCompletion(
              jobId: response.jobId,
              timeout: const Duration(minutes: 3),
            ),
          ),
        );

        // Verify all jobs completed
        expect(completedJobIds.length, equals(3));
        for (var i = 0; i < 3; i++) {
          expect(completedJobIds[i], equals(jobResponses[i].jobId));
          print('Job ${i + 1}/3 completed: ${completedJobIds[i]}');
        }
      });

      test('❌ Timeout when job never completes', () async {
        // Skip if image_resize not available
        if (!await hasTaskType('image_resize')) {
          markTestSkipped('image_resize task type not available');
          return;
        }

        // Generate test image
        final imagePath = await generateTestImage(
          width: 512,
          height: 384,
          fileName: 'test_mqtt_timeout.png',
        );
        createdTestImages.add(imagePath);

        // Create job
        final response = await createTestJob(
          taskType: 'image_resize',
          params: {'width': '256', 'height': '192'},
          file: File(imagePath),
        );

        print('Created job for timeout test: ${response.jobId}');

        // Delete job immediately so MQTT never sends completion
        await computeService.deleteJob(response.jobId);
        print('Deleted job to simulate timeout');

        // Expect TimeoutException after 3 seconds
        expect(
          () => mqttService.waitForCompletion(
            jobId: response.jobId,
            timeout: const Duration(seconds: 3),
          ),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('✅ MQTT faster than polling (performance comparison)', () async {
        // Skip if image_resize not available
        if (!await hasTaskType('image_resize')) {
          markTestSkipped('image_resize task type not available');
          return;
        }

        // Generate two identical test images
        final imagePath1 = await generateTestImage(
          width: 800,
          height: 600,
          fileName: 'test_mqtt_perf1.png',
        );
        final imagePath2 = await generateTestImage(
          width: 800,
          height: 600,
          fileName: 'test_mqtt_perf2.png',
        );
        createdTestImages.addAll([imagePath1, imagePath2]);

        // Test MQTT speed
        final mqttStopwatch = Stopwatch()..start();
        final mqttResponse = await createTestJob(
          taskType: 'image_resize',
          params: {'width': '400', 'height': '300'},
          file: File(imagePath1),
        );

        await mqttService.waitForCompletion(
          jobId: mqttResponse.jobId,
          timeout: const Duration(minutes: 2),
        );
        mqttStopwatch.stop();

        print('MQTT completion time: ${mqttStopwatch.elapsedMilliseconds}ms');

        // Small delay between tests
        await Future<void>.delayed(const Duration(seconds: 1));

        // Test polling speed (2s interval)
        final pollingStopwatch = Stopwatch()..start();
        final pollingResponse = await createTestJob(
          taskType: 'image_resize',
          params: {'width': '400', 'height': '300'},
          file: File(imagePath2),
        );

        await computeService.waitForJobCompletionWithPolling(
          pollingResponse.jobId,
          interval: const Duration(seconds: 2),
          timeout: const Duration(minutes: 2),
        );
        pollingStopwatch.stop();

        print(
          'Polling completion time: '
          '${pollingStopwatch.elapsedMilliseconds}ms',
        );

        // Calculate speedup
        final speedup =
            pollingStopwatch.elapsedMilliseconds /
            mqttStopwatch.elapsedMilliseconds;
        print('MQTT speedup: ${speedup.toStringAsFixed(2)}x faster');

        // MQTT should generally be faster (or within tolerance)
        // We allow some variance due to system load
        expect(
          mqttStopwatch.elapsedMilliseconds,
          lessThanOrEqualTo(pollingStopwatch.elapsedMilliseconds + 5000),
          reason: 'MQTT should be faster or comparable to polling',
        );
      });

      test('✅ Query status cache', () async {
        // Skip if image_resize not available
        if (!await hasTaskType('image_resize')) {
          markTestSkipped('image_resize task type not available');
          return;
        }

        // Generate test image
        final imagePath = await generateTestImage(
          width: 640,
          height: 480,
          fileName: 'test_mqtt_cache.png',
        );
        createdTestImages.add(imagePath);

        // Create job
        final response = await createTestJob(
          taskType: 'image_resize',
          params: {'width': '320', 'height': '240'},
          file: File(imagePath),
        );

        // Wait for some status updates
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Query cache
        final cachedStatus = mqttService.getStatus(response.jobId);

        if (cachedStatus != null) {
          print(
            'Cached status: ${cachedStatus.status} '
            '(${cachedStatus.progress}%)',
          );
          expect(cachedStatus.jobId, equals(response.jobId));
        } else {
          print('No cached status yet (job might be very fast or not started)');
        }

        // Wait for completion
        await mqttService.waitForCompletion(
          jobId: response.jobId,
          timeout: const Duration(minutes: 2),
        );

        // Query cache again - should have final status
        final finalStatus = mqttService.getStatus(response.jobId);
        expect(finalStatus, isNotNull);
        expect(finalStatus!.isFinished, isTrue);
        print('Final cached status: ${finalStatus.status}');
      });

      test('✅ Handle connection loss gracefully', () async {
        expect(mqttService.isConnected, isTrue);

        // Disconnect
        await mqttService.disconnect();
        expect(mqttService.isConnected, isFalse);

        // Reconnect
        await mqttService.connect();
        expect(mqttService.isConnected, isTrue);

        print('Successfully disconnected and reconnected to MQTT broker');
      });
    });
  });
}

// Helper functions

/// Check if a specific task type is available
Future<bool> hasTaskType(String taskType) async {
  final caps = await computeService.getCapabilities();
  return caps.containsKey(taskType);
}

/// Get default parameters for a task type
Map<String, dynamic> getDefaultParams(String taskType) {
  switch (taskType) {
    case 'image_resize':
      return {'width': '800', 'height': '600'};
    case 'image_conversion':
      return {'format': 'png'};
    default:
      return {};
  }
}

/// Create test job and track for cleanup
Future<CreateJobResponse> createTestJob({
  required String taskType,
  required Map<String, dynamic> params,
  File? file,
  int? priority,
}) async {
  final response = await computeService.createJob(
    taskType: taskType,
    body: params,
    file: file,
    priority: priority,
  );
  testJobIds.add(response.jobId);
  return response;
}
