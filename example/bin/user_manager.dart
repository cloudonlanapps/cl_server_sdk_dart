// ignore_for_file: avoid_print This is on example, we need print

import 'dart:io';
import 'package:args/args.dart';
import 'package:cl_server_dart_client/cl_server_dart_client.dart';

/// CLI Utility for managing CL Server users
///
/// Usage:
///   dart run user_manager.dart `command` `option1` `option2` ...
///
/// User Management Commands:
///   create-user              Create a new user
///   get-user                 Get user details by ID
///   list-users               List all users
///   update-user              Update an existing user
///   delete-user              Delete a user
///   get-user-permissions     Get user permissions by ID
///
/// Store Configuration Commands:
///   get-store-config         Get Store service configuration
///   update-read-auth         Update read authentication in store
///
/// Other:
///   menu                     Interactive menu (default)
///   help                     Show this help message
///
/// Global Options :
///   --auth-url         Auth service URL (default: http://localhost:8000)
///   --store-url        Store service URL (default: http://localhost:8001)
///   --username         Username (will prompt if not provided)
///   --admin-user       Admin username (alias for --username)
///   --password         Password (will prompt if not provided)
///   --admin-password   Admin password (alias for --password)
///   --prefix           User prefix (default: t#)

late SessionManager sessionManager;
late UserManager userManager;

String authServiceUrl = 'http://localhost:8000';
String storeServiceUrl = 'http://localhost:8001';
String userPrefix = 't#';

/// Remove prefix from username for CLI display
String removePrefix(String username) {
  // Try to remove current prefix first
  if (username.startsWith(userPrefix)) {
    return username.substring(userPrefix.length);
  }

  // Try to remove other common prefixes
  const commonPrefixes = ['t#', 'test_', 'cli_', 'util_', 'script_'];
  for (final prefix in commonPrefixes) {
    if (username.startsWith(prefix)) {
      return username.substring(prefix.length);
    }
  }

  return username;
}

/// Check if a username was created by this utility
bool isUtilityCreatedUser(String username) {
  if (username.startsWith(userPrefix)) {
    return true;
  }

  const commonUtilityPrefixes = ['t#', 'test_', 'cli_', 'util_', 'script_'];
  return commonUtilityPrefixes.any((prefix) => username.startsWith(prefix));
}

