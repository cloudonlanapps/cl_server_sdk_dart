import 'dart:convert';

import 'package:http/http.dart' as http;

import 'test_config_loader.dart';

/// Server capabilities detected at runtime
class ServerCapabilities {
  const ServerCapabilities({
    required this.authRequired,
    required this.guestMode,
    required this.availableTasks,
  });

  /// Whether compute service requires authentication
  final bool authRequired;

  /// Store guest mode setting: "on" or "off"
  final String guestMode;

  /// Available task types from workers
  final List<String> availableTasks;

  /// Detect server capabilities by querying endpoints
  static Future<ServerCapabilities> detect(TestConfig config) async {
    bool authRequired = true;
    String guestMode = 'off';
    List<String> availableTasks = [];

    try {
      // Get compute service info
      final computeResponse = await http.get(
        Uri.parse(config.computeUrl),
      );

      if (computeResponse.statusCode == 200) {
        final computeInfo = jsonDecode(computeResponse.body) as Map<String, dynamic>;
        authRequired = computeInfo['auth_required'] as bool? ?? true;

        // Get available tasks from workers
        try {
          final workersResponse = await http.get(
            Uri.parse('${config.computeUrl}/workers'),
          );

          if (workersResponse.statusCode == 200) {
            final workersData = jsonDecode(workersResponse.body) as Map<String, dynamic>;
            final workers = workersData['workers'] as List<dynamic>? ?? [];

            final tasksSet = <String>{};
            for (final worker in workers) {
              final tasks = worker['available_tasks'] as List<dynamic>? ?? [];
              tasksSet.addAll(tasks.map((t) => t as String));
            }
            availableTasks = tasksSet.toList()..sort();
          }
        } catch (e) {
          // Workers endpoint might not exist, use empty list
          availableTasks = [];
        }
      }
    } catch (e) {
      // Compute service not available or error - assume auth required
      authRequired = true;
    }

    try {
      // Get store service info
      final storeResponse = await http.get(
        Uri.parse(config.storeUrl),
      );

      if (storeResponse.statusCode == 200) {
        final storeInfo = jsonDecode(storeResponse.body) as Map<String, dynamic>;
        guestMode = storeInfo['guestMode'] as String? ?? 'off';
      }
    } catch (e) {
      // Store service not available or error - assume guest mode off
      guestMode = 'off';
    }

    return ServerCapabilities(
      authRequired: authRequired,
      guestMode: guestMode,
      availableTasks: availableTasks,
    );
  }
}
