/// Dart client library for CL Server microservices.
///
/// Provides clients for interacting with three CL Server services:
/// - Authentication Service (Port 8000)
/// - Store Service (Port 8001)
/// - Compute Service (Port 8002)
///
/// Example usage:
/// ```dart
/// import 'package:cl_server_dart_client/cl_server_dart_client.dart';
///
/// // Create auth service client
/// final authService = AuthService();
///
/// // Login
/// final token = await authService.generateToken(
///   username: 'admin',
///   password: 'admin',
/// );
///
/// // Create store service client with token
/// final storeService = StoreService(token: token.accessToken);
///
/// // List entities
/// final entities = await storeService.listEntities();
/// ```
// ignore_for_file: directives_ordering

library;

// Core exceptions
export 'src/core/exceptions.dart';

// Core HTTP client
export 'src/core/http_client.dart';

// Core models
export 'src/core/models/base_response.dart';
export 'src/core/models/auth_models.dart';
export 'src/core/models/store_models.dart';
export 'src/core/models/compute_models.dart';

// Services
export 'src/services/auth_service.dart';
export 'src/services/store_service.dart';
export 'src/services/compute_service.dart';

// Session management
export 'src/session/session_manager.dart';
export 'src/session/session_notifier.dart';
export 'src/session/session_state.dart';
export 'src/session/session_exceptions.dart';
export 'src/session/token_storage.dart';
export 'src/session/utils/jwt_utils.dart';

// Constants
export 'src/utils/constants.dart';