Future<void> main(List<String> args) async {
  try {
    final parser = ArgParser()
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
        help: 'Username for admin login (alias: --admin-user)',
      )
      ..addOption('admin-user', help: 'Admin username (alias for --username)')
      ..addOption(
        'password',
        help: 'Password for admin login (alias: --admin-password)',
      )
      ..addOption(
        'admin-password',
        help: 'Admin password (alias for --password)',
      )
      ..addOption(
        'prefix',
        defaultsTo: 't#',
        help: 'Prefix for users created by this utility (internal use)',
      )
      ..addFlag('help', abbr: 'h', help: 'Show help message');

    // Parse arguments, separating global options from command args
    late ArgResults results;
    const knownCommands = [
      'create-user',
      'get-user',
      'update-user',
      'delete-user',
      'list-users',
      'get-user-permissions',
      'get-store-config',
      'update-read-auth',
      'menu',
      'login',
      'help',
    ];

    // Find if there's a known command in the args
    int? commandIndex;
    for (final cmd in knownCommands) {
      final idx = args.indexOf(cmd);
      if (idx >= 0) {
        commandIndex = idx;
        break;
      }
    }

    // Parse global args separately from command args
    final globalArgs =
        commandIndex != null ? args.sublist(0, commandIndex) : args;
    final commandArgs =
        commandIndex != null ? args.sublist(commandIndex) : <String>[];

    results = parser.parse(globalArgs);
    // Since we can't modify the rest list, we'll handle rest separately below
    final allRest = [...results.rest, ...commandArgs];

    if (results['help'] as bool) {
      printHelp(parser);
      exit(0);
    }

    authServiceUrl = results['auth-url'] as String;
    storeServiceUrl = results['store-url'] as String;
    userPrefix = results['prefix'] as String;

    // Create server configuration
    final config = ServerConfig(
      authServiceBaseUrl: authServiceUrl,
      storeServiceBaseUrl: storeServiceUrl,
    );

    // Initialize session manager
    sessionManager = SessionManager.initialize(config);

    // Get admin credentials (support both --username/--password and --admin-user/--admin-password)
    var adminUsername = (results['username'] as String?) ??
        (results['admin-user'] as String?) ??
        '';
    var adminPassword = (results['password'] as String?) ??
        (results['admin-password'] as String?) ??
        '';

    if (adminUsername.isEmpty) {
      stdout.write('Admin Username: ');
      adminUsername = stdin.readLineSync() ?? '';
    }
    if (adminPassword.isEmpty) {
      stdout.write('Admin Password: ');
      // Only disable echo mode if stdin is a TTY
      try {
        if (stdin.hasTerminal) {
          stdin.echoMode = false;
        }
      } on Exception catch (_) {
        // Ignore errors if not a TTY
      }
      adminPassword = stdin.readLineSync() ?? '';
      try {
        if (stdin.hasTerminal) {
          stdin.echoMode = true;
        }
      } on Exception catch (_) {
        // Ignore errors if not a TTY
      }
      if (stdin.hasTerminal) {
        stdout.writeln();
      }
    }

    // Login as admin
    print('\n🔐 Logging in as admin...');
    try {
      await sessionManager.login(adminUsername, adminPassword);
      print('✓ Logged in successfully as: ${sessionManager.currentUsername}\n');
    } on Exception catch (e) {
      print('✗ Login failed: $e');
      exit(1);
    }

    // Create authenticated user manager
    userManager = await UserManager.authenticated(
      sessionManager: sessionManager,
      prefix: userPrefix,
    );

    // Get command from arguments
    final command = allRest.isNotEmpty ? allRest[0] : 'menu';

    switch (command) {
      case 'create-user':
        await createUserCommand(allRest.skip(1).toList());
      case 'get-user':
        await getUserCommand(allRest.skip(1).toList());
      case 'update-user':
        await updateUserCommand(allRest.skip(1).toList());
      case 'delete-user':
        await deleteUserCommand(allRest.skip(1).toList());
      case 'list-users':
        await listUsersCommand(allRest.skip(1).toList());
      case 'get-user-permissions':
        await getUserPermissionsCommand(allRest.skip(1).toList());
      case 'get-store-config':
        await getStoreConfigCommand();
      case 'update-read-auth':
        await updateReadAuthCommand(allRest.skip(1).toList());
      case 'menu':
      default:
        await showInteractiveMenu();
    }

    // Cleanup
    await sessionManager.dispose();
  } on Exception catch (e) {
    print('Error: $e');
    exit(1);
  }
}

/// Show help message
void printHelp(ArgParser parser) {
  print(r'''
CL Server User Manager CLI
Version 1.0.0

Usage: dart run user_manager.dart [command] [options]

User Management Commands:
  create-user              Create a new user
                           --username <name> --password <pass>
                           [--email <email>] [--admin]

  get-user                 Get user details by ID
                           --id <user_id>

  list-users               List utility-created users (default) or all users
                           [--all]  Show all users (default shows utility-created only)
                           * = user created by this utility

  update-user              Update an existing user
                           --id <user_id>
                           [--password <new_pass>]
                           [--permissions <perm1,perm2>]
                           [--admin | --no-admin]
                           [--activate | --deactivate]

  delete-user              Delete a user
                           --id <user_id>

  get-user-permissions     Get user permissions by ID
                           --id <user_id>

Store Configuration Commands:
  get-store-config         Get Store service configuration

  update-read-auth         Update read authentication
                           [--enable | --disable]

Global Options:
  --auth-url           Auth service URL (default: http://localhost:8000)
  --store-url          Store service URL (default: http://localhost:8001)
  --username           Admin username (will prompt if not provided)
  --admin-user         Admin username (alias for --username)
  --password           Admin password (will prompt if not provided)
  --admin-password     Admin password (alias for --password)
  --prefix             User prefix for this utility (default: t#)
  -h, --help           Show this help message

Examples:
  # Interactive mode (menu-driven)
  dart run user_manager.dart

  # Create a new user
  dart run user_manager.dart create-user --username alice --password pass123

  # Get user details
  dart run user_manager.dart get-user --id 5

  # Update user with permissions
  dart run user_manager.dart update-user --id 5 --permissions "read,write" --activate

  # List all users
  dart run user_manager.dart list-users

  # Get user permissions
  dart run user_manager.dart get-user-permissions --id 1

  # Get store configuration
  dart run user_manager.dart get-store-config

  # Script usage with credentials (no interactive prompts)
  dart run user_manager.dart \
    --admin-user admin \
    --admin-password mypass \
    create-user --username alice --password pass123

  # List only utility-created users
  dart run user_manager.dart --admin-user admin --admin-password mypass list-users

  # List all users
  dart run user_manager.dart --admin-user admin --admin-password mypass list-users --all

  # Create user with custom prefix
  dart run user_manager.dart \
    --admin-user admin --admin-password mypass \
    --prefix "script_" \
    create-user --username bob --password pass456
  ''');
}

