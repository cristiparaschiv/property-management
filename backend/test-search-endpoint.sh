#!/bin/bash

###############################################################################
# Search API Endpoint Testing Script
#
# Tests the global search endpoint at /api/search
#
# Usage:
#   1. Start your Dancer2 app: plackup bin/app.psgi
#   2. Login and get your JWT token
#   3. Run this script: ./test-search-endpoint.sh <token>
#
# Example:
#   ./test-search-endpoint.sh "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
###############################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="${BASE_URL:-http://localhost:5000}"
TOKEN="$1"

if [ -z "$TOKEN" ]; then
    echo -e "${RED}Error: JWT token required${NC}"
    echo "Usage: $0 <jwt_token>"
    echo ""
    echo "To get a token, login first:"
    echo "  curl -X POST ${BASE_URL}/api/auth/login \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"username\":\"your_username\",\"password\":\"your_password\"}'"
    exit 1
fi

# Function to make API request and display results
test_search() {
    local query="$1"
    local description="$2"

    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Test: ${description}${NC}"
    echo -e "${BLUE}Query: ${query}${NC}"
    echo -e "${BLUE}========================================${NC}"

    local url="${BASE_URL}/api/search?q=${query}"

    echo -e "${YELLOW}Request:${NC} GET ${url}"

    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        "${url}")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    echo -e "${YELLOW}Status Code:${NC} ${http_code}"

    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}Response:${NC}"
    else
        echo -e "${RED}Response:${NC}"
    fi

    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
}

# Function to test without authentication
test_no_auth() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Test: No Authentication${NC}"
    echo -e "${BLUE}========================================${NC}"

    local url="${BASE_URL}/api/search?q=test"

    response=$(curl -s -w "\n%{http_code}" \
        -H "Content-Type: application/json" \
        "${url}")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    echo -e "${YELLOW}Status Code:${NC} ${http_code}"

    if [ "$http_code" = "401" ]; then
        echo -e "${GREEN}✓ Correctly rejected (401)${NC}"
    else
        echo -e "${RED}✗ Expected 401, got ${http_code}${NC}"
    fi

    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
}

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Global Search API Endpoint Tests${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Base URL: ${BASE_URL}"
echo -e "Token: ${TOKEN:0:20}..."

# Test 1: Authentication required
test_no_auth

# Test 2: Invalid query (too short)
test_search "" "Empty Query (Should Fail)"

# Test 3: Query too short
test_search "a" "Single Character Query (Should Fail)"

# Test 4: Valid 2-character query
test_search "ab" "Valid 2-Character Query"

# Test 5: Common search term
test_search "test" "Search for 'test'"

# Test 6: Email-like search
test_search "admin@" "Email Pattern Search"

# Test 7: Number search
test_search "123" "Number Search"

# Test 8: Search with special characters
test_search "ABC-123" "Hyphenated Search"

# Test 9: Longer query
test_search "property" "Search for 'property'"

# Test 10: Case sensitivity test
test_search "TEST" "Uppercase Search"

# Test 11: Query with spaces (URL encoded)
test_search "john%20doe" "Search with Spaces"

# Test 12: Non-existent term
test_search "xyzabc999nonexistent" "Non-Existent Term"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Test Suite Completed${NC}"
echo -e "${GREEN}========================================${NC}"

# Summary of what to look for:
echo -e "\n${YELLOW}Expected Results:${NC}"
echo "1. Authentication test should return 401"
echo "2. Empty/short queries should return 400"
echo "3. Valid queries should return 200 with data structure:"
echo "   - tenants: array (max 5 items)"
echo "   - invoices: array (max 5 items)"
echo "   - providers: array (max 5 items)"
echo "   - total_count: number"
echo "4. Each result should have a 'type' field"
echo "5. Search should be case-insensitive"
echo ""
