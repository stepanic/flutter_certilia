#!/bin/bash

# ====================================================================
# Compare Extended User Info between TEST and PROD
# ====================================================================
# Quick script to compare extended user info responses
# Requires: valid access tokens from both environments
# ====================================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

BASE_URL="https://uniformly-credible-opossum.ngrok-free.app"
API_URL="$BASE_URL/api"

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Compare Extended Info: TEST vs PROD              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to test extended info
test_extended_info() {
    local ENV_NAME=$1
    local ACCESS_TOKEN=$2

    echo -e "${YELLOW}Testing $ENV_NAME environment...${NC}"

    RESPONSE=$(curl -s "$API_URL/user/extended-info" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "ngrok-skip-browser-warning: true")

    if echo "$RESPONSE" | grep -q "error"; then
        echo -e "${RED}❌ Error:${NC}"
        echo "$RESPONSE" | jq '.'
        return 1
    fi

    echo -e "${GREEN}✅ Response received${NC}"
    echo ""

    # Extract and display fields
    AVAILABLE_FIELDS=$(echo "$RESPONSE" | jq -r '.availableFields[]?' 2>/dev/null)
    USER_INFO=$(echo "$RESPONSE" | jq '.userInfo?' 2>/dev/null)

    if [ ! -z "$AVAILABLE_FIELDS" ]; then
        FIELD_COUNT=$(echo "$AVAILABLE_FIELDS" | wc -l | xargs)
        echo -e "${BLUE}Available fields ($FIELD_COUNT):${NC}"
        echo "$AVAILABLE_FIELDS" | sed 's/^/  • /'
        echo ""
    fi

    if [ ! -z "$USER_INFO" ] && [ "$USER_INFO" != "null" ]; then
        echo -e "${BLUE}User Info:${NC}"
        echo "$USER_INFO" | jq '.'
    else
        echo -e "${BLUE}Full Response:${NC}"
        echo "$RESPONSE" | jq '.'
    fi

    echo ""
    echo "$RESPONSE"
}

# Check current environment
CURRENT_BASE=$(grep CERTILIA_BASE_URL .env 2>/dev/null | cut -d'=' -f2)
if echo "$CURRENT_BASE" | grep -q "test.certilia"; then
    CURRENT_ENV="TEST"
else
    CURRENT_ENV="PRODUCTION"
fi

echo -e "Current server environment: ${GREEN}$CURRENT_ENV${NC}"
echo -e "Certilia URL: $CURRENT_BASE"
echo ""

# Get access tokens
echo -e "${YELLOW}Enter access tokens:${NC}"
echo ""

read -p "TEST environment access token: " TEST_TOKEN
echo ""
read -p "PROD environment access token: " PROD_TOKEN
echo ""

if [ -z "$TEST_TOKEN" ] && [ -z "$PROD_TOKEN" ]; then
    echo -e "${RED}❌ No tokens provided${NC}"
    echo ""
    echo "Get tokens by running:"
    echo "  1. npm run dev:test"
    echo "  2. ./test-oauth-flow.sh"
    echo "  3. Copy the accessToken"
    exit 1
fi

echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""

# Test TEST environment if token provided
if [ ! -z "$TEST_TOKEN" ]; then
    TEST_RESULT=$(test_extended_info "TEST" "$TEST_TOKEN")
    echo "$TEST_RESULT"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
fi

# Test PROD environment if token provided
if [ ! -z "$PROD_TOKEN" ]; then
    PROD_RESULT=$(test_extended_info "PRODUCTION" "$PROD_TOKEN")
    echo "$PROD_RESULT"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
fi

# Compare if both provided
if [ ! -z "$TEST_TOKEN" ] && [ ! -z "$PROD_TOKEN" ]; then
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Comparison                                        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""

    TEST_FIELD_COUNT=$(echo "$TEST_RESULT" | jq -r '.availableFields | length' 2>/dev/null || echo "0")
    PROD_FIELD_COUNT=$(echo "$PROD_RESULT" | jq -r '.availableFields | length' 2>/dev/null || echo "0")

    echo -e "TEST available fields: $TEST_FIELD_COUNT"
    echo -e "PROD available fields: $PROD_FIELD_COUNT"
    echo ""

    if [ "$TEST_FIELD_COUNT" = "$PROD_FIELD_COUNT" ]; then
        echo -e "${GREEN}✅ Same number of fields${NC}"
    else
        echo -e "${YELLOW}⚠️  Different number of fields!${NC}"
        echo ""

        # Show unique fields
        TEST_FIELDS=$(echo "$TEST_RESULT" | jq -r '.availableFields[]?' 2>/dev/null | sort)
        PROD_FIELDS=$(echo "$PROD_RESULT" | jq -r '.availableFields[]?' 2>/dev/null | sort)

        ONLY_IN_TEST=$(comm -23 <(echo "$TEST_FIELDS") <(echo "$PROD_FIELDS") 2>/dev/null)
        ONLY_IN_PROD=$(comm -13 <(echo "$TEST_FIELDS") <(echo "$PROD_FIELDS") 2>/dev/null)

        if [ ! -z "$ONLY_IN_TEST" ]; then
            echo -e "${BLUE}Only in TEST:${NC}"
            echo "$ONLY_IN_TEST" | sed 's/^/  • /'
            echo ""
        fi

        if [ ! -z "$ONLY_IN_PROD" ]; then
            echo -e "${BLUE}Only in PROD:${NC}"
            echo "$ONLY_IN_PROD" | sed 's/^/  • /'
            echo ""
        fi
    fi
fi

echo -e "${GREEN}Done!${NC}"