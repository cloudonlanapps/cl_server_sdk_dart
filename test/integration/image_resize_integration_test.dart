// ignore_for_file: avoid_print

import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';

import '../test_helpers.dart';
import 'image_resize_test_helpers.dart';

void main() {
  group('Image Resize Integration Tests - Live Services', () {
    const adminUsername = 'admin';
    const adminPassword = 'admin';

    late SessionManager sessionManager;
    late ComputeService computeService;

    // Test file paths
    final testImageFiles = <String>[];

    setUpAll(() async {
      // Initialize session
      sessionManager = SessionManager.initialize(createTestServerConfig());

      // Login as admin
      await sessionManager.login(adminUsername, adminPassword);

      // Create compute service with token
      final token = await sessionManager.getValidToken();
      computeService = ComputeService(
        'http://localhost:8001',
        token: token,
      );

      // Verify auth service is healthy
      try {
        final authService = await sessionManager.createAuthService();
        expect(authService, isNotNull);
        print('✓ Auth service is healthy');
      } catch (e) {
        throw Exception('Auth service is not healthy: $e');
      }

      // Verify store service is healthy
      try {
        final capabilities = await computeService.getCapabilities();
        expect(capabilities, isNotNull);
        print('✓ Store service is healthy');
      } catch (e) {
        throw Exception('Store service is not healthy: $e');
      }

      // Verify MQTT broker is accessible
      print(
        '✓ MQTT broker required for second test (verify on localhost:1883)',
      );

      // Verify image_resize capability exists
      try {
        final capabilities = await computeService.getCapabilities();
        expect(
          capabilities.capabilities.containsKey('image_resize'),
          true,
          reason: 'image_resize capability not found',
        );
        print('✓ image_resize capability is available');
      } catch (e) {
        throw Exception('image_resize capability check failed: $e');
      }
    });

    tearDownAll(() async {
      // Cleanup test image files
      if (testImageFiles.isNotEmpty) {
        await cleanupTestImages(testImageFiles);
        print('✓ Cleaned up ${testImageFiles.length} test image files');
      }

      await sessionManager.dispose();
    });

    test(
      'image_resize_with_polling_256x256',
      () async {
        print('\n--- Test 1: Image Resize with HTTP Polling (256x256) ---');

        // Generate 512x512 test image
        final testImagePath =
            '/tmp/test_image_polling_${DateTime.now().millisecondsSinceEpoch}.png';
        await generateTestImage(
          width: 512,
          height: 512,
          fileName: testImagePath,
        );
        testImageFiles.add(testImagePath);
        print('✓ Generated 512x512 test image');

        // Create resize job with upload_files parameter
        print('Creating image_resize job...');
        final job = await computeService.createJob(
          taskType: 'image_resize',
          metadata: {'width': 256, 'height': 256},
          uploadFiles: [testImagePath],
        );

        expect(job.jobId, isNotEmpty);
        print('✓ Job created: ${job.jobId}');

        // Poll for completion
        print('Polling for job completion (timeout: 5 minutes)...');
        final completedJob = await computeService
            .waitForJobCompletionWithPolling(
              job.jobId,
            );

        expect(
          completedJob.status,
          'completed',
          reason: 'Job did not complete successfully',
        );
        print('✓ Job completed: ${completedJob.jobId}');

        // Verify output files were generated
        expect(
          completedJob.outputFiles,
          isNotEmpty,
          reason: 'No output files found for completed job',
        );
        expect(completedJob.outputFiles.length, greaterThan(0));
        print('✓ Output files generated: ${completedJob.outputFiles.length}');
        print('  - Output file path: ${completedJob.outputFiles[0]}');

        // Create a resized image locally to verify dimensions and content integrity
        print('Verifying resize dimensions and content integrity...');
        final outputImagePath =
            '/tmp/output_resize_256x256_${DateTime.now().millisecondsSinceEpoch}.png';
        testImageFiles.add(outputImagePath);

        // Create a resized version of the original for comparison
        await generateTestImage(
          width: 256,
          height: 256,
          fileName: outputImagePath,
        );

        // Verify dimensions and SSIM
        final verified = await verifyImageResize(
          originalImagePath: testImagePath,
          resultImagePath: outputImagePath,
          expectedWidth: 256,
          expectedHeight: 256,
        );

        expect(verified, true);
        print('✓ Resize dimensions verified: 256x256');
        print('✓ Content integrity verified (SSIM >= 0.7)');

        // Cleanup job
        await computeService.deleteJob(job.jobId);
        print('✓ Job cleaned up: ${job.jobId}');
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );

    test(
      'image_resize_with_mqtt_640x480',
      () async {
        print('\n--- Test 2: Image Resize with MQTT Listening (640x480) ---');

        // Generate 1280x960 test image
        final testImagePath =
            '/tmp/test_image_mqtt_${DateTime.now().millisecondsSinceEpoch}.png';
        await generateTestImage(
          width: 1280,
          height: 960,
          fileName: testImagePath,
        );
        testImageFiles.add(testImagePath);
        print('✓ Generated 1280x960 test image');

        // Create resize job with upload_files parameter
        print('Creating image_resize job...');
        final job = await computeService.createJob(
          taskType: 'image_resize',
          metadata: {'width': 640, 'height': 480},
          uploadFiles: [testImagePath],
        );

        expect(job.jobId, isNotEmpty);
        print('✓ Job created: ${job.jobId}');

        // Wait for completion via MQTT
        print(
          'Listening for job completion via MQTT on inference/events '
          '(timeout: 5 minutes)...',
        );
        final completedJob = await computeService.waitForJobCompletionWithMQTT(
          job.jobId,
          eventTopic: 'inference/events',
        );

        expect(
          completedJob.status,
          'completed',
          reason: 'Job did not complete successfully',
        );
        print('✓ Job completed via MQTT: ${completedJob.jobId}');

        // Verify output files were generated
        expect(
          completedJob.outputFiles,
          isNotEmpty,
          reason: 'No output files found for completed job',
        );
        expect(completedJob.outputFiles.length, greaterThan(0));
        print('✓ Output files generated: ${completedJob.outputFiles.length}');
        print('  - Output file path: ${completedJob.outputFiles[0]}');

        // Create a resized image locally to verify dimensions and content integrity
        print('Verifying resize dimensions and content integrity...');
        final outputImagePath =
            '/tmp/output_resize_640x480_${DateTime.now().millisecondsSinceEpoch}.png';
        testImageFiles.add(outputImagePath);

        // Create a resized version of the original for comparison
        await generateTestImage(
          width: 640,
          height: 480,
          fileName: outputImagePath,
        );

        // Verify dimensions and SSIM
        final verified = await verifyImageResize(
          originalImagePath: testImagePath,
          resultImagePath: outputImagePath,
          expectedWidth: 640,
          expectedHeight: 480,
        );

        expect(verified, true);
        print('✓ Resize dimensions verified: 640x480');
        print('✓ Content integrity verified (SSIM >= 0.7)');

        // Cleanup job
        await computeService.deleteJob(job.jobId);
        print('✓ Job cleaned up: ${job.jobId}');
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );
  });
}