/// Interactive menu
Future<void> showInteractiveMenu() async {
  while (true) {
    print('\n${'=' * 50}');
    print('CL Server User Manager - Admin Dashboard');
    print('=' * 50);
    print('Logged in as: ${sessionManager.currentUsername}\n');
    print('User Management:');
    print('  1. Create User');
    print('  2. Get User Details');
    print('  3. List Users');
    print('  4. Update User');
    print('  5. Delete User');
    print('  6. Get User Permissions');
    print('\nStore Configuration:');
    print('  7. View Store Config');
    print('  8. Update Read Authentication');
    print('\nOther:');
    print('  9. Logout & Exit');
    print('\nSelect option (1-9): ');

    final choice = stdin.readLineSync() ?? '';

    switch (choice) {
      case '1':
        await createUserInteractive();
      case '2':
        await getUserInteractive();
      case '3':
        await listUsersCommand();
      case '4':
        await updateUserInteractive();
      case '5':
        await deleteUserInteractive();
      case '6':
        await getUserPermissionsInteractive();
      case '7':
        await getStoreConfigCommand();
      case '8':
        await updateReadAuthInteractive();
      case '9':
        await sessionManager.logout();
        print('\n✓ Logged out successfully');
        exit(0);
      default:
        print('Invalid option. Please select 1-9.');
    }
  }
}

/// Create user interactively
Future<void> createUserInteractive() async {
  print('\n--- Create New User ---');

  stdout.write('Username: ');
  final username = stdin.readLineSync() ?? '';
  if (username.isEmpty) {
    print('✗ Username cannot be empty');
    return;
  }

  stdout.write('Password: ');
  try {
    if (stdin.hasTerminal) {
      stdin.echoMode = false;
    }
  } on Exception catch (_) {}
  final password = stdin.readLineSync() ?? '';
  try {
    if (stdin.hasTerminal) {
      stdin.echoMode = true;
    }
  } on Exception catch (_) {}
  if (stdin.hasTerminal) {
    stdout.writeln();
  }

  if (password.isEmpty) {
    print('✗ Password cannot be empty');
    return;
  }

  stdout.write('Is Admin? (y/n, default: n): ');
  final adminInput = stdin.readLineSync()?.toLowerCase() ?? 'n';
  final isAdmin = adminInput == 'y';

  await createUser(
    username: username,
    password: password,
    email: '',
    isAdmin: isAdmin,
  );
}

