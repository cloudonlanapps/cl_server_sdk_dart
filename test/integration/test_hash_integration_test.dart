import 'dart:async';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:test/test.dart';
import 'integration_test_utils.dart';

void main() {
  group('Hash Integration Tests', () {
    late SessionManager session;
    late ComputeClient client;

    setUpAll(() async {
      session = await IntegrationHelper.createSession();
      client = session.createComputeClient();
    });

    tearDownAll(() async {
      await client.close();
      await session.close();
    });

    test('test_hash_http_polling', () async {
      final image = await IntegrationHelper.getTestImage();

      final job = await client.hash.compute(
        image,
        wait: true,
        timeout: const Duration(seconds: 20),
      );

      expect(job.status, equals('completed'));
      expect(job.taskOutput, isNotNull);

      final output = job.taskOutput!;
      //log('Hash Output: $output');
      if (output.containsKey('p_hash')) {
        expect(output['p_hash'], isA<String>());
        expect(output['p_hash'].toString().length, greaterThan(0));
      } else {
        //log('Warning: server did not return p_hash');
      }

      await client.deleteJob(job.jobId);
    });

    test('test_hash_mqtt_callbacks', () async {
      final image = await IntegrationHelper.getTestImage();

      final completionCompleter = Completer<JobResponse>();
      final job = await client.hash.compute(
        image,
        onComplete: completionCompleter.complete,
      );

      final finalJob = await completionCompleter.future.timeout(
        const Duration(seconds: 25),
      );

      expect(finalJob.status, equals('completed'));
      await client.deleteJob(job.jobId);
    });
  });
}
