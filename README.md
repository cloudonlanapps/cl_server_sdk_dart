# CL Server Dart Client

A comprehensive Dart client library for interacting with CL Server microservices. This package provides type-safe clients for three core services:

- **Authentication Service** (Port 8000) - User management and token generation
- **Store Service** (Port 8001) - Entity and collection management
- **Compute Service** (Port 8002) - Job and worker management

## Features

- ✨ Three fully-featured service clients (Auth, Store, Compute)
- 🔒 Custom exception hierarchy for comprehensive error handling
- 📦 Immutable data models with full serialization support
- 🧪 120+ unit tests with excellent coverage
- 🎯 SessionManager for automatic token lifecycle management
- 📝 No code generation required (manual implementation)
- 🚀 Type-safe async/await API
- 🔌 HTTP client wrapper with intelligent error mapping
- 💾 Built-in token persistence and encryption
- ⚡ Automatic token refresh with configurable strategies
- 🎨 **9 Plugin Clients**: CLIP, DINO, EXIF, Face Detection, Face Embedding, Hash, HLS Streaming, Image Conversion, Media Thumbnail
- 📡 **MQTT Real-time Monitoring**: Primary workflow for job status tracking
- 🔄 **HTTP Polling**: Secondary workflow as fallback
- 👥 **UserManager Module**: High-level user management with command pattern architecture
- 🏪 **StoreManager Module**: High-level store entity management API

## Unique Features

This SDK includes some features not yet present in the Python SDK:

- **UserManager Module**: High-level user management API with command pattern architecture
- **StoreManager Module**: High-level store entity management API
- **User Prefixing System**: Automatic prefixing for utility-created users (prevents namespace conflicts)
- **Command Pattern**: Clean architecture for store and user operations with Result wrapper pattern
- **Dual Workflow Architecture**: MQTT primary workflow with HTTP polling fallback

See [PYSDK_ADOPTION.md](./PYSDK_ADOPTION.md) for details on these features and recommendations for adopting them in the Python SDK.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  cl_server_dart_client: ^0.1.0
```

## Getting started

### Basic Usage

```dart
import 'package:cl_server_dart_client/cl_server_dart_client.dart';

// Create auth service client
final authService = AuthService();

// Login to get token
try {
  final token = await authService.generateToken(
    username: 'admin',
    password: 'admin',
  );

  // Use token with store service
  final storeService = StoreService(token: token.accessToken);

  // List entities
  final entities = await storeService.listEntities();
  print('Found ${entities.items.length} entities');
} on AuthException catch (e) {
  print('Authentication failed: $e');
} on ServerException catch (e) {
  print('Server error: $e');
}
```

### Service Clients

#### AuthService

Manage users and generate authentication tokens.

```dart
final authService = AuthService(baseUrl: 'http://localhost:8000');

// Generate token
final token = await authService.generateToken(
  username: 'user',
  password: 'password',
);

// Get current user
final user = await authService.getCurrentUser();

// List all users (admin only)
final users = await authService.listUsers(skip: 0, limit: 100);
```

#### StoreService

Manage entities and collections.

```dart
final storeService = StoreService(
  baseUrl: 'http://localhost:8001',
  token: authToken,
);

// List entities with pagination
final response = await storeService.listEntities(
  page: 1,
  pageSize: 20,
);

// Create entity
final entity = await storeService.createEntity(
  isCollection: false,
  label: 'My File',
  description: 'A test file',
);

// Get entity versions
final versions = await storeService.getVersions(entity.id);
```

#### ComputeService

Manage compute jobs and workers with 9 plugin clients.

```dart
final computeService = ComputeService(
  baseUrl: 'http://localhost:8002',
  token: authToken,
);

// Use plugin clients for typed operations
final job = await computeService.clipEmbedding.embedImage(
  image: File('photo.jpg'),
  wait: true,  // Use HTTP polling
  timeout: Duration(seconds: 30),
);

// Or use MQTT for real-time monitoring
final mqttService = MqttService(
  brokerUrl: 'localhost',
  brokerPort: 1883,
);
await mqttService.connect();

final job2 = await computeService.clipEmbedding.embedImage(
  image: File('photo.jpg'),
  onProgress: (status) => print('Progress: ${status.progress}%'),
  onComplete: (status) async {
    final fullJob = await computeService.getJob(status.jobId);
    print('Result: ${fullJob.taskOutput}');
  },
);

// Available plugins:
// - clipEmbedding (512-dim CLIP embeddings)
// - dinoEmbedding (384-dim DINO embeddings)
// - exif (EXIF metadata extraction)
// - faceDetection (Face detection with bounding boxes)
// - faceEmbedding (128-dim face embeddings)
// - hash (Perceptual hashing - phash, dhash)
// - hlsStreaming (HLS manifest generation)
// - imageConversion (Format conversion with quality control)
// - mediaThumbnail (Thumbnail generation)

// Legacy: Create job manually
final manualJob = await computeService.createJob(
  taskType: 'clip_embedding',
  metadata: {'width': 800, 'height': 600},
);

// Get job status
final status = await computeService.getJobStatus(manualJob.jobId);

// List workers
final workers = await computeService.listWorkers();
```

## Error Handling

The client uses a custom exception hierarchy for clear error handling:

- `AuthException` - Authentication failed (401)
- `PermissionException` - Insufficient permissions (403)
- `ValidationException` - Invalid request data (422)
- `ResourceNotFoundException` - Resource not found (404)
- `ServerException` - Server error (5xx)
- `NetworkException` - Network/connection errors

```dart
try {
  final user = await authService.getUser(999);
} on ResourceNotFoundException catch (e) {
  print('User not found: $e');
} on AuthException catch (e) {
  print('Not authenticated: $e');
} on CLServerException catch (e) {
  print('Client error: $e');
}
```

## Data Models

All models are immutable and include full serialization support:

```dart
// Models support fromJson/toJson
final json = {'id': 1, 'username': 'admin'};
final user = User.fromJson(json);