/// Create user from command line args
Future<void> createUserCommand(List<String> args) async {
  final parser = ArgParser()
    ..addOption('username', help: 'Username')
    ..addOption('password', help: 'Password')
    ..addOption('email', help: 'Email address')
    ..addFlag('admin', help: 'Make user an admin');

  final results = parser.parse(args);

  var username = results['username'] as String? ?? '';
  var password = results['password'] as String? ?? '';
  final email = results['email'] as String? ?? '';
  final isAdmin = results['admin'] as bool;

  if (username.isEmpty) {
    stdout.write('Username: ');
    username = stdin.readLineSync() ?? '';
  }
  if (password.isEmpty) {
    stdout.write('Password: ');
    try {
      if (stdin.hasTerminal) {
        stdin.echoMode = false;
      }
    } on Exception catch (_) {}
    password = stdin.readLineSync() ?? '';
    try {
      if (stdin.hasTerminal) {
        stdin.echoMode = true;
      }
    } on Exception catch (_) {}
    if (stdin.hasTerminal) {
      stdout.writeln();
    }
  }

  await createUser(
    username: username,
    password: password,
    email: email,
    isAdmin: isAdmin,
  );
}

/// Create a new user
Future<void> createUser({
  required String username,
  required String password,
  required String email,
  required bool isAdmin,
}) async {
  print('\n📝 Creating user: $username...');

  try {
    // Create user via user manager
    final result = await userManager.createUser(
      username: username,
      password: password,
      isAdmin: isAdmin,
    );

    if (result.isSuccess) {
      final newUser = result.data as User;
      print('✓ User created successfully!');
      print('  - ID: ${newUser.id}');
      print('  - Username: ${removePrefix(newUser.username)}');
      print('  - Admin: ${newUser.isAdmin ? 'Yes' : 'No'}');
      print('  - Active: ${newUser.isActive ? 'Yes' : 'No'}');
    } else {
      print('✗ ${result.error}');
    }
  } on Exception catch (e) {
    print('✗ Failed to create user: $e');
  }
}

/// Update user interactively
Future<void> updateUserInteractive() async {
  print('\n--- Update User ---');

  // List users first
  await listUsersCommand();

  stdout.write('\nEnter user ID to update: ');
  final userId = int.tryParse(stdin.readLineSync() ?? '') ?? 0;
  if (userId == 0) {
    print('✗ Invalid user ID');
    return;
  }

  stdout.write('New password (leave empty to skip): ');
  try {
    if (stdin.hasTerminal) {
      stdin.echoMode = false;
    }
  } on Exception catch (_) {}
  final newPassword = stdin.readLineSync() ?? '';
  try {
    if (stdin.hasTerminal) {
      stdin.echoMode = true;
    }
  } on Exception catch (_) {}
  if (stdin.hasTerminal) {
    stdout.writeln();
  }

  stdout.write('Update admin status? (y/n/skip): ');
  final adminInput = stdin.readLineSync()?.toLowerCase() ?? 'skip';
  bool? isAdmin;
  if (adminInput == 'y') isAdmin = true;
  if (adminInput == 'n') isAdmin = false;

  stdout.write('Update active status? (y/n/skip): ');
  final activeInput = stdin.readLineSync()?.toLowerCase() ?? 'skip';
  bool? isActive;
  if (activeInput == 'y') isActive = true;
  if (activeInput == 'n') isActive = false;

  await updateUser(
    userId,
    newPassword,
    isAdmin: isAdmin,
    isActive: isActive,
  );
}

/// Update user from command line args
Future<void> updateUserCommand(List<String> args) async {
  final parser = ArgParser()
    ..addOption('id', help: 'User ID')
    ..addOption('password', help: 'New password')
    ..addOption('permissions', help: 'Comma-separated permissions list')
    ..addFlag('admin', help: 'Make user an admin')
    ..addFlag('no-admin', help: 'Remove admin status')
    ..addFlag('activate', help: 'Activate the user')
    ..addFlag('deactivate', help: 'Deactivate the user');

  final results = parser.parse(args);

  final userId = int.tryParse(results['id'] as String? ?? '') ?? 0;
  if (userId == 0) {
    print('✗ User ID is required');
    return;
  }

  final newPassword = results['password'] as String? ?? '';
  final permissionsStr = results['permissions'] as String? ?? '';
  final permissions = permissionsStr.isNotEmpty
      ? permissionsStr.split(',').map((p) => p.trim()).toList()
      : null;

  bool? isAdmin;
  if (results['admin'] as bool) isAdmin = true;
  if (results['no-admin'] as bool) isAdmin = false;

  bool? isActive;
  if (results['activate'] as bool) isActive = true;
  if (results['deactivate'] as bool) isActive = false;

  await updateUser(
    userId,
    newPassword,
    isAdmin: isAdmin,
    isActive: isActive,
    permissions: permissions,
  );
}

