#!/bin/bash -el

RES_FILE=$(pwd -P)/test_results.json

echo "=== Check 16384_2048_1_debug ==="
RUNTIME_MODE="debug" NANOS6_CONFIG_OVERRIDE="version.debug=true" timeout --preserve-status 300s ./build/nbody-d -p 16384 -t 1 -c -S
cat test_result.json >>$RES_FILE
echo "," >>$RES_FILE

echo "=== Check 8192_2048_50_debug ==="
RUNTIME_MODE="debug" NANOS6_CONFIG_OVERRIDE="version.debug=true" timeout --preserve-status 300s ./build/nbody-d -p 16384 -t 10 -c -S
cat test_result.json >>$RES_FILE
echo "," >>$RES_FILE

echo "=== Check 32768_2048_32_perf ==="
RUNTIME_MODE="perf" timeout --preserve-status 60s ./build/nbody-p -p 32768 -t 32 -S
cat test_result.json >>$RES_FILE
echo "," >>$RES_FILE

