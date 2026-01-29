#!/bin/bash

# Configuration
export CL_AUTH_URL=${CL_AUTH_URL:-"http://localhost:8010"}
export CL_COMPUTE_URL=${CL_COMPUTE_URL:-"http://localhost:8012"}
export CL_STORE_URL=${CL_STORE_URL:-"http://localhost:8011"}
export CL_USERNAME=${CL_USERNAME:-"admin"}
export CL_PASSWORD=${CL_PASSWORD:-"admin"}

echo "Running Integration Tests with:"
echo "  Auth:    $CL_AUTH_URL"
echo "  Compute: $CL_COMPUTE_URL"
echo "  Store:   $CL_STORE_URL"
echo "  User:    $CL_USERNAME"

dart test -j 1 test
