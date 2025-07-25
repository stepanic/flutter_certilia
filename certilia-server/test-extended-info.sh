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

# Check if access token is provided
if [ -z "$1" ]; then
    echo -e "${RED}❌ Error: Access token required${NC}"
    echo "Usage: $0 <access_token>"
    echo ""
    echo "Example:"
    echo "  $0 eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    exit 1
fi

ACCESS_TOKEN=$1

# Server URL (default to localhost:3000)
SERVER_URL=${SERVER_URL:-http://localhost:3000}

echo -e "${YELLOW}1. Testing /api/user/extended-info endpoint...${NC}"
echo ""

# Make the request
response=$(curl -s -w "\n%{http_code}" -X GET \
  "${SERVER_URL}/api/user/extended-info" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json")

# Extract HTTP status code
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

echo -e "${BLUE}HTTP Status Code:${NC} $http_code"
echo ""

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✅ Extended user info retrieved successfully!${NC}"
    echo ""
    echo -e "${BLUE}Response:${NC}"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
    
    # Extract available fields
    echo ""
    echo -e "${YELLOW}📋 Available fields:${NC}"
    echo "$body" | jq -r '.availableFields[]' 2>/dev/null || echo "Could not parse available fields"
    
else
    echo -e "${RED}❌ Failed to get extended user info${NC}"
    echo ""
    echo -e "${BLUE}Response:${NC}"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
fi

echo ""
echo -e "${BLUE}💡 Tip:${NC} To get fresh data, run the OAuth flow again with ./test-oauth-flow.sh"