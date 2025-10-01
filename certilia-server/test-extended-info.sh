#!/bin/bash

# Test script for getting extended user info from Certilia API

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Testing Extended User Info Endpoint${NC}"
echo "======================================"

# Try to load tokens from export file
if [ -f "/tmp/certilia_tokens.sh" ] && [ -z "$1" ]; then
    echo -e "${YELLOW}Loading tokens from /tmp/certilia_tokens.sh...${NC}"
    source /tmp/certilia_tokens.sh
    ACCESS_TOKEN="$CERTILIA_ACCESS_TOKEN"
    SERVER_URL="${CERTILIA_SERVER_URL:-https://uniformly-credible-opossum.ngrok-free.app}"
    echo -e "${GREEN}✅ Tokens loaded${NC}"
elif [ ! -z "$1" ]; then
    ACCESS_TOKEN="$1"
    SERVER_URL="${2:-https://uniformly-credible-opossum.ngrok-free.app}"
else
    echo -e "${RED}❌ Error: Access token required${NC}"
    echo ""
    echo "Option 1: Run test-complete-flow.sh first, then:"
    echo "  source /tmp/certilia_tokens.sh && $0"
    echo ""
    echo "Option 2: Provide token manually:"
    echo "  $0 <access_token> [server_url]"
    echo ""
    echo "Example:"
    echo "  $0 eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    exit 1
fi

# Default to ngrok URL if not set
SERVER_URL=${SERVER_URL:-https://uniformly-credible-opossum.ngrok-free.app}

echo -e "${YELLOW}1. Testing /api/user/extended-info endpoint...${NC}"
echo "Server: $SERVER_URL"
echo ""

# Make the request with verbose error handling
response=$(curl -s -w "\n%{http_code}" -X GET \
  "${SERVER_URL}/api/user/extended-info" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "ngrok-skip-browser-warning: true")

# Extract HTTP status code
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

echo -e "${BLUE}HTTP Status Code:${NC} $http_code"
echo ""

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✅ Extended user info retrieved successfully!${NC}"

    # Extract source field to see where data came from
    source=$(echo "$body" | jq -r '.source' 2>/dev/null)
    if [ ! -z "$source" ] && [ "$source" != "null" ]; then
        echo -e "${YELLOW}Data source:${NC} $source"
    fi

    # Extract available fields
    echo ""
    echo -e "${YELLOW}📋 Available fields ($(echo "$body" | jq -r '.availableFields | length' 2>/dev/null) total):${NC}"
    echo "$body" | jq -r '.availableFields[]' 2>/dev/null || echo "Could not parse available fields"

    # Show key field values only
    echo ""
    echo -e "${YELLOW}📊 Key field values:${NC}"
    echo "$body" | jq '{
        sub: .userInfo.sub,
        given_name: .userInfo.given_name,
        family_name: .userInfo.family_name,
        oib: .userInfo.oib,
        email: .userInfo.email,
        birthdate: .userInfo.birthdate,
        source: .source
    }' 2>/dev/null || echo "$body" | jq '.' 2>/dev/null

    # Show full response if DEBUG is set
    if [ ! -z "$DEBUG" ]; then
        echo ""
        echo -e "${YELLOW}📄 Full response:${NC}"
        echo "$body" | jq '.' 2>/dev/null
    fi

elif [ "$http_code" = "401" ]; then
    echo -e "${RED}❌ Unauthorized: Token may be expired or invalid${NC}"
    echo ""
    echo -e "${BLUE}Response:${NC}"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
    echo ""
    echo -e "${YELLOW}💡 Tip:${NC} Run test-complete-flow.sh to get a fresh token"
else
    echo -e "${RED}❌ Failed to get extended user info${NC}"
    echo ""
    echo -e "${BLUE}Response:${NC}"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
fi

echo ""
echo -e "${BLUE}💡 Tips:${NC}"
echo "- To see full response: DEBUG=1 $0"
echo "- To get fresh token: ./test-complete-flow.sh"
echo "- To test specific env: npm run dev:prod (or dev:test)"