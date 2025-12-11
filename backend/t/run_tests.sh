#!/bin/bash

# Test runner script for Property Management System
# Usage: ./run_tests.sh [category]
# Categories: all, unit, integration, workflow, security, error

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default to running all tests
CATEGORY="${1:-all}"

echo -e "${YELLOW}Property Management System - Test Runner${NC}"
echo "=========================================="
echo ""

# Change to backend directory
cd "$(dirname "$0")/.."

# Check if prove is available
if ! command -v prove &> /dev/null; then
    echo -e "${RED}Error: 'prove' command not found${NC}"
    echo "Install Test::Harness: cpanm Test::Harness"
    exit 1
fi

# Function to run tests
run_tests() {
    local path=$1
    local name=$2

    echo -e "${YELLOW}Running $name...${NC}"

    if prove -l "$path"; then
        echo -e "${GREEN}✓ $name passed${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ $name failed${NC}"
        echo ""
        return 1
    fi
}

# Run tests based on category
case "$CATEGORY" in
    all)
        echo "Running all tests..."
        echo ""

        run_tests "t/unit/" "Unit Tests"
        UNIT_RESULT=$?

        run_tests "t/integration/" "Integration Tests"
        INTEGRATION_RESULT=$?

        run_tests "t/workflow/" "Workflow Tests"
        WORKFLOW_RESULT=$?

        run_tests "t/security/" "Security Tests"
        SECURITY_RESULT=$?

        run_tests "t/error/" "Error Handling Tests"
        ERROR_RESULT=$?

        # Summary
        echo "=========================================="
        echo -e "${YELLOW}Test Summary:${NC}"
        [ $UNIT_RESULT -eq 0 ] && echo -e "  ${GREEN}✓${NC} Unit Tests" || echo -e "  ${RED}✗${NC} Unit Tests"
        [ $INTEGRATION_RESULT -eq 0 ] && echo -e "  ${GREEN}✓${NC} Integration Tests" || echo -e "  ${RED}✗${NC} Integration Tests"
        [ $WORKFLOW_RESULT -eq 0 ] && echo -e "  ${GREEN}✓${NC} Workflow Tests" || echo -e "  ${RED}✗${NC} Workflow Tests"
        [ $SECURITY_RESULT -eq 0 ] && echo -e "  ${GREEN}✓${NC} Security Tests" || echo -e "  ${RED}✗${NC} Security Tests"
        [ $ERROR_RESULT -eq 0 ] && echo -e "  ${GREEN}✓${NC} Error Handling Tests" || echo -e "  ${RED}✗${NC} Error Handling Tests"

        # Exit with error if any tests failed
        if [ $UNIT_RESULT -ne 0 ] || [ $INTEGRATION_RESULT -ne 0 ] || [ $WORKFLOW_RESULT -ne 0 ] || [ $SECURITY_RESULT -ne 0 ] || [ $ERROR_RESULT -ne 0 ]; then
            exit 1
        fi
        ;;

    unit)
        run_tests "t/unit/" "Unit Tests"
        ;;

    integration)
        run_tests "t/integration/" "Integration Tests"
        ;;

    workflow)
        run_tests "t/workflow/" "Workflow Tests"
        ;;

    security)
        run_tests "t/security/" "Security Tests"
        ;;

    error)
        run_tests "t/error/" "Error Handling Tests"
        ;;

    *)
        echo -e "${RED}Error: Unknown category '$CATEGORY'${NC}"
        echo ""
        echo "Usage: $0 [category]"
        echo "Categories: all, unit, integration, workflow, security, error"
        exit 1
        ;;
esac

echo -e "${GREEN}All tests completed successfully!${NC}"