// Models support fromMap/toMap
final map = user.toMap();

// Models support copyWith for immutable updates
final updatedUser = user.copyWith(username: 'newadmin');
```

## Token Management

### SessionManager (Recommended)

For most applications, use the `SessionManager` which provides automatic token lifecycle management:

```dart
import 'package:cl_server_dart_client/cl_server_dart_client.dart';

// Initialize session manager (creates storage, auth service, and notifier)
final sessionManager = SessionManager.initialize();

// Login with credentials
try {
  await sessionManager.login('admin', 'admin');
  print('Logged in as: ${sessionManager.currentUsername}');
} on AuthException catch (e) {
  print('Login failed: $e');
}

// Access current session state
if (sessionManager.isLoggedIn) {
  print('User: ${sessionManager.currentUsername}');
  print('State: ${sessionManager.currentState}');
}

// Get valid token (auto-refreshes if needed)
final token = await sessionManager.getValidToken();

// Create pre-authenticated services
final storeService = await sessionManager.createStoreService();
final computeService = await sessionManager.createComputeService();

// Use services with automatic token injection
final entities = await storeService.listEntities();

// Listen to session state changes
sessionManager.onSessionStateChanged((state) {
  print('Session changed: logged_in=${state.isLoggedIn}');
});

// Logout when done
await sessionManager.logout();

// Cleanup
await sessionManager.dispose();
```

### SessionManager Features

- **Token Persistence**: Automatically stores token in-memory (or extend for persistent storage)
- **Token Refresh**: Automatic refresh with 1-minute threshold before expiry
- **Reactive Updates**: Uses Solidart signals for reactive state management
- **Password Encryption**: Optional password storage with AES encryption
- **Configurable Strategies**: `refreshEndpoint` or `reLogin` refresh strategies
- **Single User**: Manages a single logged-in user at a time

### Manual Token Management

If you prefer manual control, you can use stateless clients:

```dart
class TokenManager {
  String? _token;

  Future<String> getValidToken() async {
    if (_token == null) {
      final response = await AuthService().generateToken(
        username: 'user',
        password: 'pass',
      );
      _token = response.accessToken;
    }
    return _token!;
  }
}

final tokenManager = TokenManager();
final storeService = StoreService(token: await tokenManager.getValidToken());
```

### SessionManager Configuration

Configure token refresh strategy:

```dart
// Use token refresh endpoint (recommended)
sessionManager.setRefreshStrategy(TokenRefreshStrategy.refreshEndpoint);

// Or use re-login strategy (stores encrypted password)
sessionManager.setRefreshStrategy(TokenRefreshStrategy.reLogin);
```

### JWT Token Parsing

For manual token handling, the library includes JWT utilities:

```dart
import 'package:cl_server_dart_client/cl_server_dart_client.dart';

final token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

// Parse JWT token (no signature verification)
final payload = JwtUtils.parseToken(token);

if (payload != null) {
  print('User: ${payload.userId}');
  print('Permissions: ${payload.permissions}');
  print('Is Admin: ${payload.isAdmin}');

  // Check if token expires within 1 minute
  if (payload.expiresWithin(const Duration(minutes: 1))) {
    print('Token will expire soon');
  }

  // Get time remaining
  final remaining = payload.timeRemaining;
  print('Time remaining: ${remaining?.inMinutes} minutes');
}
```

## Testing

The package includes comprehensive unit tests (120+ tests) covering:

- All service clients and their endpoints
- Model serialization/deserialization
- Exception handling
- HTTP client error mapping
- Session management (token storage, JWT parsing, refresh)
- SessionManager lifecycle and state management
- Token persistence and encryption

Run tests with:

```bash
dart test
```

## Known Limitations

- **In-memory token storage**: TokenStorage uses in-memory cache by default. Extend it to use `shared_preferences` or `flutter_secure_storage` for persistent storage in Flutter apps
- **No built-in caching**: Response caching should be implemented at the application level
- **JWT signature verification disabled**: Tokens are parsed but signatures are not verified (trusted tokens from server)
- **Single user session**: SessionManager manages only one logged-in user at a time
- **Integration tests deferred**: Full integration tests with running services are planned

## Code Quality

This package adheres to the `very_good_analysis` lint rules and passes all linting checks without warnings. The code is 100% documented with no public members lacking documentation comments.

## Additional Information

### Architecture

The library follows a layered architecture:

- **Core Layer**: HTTP client, exceptions, base models
- **Models Layer**: Immutable data classes with serialization
- **Services Layer**: Service clients wrapping API endpoints

Each service is independent and can be used separately.

### Architecture Updates (Phase 2)

Phase 2 adds the Session Layer for automatic token lifecycle management:

- **SessionManager**: High-level facade for session management
- **SessionNotifier**: Reactive state management using Solidart signals
- **TokenStorage**: In-memory token persistence with optional encryption
- **JwtUtils**: JWT token parsing without verification
- **SessionExceptions**: Domain-specific exceptions for session operations

### Contributing

Future phases will include:
- Integration tests with running services
- Persistent storage adapters (shared_preferences, flutter_secure_storage)
- Request/response caching strategies
- Advanced error recovery strategies
- Multi-user session management

### Version

Current version: **0.1.0** (Phase 2 - Session Management Layer)

**Phase History:**
- **Phase 1**: Core client implementation (Auth, Store, Compute services)
- **Phase 2** (Current): Session management layer with token lifecycle
