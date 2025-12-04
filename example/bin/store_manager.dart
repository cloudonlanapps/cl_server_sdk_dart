// ignore_for_file: avoid_print for demo

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';
import 'package:path/path.dart' as p;

late StoreManager storeManager;

void main(List<String> args) async {
  // Parse global options
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
      'guest',
      defaultsTo: true,
      help: 'Use guest mode (default) or authenticated',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show help',
    );

  try {
    final results = globalParser.parse(args);

    if (results['help'] as bool) {
      printHelp(globalParser);
      exit(0);
    }

    // Initialize store manager
    final isGuest = results['guest'] as bool;
    final authUrl = results['auth-url'] as String;
    final storeUrl = results['store-url'] as String;

    // Create server configuration
    final config = ServerConfig(
      authServiceBaseUrl: authUrl,
      storeServiceBaseUrl: storeUrl,
    );

    if (isGuest) {
      storeManager = StoreManager.guest(storeUrl);
    } else {
      // Authenticated mode
      final username = results['username'] as String?;
      final password = results['password'] as String?;

      if (username == null || password == null) {
        stderr.writeln(
          '❌ Error: --username and --password required for authenticated mode',
        );
        exit(1);
      }

      try {
        final sessionManager = SessionManager.initialize(config);
        await sessionManager.login(username, password);
        storeManager = await StoreManager.authenticated(
          sessionManager: sessionManager,
        );
      } on Exception catch (e) {
        stderr.writeln('❌ Authentication failed: $e');
        exit(1);
      }
    }

    // Get remaining args (after parsing global options)
    final remaining = results.rest;

    if (remaining.isEmpty) {
      printHelp(globalParser);
      exit(0);
    }

    final command = remaining[0];
    final commandArgs = remaining.skip(1).toList();

    switch (command) {
      case 'list-entities':
        await handleListEntities(commandArgs);
      case 'create-entity':
        await handleCreateEntity(commandArgs);
      case 'read-entity':
        await handleReadEntity(commandArgs);
      case 'update-entity':
        await handleUpdateEntity(commandArgs);
      case 'patch-entity':
        await handlePatchEntity(commandArgs);
      case 'delete-entity':
        await handleDeleteEntity(commandArgs);
      case 'help':
        printHelp(globalParser);
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

/// Handle list-entities command
Future<void> handleListEntities(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'page',
      defaultsTo: '1',
      help: 'Page number',
    )
    ..addOption(
      'page-size',
      defaultsTo: '20',
      help: 'Items per page',
    )
    ..addOption(
      'search',
      help: 'Search query',
    );

  try {
    final results = parser.parse(args);
    final page = int.tryParse(results['page'] as String) ?? 1;
    final pageSize = int.tryParse(results['page-size'] as String) ?? 20;
    final searchQuery = results['search'] as String?;

    final result = await storeManager.listEntities(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
    );

    if (result.isError) {
      stderr.writeln('❌ ${result.error}');
      exit(1);
    }

    print('✅ ${result.success}');
    // Data is EntityListResponse
    if (result.data != null) {
      print('   Total items: ${(result.data as PaginationInfo).totalItems}');
      print('   Total pages: ${(result.data as PaginationInfo).totalPages}');
    }
  } on Exception catch (e) {
    stderr.writeln('❌ Error: $e');
    exit(1);
  }
}

/// Handle create-entity command
Future<void> handleCreateEntity(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'file',
      help: 'File or directory path',
    )
    ..addOption(
      'label',
      help: 'Entity label',
    )
    ..addOption(
      'description',
      help: 'Entity description',
    )
    ..addOption(
      'parent',
      help: 'Parent collection label',
    )
    ..addOption(
      'parent-id',
      help: 'Parent collection ID',
    )
    ..addFlag(
      'collection',
      help: 'Create as collection',
    );

  try {
    final results = parser.parse(args);
    final filePath = results['file'] as String?;

    if (filePath == null) {
      stderr.writeln('❌ Error: --file is required');
      exit(1);
    }

    final file = File(filePath);
    final isDir =
        file.existsSync() && (FileSystemEntity.isDirectorySync(filePath));

    if (!file.existsSync()) {
      stderr.writeln('❌ Error: File or directory not found: $filePath');
      exit(1);
    }

    if (isDir) {
      // Directory handling
      await _handleDirectoryRecursive(
        Directory(filePath),
        results,
      );
    } else {
      // Single file
      final result = await storeManager.createEntity(
        label: results['label'] as String?,
        description: results['description'] as String?,
        isCollection: results['collection'] as bool,
        parentLabel: results['parent'] as String?,
        parentId: results['parent-id'] as String?,
      );

      if (result.isError) {
        stderr.writeln('❌ ${result.error}');
        exit(1);
      }

      print('✅ ${result.success}');
      if (result.data != null) {
        print('   ID: ${(result.data as Entity).id}');
      }
    }
  } on Exception catch (e) {
    stderr.writeln('❌ Error: $e');
    exit(1);
  }
}

