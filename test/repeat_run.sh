#!/bin/bash
# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Root of the Dart SDK (one level up from test/ directory)
SDK_ROOT="$(dirname "$SCRIPT_DIR")"

LOG_FILE="$SDK_ROOT/run_all.log"

# Clear the log file before starting
: > "$LOG_FILE"

# Configuration
export CL_AUTH_URL=${CL_AUTH_URL:-"http://localhost:8010"}
export CL_COMPUTE_URL=${CL_COMPUTE_URL:-"http://localhost:8012"}
export CL_STORE_URL=${CL_STORE_URL:-"http://localhost:8011"}
export CL_USERNAME=${CL_USERNAME:-"admin"}
export CL_PASSWORD=${CL_PASSWORD:-"admin"}

echo "Running Integration Tests with:" >> "$LOG_FILE"
echo "  Auth:    $CL_AUTH_URL" >> "$LOG_FILE"
echo "  Compute: $CL_COMPUTE_URL" >> "$LOG_FILE"
echo "  Store:   $CL_STORE_URL" >> "$LOG_FILE"
echo "  User:    $CL_USERNAME" >> "$LOG_FILE"

# Change to SDK root so relative paths like test/integration/... work
cd "$SDK_ROOT"

for i in $(seq 1 10); do
  echo "==================================================" >> "$LOG_FILE"
  echo "Run $i started at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
  echo "==================================================" >> "$LOG_FILE"

  # Run the test
  dart test test/integration/test_full_embedding_flow_test.dart -j 1  >> "$LOG_FILE" 2>&1
  
  if [ $? -ne 0 ]; then
    echo "Run $i FAILED." | tee -a "$LOG_FILE"
    # Optional: break on failure
    # break
  else
    echo "Run $i PASSED." | tee -a "$LOG_FILE"
  fi
  
  echo "Run $i finished at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
  echo >> "$LOG_FILE"
done

# Show the summary info from the log
echo "Summary of runs:"
grep -E "PASSED|FAILED" "$LOG_FILE"
grep -E "All tests passed|Some tests failed" "$LOG_FILE"