/// Update a user
Future<void> updateUser(
  int userId,
  String newPassword, {
  bool? isAdmin,
  bool? isActive,
  List<String>? permissions,
}) async {
  print('\n📝 Updating user ID: $userId...');

  try {
    final result = await userManager.updateUser(
      userId: userId,
      password: newPassword.isNotEmpty ? newPassword : null,
      isAdmin: isAdmin,
      isActive: isActive,
      permissions: permissions,
    );

    if (result.isSuccess) {
      final updatedUser = result.data as User;
      print('✓ User updated successfully!');
      print('  - ID: ${updatedUser.id}');
      print('  - Username: ${removePrefix(updatedUser.username)}');
      print('  - Admin: ${updatedUser.isAdmin ? 'Yes' : 'No'}');
      print('  - Active: ${updatedUser.isActive ? 'Yes' : 'No'}');
    } else {
      print('✗ ${result.error}');
    }
  } on Exception catch (e) {
    print('✗ Failed to update user: $e');
  }
}

/// Delete user interactively
Future<void> deleteUserInteractive() async {
  print('\n--- Delete User ---');

  // List users first
  await listUsersCommand();

  stdout.write('\nEnter user ID to delete: ');
  final userId = int.tryParse(stdin.readLineSync() ?? '') ?? 0;
  if (userId == 0) {
    print('✗ Invalid user ID');
    return;
  }

  stdout.write('Are you sure? (type YES to confirm): ');
  final confirmation = stdin.readLineSync() ?? '';

  if (confirmation != 'YES') {
    print('Cancelled.');
    return;
  }

  await deleteUser(userId);
}

/// Delete user from command line args
Future<void> deleteUserCommand(List<String> args) async {
  final parser = ArgParser()..addOption('id', help: 'User ID');

  final results = parser.parse(args);

  final userId = int.tryParse(results['id'] as String? ?? '') ?? 0;
  if (userId == 0) {
    print('✗ User ID is required');
    return;
  }

  stdout.write('Are you sure? (type YES to confirm): ');
  final confirmation = stdin.readLineSync() ?? '';

  if (confirmation != 'YES') {
    print('Cancelled.');
    return;
  }

  await deleteUser(userId);
}

/// Delete a user
Future<void> deleteUser(int userId) async {
  print('\n🗑️  Deleting user ID: $userId...');

  try {
    // Delete user via user manager
    final result = await userManager.deleteUser(userId: userId);

    if (result.isSuccess) {
      print('✓ User deleted successfully!');
      print('  - User ID: $userId has been removed from the system');
    } else {
      print('✗ ${result.error}');
    }
  } on Exception catch (e) {
    print('✗ Failed to delete user: $e');
  }
}

