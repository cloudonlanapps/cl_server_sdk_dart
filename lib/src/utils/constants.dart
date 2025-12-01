/// Default service base URLs
const String authServiceBaseUrl = 'http://localhost:8000';
const String storeServiceBaseUrl = 'http://localhost:8001';
const String computeServiceBaseUrl = 'http://localhost:8002';

/// Auth Service Endpoints
class AuthServiceEndpoints {
  static const String health = '/';
  static const String generateToken = '/auth/token';
  static const String refreshToken = '/auth/token/refresh';
  static const String getPublicKey = '/auth/public-key';
  static const String getCurrentUser = '/users/me';
  static const String listUsers = '/users/';
  static const String getUser = '/users/{user_id}';
  static const String createUser = '/users/';
  static const String updateUser = '/users/{user_id}';
  static const String deleteUser = '/users/{user_id}';
}

/// Store Service Endpoints
class StoreServiceEndpoints {
  static const String health = '/';
  static const String listEntities = '/entity/';
  static const String createEntity = '/entity/';
  static const String getEntity = '/entity/{entity_id}';
  static const String updateEntity = '/entity/{entity_id}';
  static const String patchEntity = '/entity/{entity_id}';
  static const String deleteEntity = '/entity/{entity_id}';
  static const String deleteCollection = '/entity/collection';
  static const String getVersions = '/entity/{entity_id}/versions';
  static const String getConfig = '/admin/config';
  static const String updateReadAuthConfig = '/admin/config/read-auth';
}

/// Compute Service Endpoints
class ComputeServiceEndpoints {
  static const String createJob = '/api/v1/job/{task_type}';
  static const String getJobStatus = '/api/v1/job/{job_id}';
  static const String deleteJob = '/api/v1/job/{job_id}';
  static const String listWorkers = '/api/v1/workers';
  static const String getWorkerStatus = '/api/v1/workers/status/{worker_id}';
  static const String getStorageSize = '/api/v1/admin/storage/size';
  static const String cleanupOldJobs = '/api/v1/admin/cleanup';
}

/// HTTP Headers
class HttpHeaders {
  static const String contentType = 'content-type';
  static const String authorization = 'authorization';
  static const String applicationJson = 'application/json';
  static const String applicationFormUrlEncoded = 'application/x-www-form-urlencoded';
}

/// Common Query Parameters
class QueryParameters {
  static const String page = 'page';
  static const String pageSize = 'page_size';
  static const String skip = 'skip';
  static const String limit = 'limit';
  static const String version = 'version';
  static const String searchQuery = 'search_query';
  static const String days = 'days';
}
