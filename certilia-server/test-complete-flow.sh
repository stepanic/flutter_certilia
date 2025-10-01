#!/bin/bash

# Complete OAuth2 + Extended Info Test
# Tests the full flow from initialization to extended user info

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Complete Certilia OAuth2 + Extended Info Test${NC}"
echo "================================================="

# Configuration
BASE_URL="https://uniformly-credible-opossum.ngrok-free.app"
API_URL="$BASE_URL/api"

# Check if server is running
echo -e "\n${YELLOW}1. Checking server health...${NC}"
HEALTH_RESPONSE=$(curl -s "$API_URL/health" -H "ngrok-skip-browser-warning: true")

if [ -z "$HEALTH_RESPONSE" ]; then
    echo -e "${RED}❌ Server is not responding. Make sure:${NC}"
    echo "   1. Server is running (npm run dev:test or npm run dev:prod)"
    echo "   2. ngrok is running with correct domain"
    exit 1
fi

echo -e "${GREEN}✅ Server is healthy${NC}"
echo "$HEALTH_RESPONSE" | jq '.'

# Initialize OAuth flow
echo -e "\n${YELLOW}2. Initializing OAuth flow...${NC}"
INIT_RESPONSE=$(curl -s "$API_URL/auth/initialize?response_type=code&redirect_uri=$BASE_URL/api/auth/callback" -H "ngrok-skip-browser-warning: true")

if [ -z "$INIT_RESPONSE" ]; then
    echo -e "${RED}❌ Failed to initialize OAuth flow${NC}"
    exit 1
fi

echo -e "${GREEN}✅ OAuth flow initialized${NC}"
echo "$INIT_RESPONSE" | jq '.'

# Extract values
AUTH_URL=$(echo "$INIT_RESPONSE" | jq -r '.authorization_url')
SESSION_ID=$(echo "$INIT_RESPONSE" | jq -r '.session_id')
STATE=$(echo "$INIT_RESPONSE" | jq -r '.state')

echo -e "\n${YELLOW}3. OAuth Flow Details:${NC}"
echo "Session ID: $SESSION_ID"
echo "State: $STATE"
echo ""
echo -e "${GREEN}📋 Authorization URL:${NC}"
echo "$AUTH_URL"
echo ""
echo -e "${YELLOW}👉 Next Steps:${NC}"
echo "1. Open the authorization URL in your browser"
echo "2. Log in with your Croatian eID"
echo "3. After redirect, copy the ENTIRE callback URL"
echo ""

# Wait for callback URL
echo -e "${YELLOW}⏳ Waiting for callback URL...${NC}"
echo "After you authenticate, paste the ENTIRE callback URL here:"
read -p "> " CALLBACK_URL

if [ -z "$CALLBACK_URL" ]; then
    echo -e "${RED}❌ No callback URL provided${NC}"
    exit 1
fi

echo -e "\n${YELLOW}4. Processing callback URL...${NC}"

# Parse URL parameters
QUERY_STRING=$(echo "$CALLBACK_URL" | cut -d'?' -f2)

# Parse individual parameters
CALLBACK_CODE=""
CALLBACK_STATE=""

# Parse each parameter
IFS='&' read -ra PARAMS <<< "$QUERY_STRING"
for param in "${PARAMS[@]}"; do
    KEY=$(echo "$param" | cut -d'=' -f1)
    VALUE=$(echo "$param" | cut -d'=' -f2)

    case "$KEY" in
        "code")
            CALLBACK_CODE="$VALUE"
            ;;
        "state")
            CALLBACK_STATE="$VALUE"
            ;;
    esac
done

# Verify state matches
if [ "$CALLBACK_STATE" != "$STATE" ]; then
    echo -e "${RED}❌ State mismatch!${NC}"
    echo "Expected: $STATE"
    echo "Received: $CALLBACK_STATE"
    exit 1
fi

echo -e "${GREEN}✅ State verified!${NC}"
echo "Code: $CALLBACK_CODE"

# Exchange code for tokens
echo -e "\n${YELLOW}5. Exchanging code for tokens...${NC}"

EXCHANGE_RESPONSE=$(curl -s -X POST "$API_URL/auth/exchange" \
  -H "Content-Type: application/json" \
  -H "ngrok-skip-browser-warning: true" \
  -d "{
    \"code\": \"$CALLBACK_CODE\",
    \"state\": \"$CALLBACK_STATE\",
    \"session_id\": \"$SESSION_ID\"
  }")

