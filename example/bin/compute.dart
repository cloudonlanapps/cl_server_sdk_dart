import 'dart:io';

import 'package:args/args.dart';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';

final globalParser = ArgParser()
  ..addOption(
    'auth-url',
    defaultsTo: 'http://localhost:8000',
    help: 'Auth service URL',
  )
  ..addOption(
    'store-url',
    defaultsTo: 'http://localhost:8001',
    help: 'Store service URL',
  )
  ..addOption(
    'username',
    abbr: 'u',
    help: 'Username (for authenticated mode)',
  )
  ..addOption(
    'password',
    abbr: 'p',
    help: 'Password (for authenticated mode)',
  )
  ..addFlag(
    'help',
    negatable: false,
    help: 'Show help',
  );

final Map<String, Map<String, dynamic>> knownCommands = {
  'resize': {
    'description': 'invoke Resizer',
    'parser': ArgParser()
      ..addOption(
        'file',
        abbr: 'f',
        help: 'input media to resize',
      )
      ..addOption(
        'width',
        abbr: 'w',
        help: 'output media width',
        defaultsTo: '256',
      )
      ..addOption(
        'height',
        abbr: 'h',
        help: 'output media height',
        defaultsTo: '256',
      ),
  },
};

void main(List<String> args) async {
  // Parse global options

  // Find if there's a known command in the args
  int? commandIndex;
  for (final cmd in knownCommands.keys) {
    final idx = args.indexOf(cmd);
    if (idx >= 0) {
      commandIndex = idx;
      break;
    }
  }

  // Parse global args separately from command args
  final globalArgs =
      commandIndex != null ? args.sublist(0, commandIndex) : args;
  final remaining =
      commandIndex != null ? args.sublist(commandIndex) : <String>[];
  final results = globalParser.parse(globalArgs);

  try {
    if (results['help'] as bool) {
      printHelp(globalParser);
      exit(0);
    }

    final authUrl = results['auth-url'] as String;
    final storeUrl = results['store-url'] as String;
    final username = results['username'] == null
        ? null
        : results['username'] == 'admin'
            ? 'admin'
            : "t#${results['username']}";
    final password = results['password'] as String?;

    if (username == null || password == null) {
      stderr.writeln(
        '❌ Error: --username and --password required for authenticated mode',
      );
      exit(1);
    }
    final config = ServerConfig(
      authServiceBaseUrl: authUrl,
      storeServiceBaseUrl: storeUrl,
    );
    final sessionManager = SessionManager.initialize(config);
    await sessionManager.login(username, password);
    final command = remaining[0];
    final commandArgs = remaining.skip(1).toList();
    final computeService = await sessionManager.createComputeService();
    switch (command) {
      case 'resize':
        await handleResize(computeService, commandArgs);
      default:
        stderr.writeln('❌ Unknown command: $command');
        printHelp(globalParser);
        exit(1);
    }
  } on FormatException catch (e) {
    stderr.writeln('❌ Error: ${e.message}');
    exit(1);
  } on Exception catch (e) {
    stderr.writeln('❌ Unexpected error: $e');
    exit(1);
  }
}

Future<bool> computeResize(
  ComputeService computeService,
  String inputFileName, {
  required int width,
  required int height,
  String? outputFileName,
  bool maintainAspectRatio = true,
}) async {
  try {
    if (!(await computeService.hasTaskType('image_resize'))) {
      throw Exception('Worker not found for image_resize');
    }
    final response = await computeService.createJob(
      taskType: 'image_resize',
      body: {
        'width': width,
        'height': height,
        'maintain_aspect_ratio': maintainAspectRatio,
      },
      file: File(inputFileName),
    );
    await computeService.waitForJobCompletionWithPolling(
      response.jobId,
      timeout: const Duration(minutes: 2),
      onProgress: (job) {
        print('Job ${job.jobId}: ${job.status} - ${job.progress}%');
      },
    );
    final job = await computeService.getJob(response.jobId);
    print('Job ${job.jobId} is ${job.status}');
    print(job);
    return (job.status == 'completed');
  } on Exception catch (_) {
    return false;
  }
}

Future<void> handleResize(
  ComputeService computeService,
  List<String> args,
) async {
  try {
    if (knownCommands['resize'] == null) {
      throw Exception('resize not supported');
    }
    final results =
        (knownCommands['resize']!['parser'] as ArgParser).parse(args);

    final width = int.parse(results['width'] as String);
    final height = int.parse(results['height'] as String);
    final file = results['file'] as String?;
    if (file == null) {
      throw Exception('File not provided (use -f / --file)');
    }
    final success =
        await computeResize(computeService, file, width: width, height: height);

    if (success) {
      print('✅ Resize successfully completed');
    } else {
      throw Exception('resize failed');
    }
  } on Exception catch (e) {
    stderr.writeln('❌ Error: $e');
    exit(1);
  }
}

void printHelp(ArgParser parser) {
  print('''
Store Manager - Manage entities in CL Server Store Service

Usage: dart run store_manager.dart [global-options] <command> [command-options]

Global Options:
${parser.usage}
''');
  for (final command in knownCommands.entries) {
    print("${command.key} - ${command.value['description']!}");
  }
  print('Command Options');
  for (final command in knownCommands.entries) {
    print('\t${command.key}:');
    print(
      '\t'
      '${(command.value['parser'] as ArgParser).usage.replaceAll('\n', '\n\t')}',
    );
  }
}
