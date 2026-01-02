#!/bin/bash

# Simple single-scenario test runner for debugging
# Usage: ./run_single_test.sh [auth_mode]
# Example: ./run_single_test.sh admin

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
AUTH_MODE="${1:-admin}"
TEST_DIR="/Users/anandasarangaram/Work/cl_server/sdks/dartsdk"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Running Single Test Scenario${NC}"
echo -e "${BLUE}Auth Mode: ${AUTH_MODE}${NC}"
echo -e "${BLUE}========================================${NC}"

# Set environment variable
export TEST_AUTH_MODE="${AUTH_MODE}"

# Update test config with current URLs
export TEST_AUTH_URL="http://localhost:8010"
export TEST_COMPUTE_URL="http://localhost:8012"
export TEST_STORE_URL="http://localhost:8011"

echo ""
echo -e "${BLUE}Running tests with auth mode: ${AUTH_MODE}${NC}"
echo ""

# Run a single test file first to check if it works
cd "${TEST_DIR}"
dart test test/integration/store_integration_test.dart --reporter=expanded

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Tests passed for auth mode: ${AUTH_MODE}${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}✗ Tests failed for auth mode: ${AUTH_MODE}${NC}"
    exit 1
fi
