#!/bin/bash
# Check org-wide code coverage meets minimum threshold
COVERAGE_FILE="./tests/apex/test-result-codecoverage.json"
if [ ! -f "$COVERAGE_FILE" ]; then
    echo "Coverage file not found"
    exit 1
fi

COVERAGE=$(jq '[.[] | .coveredPercent] | add / length | floor' "$COVERAGE_FILE")
echo "Org-wide coverage: ${COVERAGE}%"

if [ "$COVERAGE" -lt 75 ]; then
    echo "FAIL: Coverage ${COVERAGE}% is below 75% threshold"
    exit 1
fi

echo "PASS: Coverage meets threshold"
