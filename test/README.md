# Dart SDK Tests

This directory contains unit and integration tests for the cl_server Dart SDK.

## Running Tests

All tests are run using the standard `dart test` tool.

### Unit Tests

To run all unit tests:

```bash
dart test
```

To run a specific test file:

```bash
dart test test/auth_test.dart
```

### Integration Tests

Integration tests require a running server and are configured via environment variables.

To run integration tests:

```bash
# Set environment variables for your server
export CL_AUTH_URL=http://localhost:8010
export CL_COMPUTE_URL=http://localhost:8012
export CL_STORE_URL=http://localhost:8011
export CL_USERNAME=admin
export CL_PASSWORD=admin

# Run integration tests
dart test test/integration/
```

### Alternative: Using Environment Variables in a single command

If you prefer not to export variables, you can provide them directly to the `dart test` command (on Unix-like systems):

```bash
CL_AUTH_URL=http://localhost:8010 \
CL_COMPUTE_URL=http://localhost:8012 \
CL_STORE_URL=http://localhost:8011 \
CL_USERNAME=admin \
CL_PASSWORD=admin \
dart test test/integration/
```

> [!NOTE]
> `dart test` does not currently support the `--define` or `--dart-define` flags for VM-based tests. Environment variables are the standard way to configure these tests.


## Linting

To check for linting issues:

```bash
dart analyze
```
