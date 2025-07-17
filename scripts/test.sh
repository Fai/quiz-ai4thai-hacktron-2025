#!/bin/bash

# Time Service API Test Script
# This script tests all endpoints and validates responses

set -e

BASE_URL_API1="http://localhost:3000"
BASE_URL_API2="http://localhost:4000"

echo "🧪 Starting Time Service API Tests..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run test
run_test() {
    local test_name="$1"
    local url="$2"
    local expected_status="$3"

    echo -n "Testing $test_name... "

    response=$(curl -s -w "%{http_code}" -o /tmp/response.json "$url")
    status_code="${response: -3}"

    if [ "$status_code" -eq "$expected_status" ]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC} (Expected: $expected_status, Got: $status_code)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to validate JSON response
validate_json() {
    local test_name="$1"
    local required_fields="$2"

    echo -n "Validating $test_name JSON structure... "

    for field in $required_fields; do
        if ! jq -e ".$field" /tmp/response.json >/dev/null 2>&1; then
            echo -e "${RED}FAIL${NC} (Missing field: $field)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    done

    echo -e "${GREEN}PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
}

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
for i in {1..30}; do
    if curl -s "$BASE_URL_API1/health" >/dev/null 2>&1 && \
       curl -s "$BASE_URL_API2/health" >/dev/null 2>&1; then
        break
    fi
    echo -n "."
    sleep 1
done
echo

# Test API1 Health Check
run_test "API1 Health Check" "$BASE_URL_API1/health" 200
validate_json "API1 Health" "status service timestamp"

# Test API2 Health Check
run_test "API2 Health Check" "$BASE_URL_API2/health" 200
validate_json "API2 Health" "status service timestamp"

# Test API1 Root Endpoint
run_test "API1 Root" "$BASE_URL_API1/" 200

# Test API2 Root Endpoint
run_test "API2 Root" "$BASE_URL_API2/" 200

# Test API1 Time Endpoint (Default UTC)
run_test "API1 Time (UTC)" "$BASE_URL_API1/time" 200
validate_json "API1 Time" "timestamp timezone request_id source"

# Test API1 Time Endpoint with EST timezone
run_test "API1 Time (EST)" "$BASE_URL_API1/time?timezone=EST" 200
validate_json "API1 Time EST" "timestamp timezone request_id source"

# Test API1 Time Endpoint with PST timezone
run_test "API1 Time (PST)" "$BASE_URL_API1/time?timezone=PST" 200
validate_json "API1 Time PST" "timestamp timezone request_id source"

# Test API2 Time Endpoint Directly
run_test "API2 Time Direct" "$BASE_URL_API2/time" 200
validate_json "API2 Time" "timestamp timezone request_id source"

# Test API2 Time Endpoint with timezone
run_test "API2 Time (CET)" "$BASE_URL_API2/time?timezone=CET" 200
validate_json "API2 Time CET" "timestamp timezone request_id source"

# Test invalid timezone (should still work, default to UTC)
run_test "API1 Invalid Timezone" "$BASE_URL_API1/time?timezone=INVALID" 200

# Test HTTPS endpoints (if available)
if curl -k -s "https://localhost:3443/health" >/dev/null 2>&1; then
    run_test "API1 HTTPS Health" "https://localhost:3443/health" 200
fi

if curl -k -s "https://localhost:4443/health" >/dev/null 2>&1; then
    run_test "API2 HTTPS Health" "https://localhost:4443/health" 200
fi

# Performance test
echo "🚀 Running basic performance test..."
start_time=$(date +%s%N)
for i in {1..100}; do
    curl -s "$BASE_URL_API1/time" >/dev/null
done
end_time=$(date +%s%N)
duration=$((($end_time - $start_time) / 1000000))
avg_latency=$((duration / 100))

echo "Performance: 100 requests completed in ${duration}ms (avg: ${avg_latency}ms per request)"

# Load test with multiple concurrent requests
echo "🔄 Running concurrent request test..."
for i in {1..10}; do
    curl -s "$BASE_URL_API1/time" >/dev/null &
done
wait

echo "Concurrent requests test completed"

# Check for proper source attribution
echo "🔍 Validating API flow..."
response=$(curl -s "$BASE_URL_API1/time")
source=$(echo "$response" | jq -r '.source')
if [ "$source" = "api1->api2" ]; then
    echo -e "API Flow: ${GREEN}PASS${NC} (Correct source attribution)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "API Flow: ${RED}FAIL${NC} (Expected: api1->api2, Got: $source)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test timezone validation
echo "🌍 Testing timezone handling..."
timezones=("UTC" "EST" "PST" "CET")
for tz in "${timezones[@]}"; do
    response=$(curl -s "$BASE_URL_API1/time?timezone=$tz")
    returned_tz=$(echo "$response" | jq -r '.timezone')
    if [ "$returned_tz" = "$tz" ]; then
        echo -e "Timezone $tz: ${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "Timezone $tz: ${RED}FAIL${NC} (Expected: $tz, Got: $returned_tz)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
done

# Summary
echo
echo "📊 Test Summary:"
echo "=================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n🎉 ${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n❌ ${RED}Some tests failed!${NC}"
    exit 1
fi
