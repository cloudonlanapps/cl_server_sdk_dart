#!/bin/bash

# Default values
SERVER_IP="localhost"
EXTRA_ARGS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --ip)
      SERVER_IP="$2"
      shift # past argument
      shift # past value
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift # past argument
      ;;
  esac
done

# Configuration
export CL_AUTH_URL=${CL_AUTH_URL:-"http://${SERVER_IP}:8010"}
export CL_COMPUTE_URL=${CL_COMPUTE_URL:-"http://${SERVER_IP}:8012"}
export CL_STORE_URL=${CL_STORE_URL:-"http://${SERVER_IP}:8011"}
export CL_USERNAME=${CL_USERNAME:-"admin"}
export CL_PASSWORD=${CL_PASSWORD:-"admin"}
# MQTT Configuration
export CL_MQTT_BROKER=${CL_MQTT_BROKER:-"${SERVER_IP}"}
export CL_MQTT_PORT=${CL_MQTT_PORT:-"1883"}
export CL_MQTT_URL=${CL_MQTT_URL:-"mqtt://${SERVER_IP}:1883"}

echo "Running Integration Tests with:"
echo "  Auth:    $CL_AUTH_URL"
echo "  Compute: $CL_COMPUTE_URL"
echo "  Store:   $CL_STORE_URL"
echo "  MQTT:    $CL_MQTT_BROKER:$CL_MQTT_PORT"
echo "  User:    $CL_USERNAME"

# Run tests
dart test -j 1 "${EXTRA_ARGS[@]}" -r expanded