/// Handle read-entity command
Future<void> handleReadEntity(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'id',
      help: 'Entity ID',
    );

  try {
    final results = parser.parse(args);
    final id = results['id'] as String?;

    if (id == null) {
      stderr.writeln('❌ Error: --id is required');
      exit(1);
    }

    final entityId = int.tryParse(id);
    if (entityId == null) {
      stderr.writeln('❌ Error: Invalid entity ID: $id');
      exit(1);
    }

    final result = await storeManager.readEntity(entityId: entityId);

    if (result.isError) {
      stderr.writeln('❌ ${result.error}');
      exit(1);
    }

    print('✅ ${result.success}');
    if (result.data != null) {
      print('   ID: ${(result.data as Entity).id}');
      print('   Label: ${(result.data as Entity).label}');
    }
  } on Exception catch (e) {
    stderr.writeln('❌ Error: $e');
    exit(1);
  }
}

/// Handle update-entity command
Future<void> handleUpdateEntity(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'id',
      help: 'Entity ID',
    )
    ..addOption(
      'label',
      help: 'New label',
    )
    ..addOption(
      'description',
      help: 'New description',
    )
    ..addFlag(
      'collection',
      help: 'Is collection',
    );

  try {
    final results = parser.parse(args);
    final id = results['id'] as String?;
    final label = results['label'] as String?;

    if (id == null) {
      stderr.writeln('❌ Error: --id is required');
      exit(1);
    }

    if (label == null) {
      stderr.writeln('❌ Error: --label is required');
      exit(1);
    }

    final entityId = int.tryParse(id);
    if (entityId == null) {
      stderr.writeln('❌ Error: Invalid entity ID: $id');
      exit(1);
    }

    final isCollection = results['collection'] as bool;

    final result = await storeManager.updateEntity(
      entityId: entityId,
      label: label,
      isCollection: isCollection,
      description: results['description'] as String?,
    );

    if (result.isError) {
      stderr.writeln('❌ ${result.error}');
      exit(1);
    }

    print('✅ ${result.success}');
  } on Exception catch (e) {
    stderr.writeln('❌ Error: $e');
    exit(1);
  }
}

/// Handle patch-entity command
Future<void> handlePatchEntity(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'id',
      help: 'Entity ID',
    )
    ..addOption(
      'label',
      help: 'New label',
    )
    ..addOption(
      'description',
      help: 'New description',
    );

  try {
    final results = parser.parse(args);
    final id = results['id'] as String?;

    if (id == null) {
      stderr.writeln('❌ Error: --id is required');
      exit(1);
    }

    final entityId = int.tryParse(id);
    if (entityId == null) {
      stderr.writeln('❌ Error: Invalid entity ID: $id');
      exit(1);
    }

    final result = await storeManager.patchEntity(
      entityId: entityId,
      label: results['label'] as String?,
      description: results['description'] as String?,
    );

    if (result.isError) {
      stderr.writeln('❌ ${result.error}');
      exit(1);
    }

    print('✅ ${result.success}');
  } on Exception catch (e) {
    stderr.writeln('❌ Error: $e');
    exit(1);
  }
}