/// List users, filtering by default to show only utility-created users
/// Use --all flag to show all users
Future<void> listUsersCommand([List<String> args = const []]) async {
  final parser = ArgParser()
    ..addFlag(
      'all',
      help: 'Show all users (default shows only utility-created users)',
    );

  final results = parser.parse(args);
  final showAll = results['all'] as bool;

  print('\n📋 Fetching users...');

  try {
    final result = await userManager.listUsers(
      options: UserListOptions(
        showAll: showAll,
      ),
    );

    if (!result.isSuccess) {
      print('✗ ${result.error}');
      return;
    }

    final displayedUsers = result.data as List;

    print('\n${'=' * 70}');
    final title = showAll ? 'All Users' : 'Utility-Created Users';
    print(title);
    print('=' * 70);

    if (displayedUsers.isEmpty) {
      print('No users found.');
      if (!showAll) {
        print('(Use --all to see all users)');
      }
    } else {
      // Print header
      print(
        '${padRight('ID', 5)} | ${padRight('Username', 20)} '
        '| ${padRight('Status', 15)} | Admin',
      );
      print('-' * 70);

      for (final user in displayedUsers.map((e) => e as User)) {
        final adminBadge = user.isAdmin ? '✓ Yes' : 'No';
        final status = user.isActive ? '✓ Active' : '✗ Inactive';
        final displayUsername = removePrefix(user.username);
        final marker = isUtilityCreatedUser(user.username) ? '*' : '';
        print(
          '${padRight(user.id.toString(), 5)} '
          '| ${padRight('$displayUsername$marker', 20)} '
          '| ${padRight(status, 15)} | $adminBadge',
        );
      }

      print('-' * 70);
      print('Total: ${displayedUsers.length} users');
      if (!showAll && displayedUsers.length < (result.data as List).length) {
        print(
          '(Showing utility-created users only. Use --all to see all '
          '${(result.data as List).length} users)',
        );
      }
    }
  } on Exception catch (e) {
    print('✗ Failed to fetch users: $e');
  }
}

/// Get user details interactively
Future<void> getUserInteractive() async {
  print('\n--- Get User Details ---');

  stdout.write('Enter user ID: ');
  final userId = int.tryParse(stdin.readLineSync() ?? '') ?? 0;
  if (userId == 0) {
    print('✗ Invalid user ID');
    return;
  }

  await getUser(userId);
}

/// Get user details from command line args
Future<void> getUserCommand(List<String> args) async {
  final parser = ArgParser()..addOption('id', help: 'User ID');

  final results = parser.parse(args);
  final userId = int.tryParse(results['id'] as String? ?? '') ?? 0;

  if (userId == 0) {
    print('✗ User ID is required');
    return;
  }

  await getUser(userId);
}

/// Get user details
Future<void> getUser(int userId) async {
  print('\n👤 Fetching user ID: $userId...');

  try {
    final result = await userManager.getUser(userId: userId);

    if (result.isSuccess) {
      final user = result.data as User;
      print('\n${'=' * 70}');
      print('User Details');
      print('=' * 70);
      print('ID: ${user.id}');
      print('Username: ${removePrefix(user.username)}');
      print('Admin: ${user.isAdmin ? 'Yes' : 'No'}');
      print('Active: ${user.isActive ? 'Yes' : 'No'}');
      print('=' * 70);
    } else {
      print('✗ ${result.error}');
    }
  } on Exception catch (e) {
    print('✗ Failed to fetch user: $e');
  }
}

/// Get user permissions interactively
Future<void> getUserPermissionsInteractive() async {
  print('\n--- Get User Permissions ---');

  stdout.write('Enter user ID: ');
  final userId = int.tryParse(stdin.readLineSync() ?? '') ?? 0;
  if (userId == 0) {
    print('✗ Invalid user ID');
    return;
  }

  await getUserPermissions(userId);
}

/// Get user permissions from command line args
Future<void> getUserPermissionsCommand(List<String> args) async {
  final parser = ArgParser()..addOption('id', help: 'User ID');

  final results = parser.parse(args);
  final userId = int.tryParse(results['id'] as String? ?? '') ?? 0;

  if (userId == 0) {
    print('✗ User ID is required');
    return;
  }

  await getUserPermissions(userId);
}

/// Get user permissions
Future<void> getUserPermissions(int userId) async {
  print('\n🔑 Fetching permissions for user ID: $userId...');

  try {
    final result = await userManager.getUserPermissions(userId: userId);

    if (result.isSuccess) {
      // Get user details to show username alongside permissions
      final userResult = await userManager.getUser(userId: userId);
      final username = userResult.isSuccess
          ? removePrefix((userResult.data as User).username)
          : 'Unknown';

      final permissions = result.data as List<String>;
      print('\n${'=' * 70}');
      print('User: $username (ID: $userId)');
      print('=' * 70);
      print('Permissions:');
      if (permissions.isEmpty) {
        print('  (none)');
      } else {
        for (final perm in permissions) {
          print('  - $perm');
        }
      }
      print('=' * 70);
    } else {
      print('✗ ${result.error}');
    }
  } on Exception catch (e) {
    print('✗ Failed to fetch user permissions: $e');
  }
}