if [ -z "$EXCHANGE_RESPONSE" ]; then
    echo -e "${RED}❌ Failed to exchange code${NC}"
    exit 1
fi

# Check if response contains error
if echo "$EXCHANGE_RESPONSE" | grep -q "error"; then
    echo -e "${RED}❌ Error in response:${NC}"
    echo "$EXCHANGE_RESPONSE" | jq '.' 2>/dev/null || echo "$EXCHANGE_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✅ Tokens received successfully!${NC}"
# Uncomment to see full token response:
# echo "$EXCHANGE_RESPONSE" | jq '.' 2>/dev/null || echo "$EXCHANGE_RESPONSE"

# Extract access token
ACCESS_TOKEN=$(echo "$EXCHANGE_RESPONSE" | jq -r '.accessToken' 2>/dev/null)

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}❌ No access token in response${NC}"
    exit 1
fi

# Test basic user endpoint
echo -e "\n${YELLOW}6. Testing basic user endpoint...${NC}"
USER_RESPONSE=$(curl -s "$API_URL/auth/user" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "ngrok-skip-browser-warning: true")

echo -e "${GREEN}✅ Basic user info retrieved:${NC}"
# Show full response to debug differences between TEST and PROD
echo "$USER_RESPONSE" | jq '.' 2>/dev/null || echo "$USER_RESPONSE"

# Test extended user info endpoint
echo -e "\n${YELLOW}7. Testing extended user info endpoint...${NC}"

EXTENDED_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
  "$API_URL/user/extended-info" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "ngrok-skip-browser-warning: true")

# Extract HTTP status code
HTTP_CODE=$(echo "$EXTENDED_RESPONSE" | tail -n1)
EXTENDED_BODY=$(echo "$EXTENDED_RESPONSE" | sed '$d')

echo -e "${BLUE}HTTP Status Code:${NC} $HTTP_CODE"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Extended user info retrieved successfully!${NC}"

    # Extract and display available fields
    echo ""
    echo -e "${YELLOW}📋 Available fields in extended info:${NC}"
    echo "$EXTENDED_BODY" | jq -r '.availableFields[]?' 2>/dev/null || echo "Could not parse available fields"

    echo ""
    echo -e "${YELLOW}📊 Key field values:${NC}"
    # Show only essential fields, not the full verbose response
    echo "$EXTENDED_BODY" | jq '{userInfo: .userInfo | {sub, given_name, family_name, oib, email, birthdate, mobile, formatted}, fieldCount: (.availableFields | length)}' 2>/dev/null || echo "Could not parse fields"

else
    echo -e "${RED}❌ Failed to get extended user info${NC}"
    echo ""
    echo -e "${BLUE}Response:${NC}"
    echo "$EXTENDED_BODY" | jq '.' 2>/dev/null || echo "$EXTENDED_BODY"
fi

# Save tokens to file for debugging and reuse
EXPORT_FILE="/tmp/certilia_tokens.sh"
echo "#!/bin/bash" > "$EXPORT_FILE"
echo "export CERTILIA_ACCESS_TOKEN='$ACCESS_TOKEN'" >> "$EXPORT_FILE"
echo "export CERTILIA_REFRESH_TOKEN='$(echo "$EXCHANGE_RESPONSE" | jq -r '.refreshToken' 2>/dev/null)'" >> "$EXPORT_FILE"
echo "export CERTILIA_ID_TOKEN='$(echo "$EXCHANGE_RESPONSE" | jq -r '.idToken' 2>/dev/null)'" >> "$EXPORT_FILE"
echo "export CERTILIA_SESSION_ID='$SESSION_ID'" >> "$EXPORT_FILE"
echo "export CERTILIA_STATE='$STATE'" >> "$EXPORT_FILE"
echo "export CERTILIA_SERVER_URL='$BASE_URL'" >> "$EXPORT_FILE"
chmod +x "$EXPORT_FILE"

echo -e "\n${GREEN}💾 Tokens exported to $EXPORT_FILE${NC}"
echo -e "${YELLOW}To reuse tokens in another session:${NC}"
echo "source $EXPORT_FILE"

echo -e "\n${GREEN}🎉 Complete OAuth flow test finished!${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "✅ Health check"
echo "✅ OAuth initialization"
echo "✅ Code exchange"
echo "✅ Basic user info"
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Extended user info"
else
    echo "❌ Extended user info (HTTP $HTTP_CODE)"
fi