/// Handle delete-entity command
Future<void> handleDeleteEntity(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'id',
      help: 'Entity ID',
    )
    ..addFlag(
      'force',
      negatable: false,
      help: 'Skip confirmation',
    );

  try {
    final results = parser.parse(args);
    final id = results['id'] as String?;

    if (id == null) {
      stderr.writeln('❌ Error: --id is required');
      exit(1);
    }

    final entityId = int.tryParse(id);
    if (entityId == null) {
      stderr.writeln('❌ Error: Invalid entity ID: $id');
      exit(1);
    }

    // Ask for confirmation unless --force
    if (!(results['force'] as bool)) {
      stdout.write(
        'Are you sure you want to delete entity $entityId? (yes/no): ',
      );
      final confirmation = stdin.readLineSync()?.toLowerCase() ?? '';
      if (confirmation != 'yes' && confirmation != 'y') {
        print('Cancelled.');
        return;
      }
    }

    final result = await storeManager.deleteEntity(entityId: entityId);

    if (result.isError) {
      stderr.writeln('❌ ${result.error}');
      exit(1);
    }

    print('✅ ${result.success}');
  } on Exception catch (e) {
    stderr.writeln('❌ Error: $e');
    exit(1);
  }
}

/// Handle directory recursion
Future<void> _handleDirectoryRecursive(
  Directory dir,
  ArgResults args,
) async {
  // Generate collection name from directory path
  final dirName = p.basename(dir.path);
  final parentLabel = args['parent'] as String? ?? dirName;

  print('📁 Processing directory: ${dir.path}');
  print('   Collection: $parentLabel');

  var fileCount = 0;

  // List all files and directories
  try {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        fileCount++;
        final relativePath = p.relative(entity.path, from: dir.path);

        // Create entity for each file
        final result = await storeManager.createEntity(
          label: p.basename(entity.path),
          description: 'File: $relativePath',
          parentLabel: parentLabel,
        );

        if (result.isError) {
          stderr.writeln('❌ Failed to upload $relativePath: ${result.error}');
        } else {
          print('   ✓ $relativePath');
        }
      }
    }

    if (fileCount == 0) {
      print('⚠️  No files found in directory');
    } else {
      print('✅ Processed $fileCount files');
    }
  } on Exception catch (e) {
    stderr.writeln('❌ Directory processing error: $e');
    exit(1);
  }
}

void printHelp(ArgParser parser) {
  print('''
Store Manager - Manage entities in CL Server Store Service

Usage: dart run store_manager.dart [global-options] <command> [command-options]

Global Options:
${parser.usage}

Commands:
  list-entities       List all entities
  create-entity       Create a new entity or upload file(s)
  read-entity         Read a single entity
  update-entity       Update an entity (full update)
  patch-entity        Patch an entity (partial update)
  delete-entity       Delete an entity

Examples:
  # Guest mode - list entities
  dart run store_manager.dart list-entities

  # Authenticated mode - create entity
  dart run store_manager.dart --guest=false --username alice --password pass123 \\
    create-entity --label "My Entity"

  # Upload single file
  dart run store_manager.dart create-entity --file /path/to/file.jpg --label "Photo"

  # Upload directory
  dart run store_manager.dart create-entity --file /path/to/directory

  # Update entity
  dart run store_manager.dart update-entity --id 123 --label "Updated" --collection=false

  # Patch entity
  dart run store_manager.dart patch-entity --id 123 --label "Patched"

  # Delete entity
  dart run store_manager.dart delete-entity --id 123
''');
}