/// Get store configuration
Future<void> getStoreConfigCommand() async {
  print('\n📋 Fetching Store Configuration...');

  try {
    final result = await userManager.getStoreConfig();

    if (result.isSuccess) {
      final config = result.data as StoreConfig;
      print('\n${'=' * 70}');
      print('Store Configuration');
      print('=' * 70);
      final readAuthStatus = config.readAuthEnabled ? 'Enabled' : 'Disabled';
      print('Read Authentication: $readAuthStatus');
      print('Last Updated: ${config.updatedAt}');
      if (config.updatedBy != null) {
        print('Updated By: ${config.updatedBy}');
      }
      print('=' * 70);
    } else {
      print('✗ ${result.error}');
      print(
        '⚠️  Note: /admin/config endpoint may not be implemented on the server',
      );
    }
  } on Exception catch (e) {
    print('✗ Failed to fetch store configuration: $e');
    print(
      '⚠️  Note: /admin/config endpoint may not be implemented on the server',
    );
  }
}

/// Update read authentication in store interactively
Future<void> updateReadAuthInteractive() async {
  print('\n--- Update Read Authentication Control ---');

  // Show current config first
  try {
    final configResult = await userManager.getStoreConfig();
    if (configResult.isSuccess) {
      final currentConfig = configResult.data as StoreConfig;
      print(
        'Current Read Authentication: '
        '${currentConfig.readAuthEnabled ? 'Enabled' : 'Disabled'}',
      );

      stdout.write('\nEnable read authentication? (y/n): ');
      final input = stdin.readLineSync()?.toLowerCase() ?? 'n';
      final enabled = input == 'y';

      await updateReadAuthConfig(enabled: enabled);
    } else {
      print('✗ Error: ${configResult.error}');
    }
  } on Exception catch (e) {
    print('✗ Error: $e');
  }
}

/// Update read authentication in store from command line args
Future<void> updateReadAuthCommand(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('enable', help: 'Enable read authentication')
    ..addFlag('disable', help: 'Disable read authentication');

  try {
    final results = parser.parse(args);
    final enableFlag = results['enable'] as bool;
    final disableFlag = results['disable'] as bool;

    if (enableFlag && disableFlag) {
      print('✗ Cannot specify both --enable and --disable');
      return;
    }

    if (!enableFlag && !disableFlag) {
      // Show current config and prompt
      await updateReadAuthInteractive();
      return;
    }

    await updateReadAuthConfig(enabled: enableFlag);
  } on Exception catch (e) {
    print('✗ Error parsing arguments: $e');
  }
}

/// Update read auth configuration in store
Future<void> updateReadAuthConfig({required bool enabled}) async {
  print('\n⚙️  Updating read authentication configuration...');

  try {
    final result = await userManager.updateReadAuth(enabled: enabled);

    if (result.isSuccess) {
      final updatedConfig = result.data as StoreConfig;
      print('✓ Read authentication updated successfully!');
      final status = updatedConfig.readAuthEnabled ? 'Enabled' : 'Disabled';
      print('  - Status: $status');
      print('  - Updated At: ${updatedConfig.updatedAt}');
      if (updatedConfig.updatedBy != null) {
        print('  - Updated By: ${updatedConfig.updatedBy}');
      }
    } else {
      print('✗ ${result.error}');
      print('⚠️  Note: /admin/config/read-auth endpoint may not be fully'
          ' implemented on the server');
    }
  } on Exception catch (e) {
    print('✗ Failed to update read authentication: $e');
    print('⚠️  Note: /admin/config/read-auth endpoint may not be fully'
        ' implemented on the server');
  }
}

/// Helper function to pad strings for display
String padRight(String str, int width) {
  if (str.length >= width) return str.substring(0, width);
  return str + ' ' * (width - str.length);
}
