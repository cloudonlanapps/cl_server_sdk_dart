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

    test('test_hash_flow', () async {
      final image = await IntegrationHelper.getTestImage();

      final job = await client.hash.compute(
        image,
        wait: true,
        timeout: const Duration(seconds: 20),
      );

      expect(job.status, equals('completed'));
      expect(job.taskOutput, isNotNull);

      final output = job.taskOutput!;
      print('Hash Output: $output');
      if (output.containsKey('p_hash')) {
        expect(output['p_hash'], isA<String>());
        expect(output['p_hash'].toString().length, greaterThan(0));
      } else {
        print('Warning: server did not return p_hash');
      }

      await client.deleteJob(job.jobId);
    });
  });
}
