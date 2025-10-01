#!/bin/bash

# Standalone Exchange Test Script
# This script tests the code exchange independently

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Standalone Code Exchange Test${NC}"
echo "=================================="

# Check if we have exported session info
if [ -f "/tmp/certilia_tokens.sh" ] && [ -z "$1" ]; then
    echo -e "${YELLOW}Loading session info from /tmp/certilia_tokens.sh...${NC}"
    source /tmp/certilia_tokens.sh
    AUTH_CODE=""
    SESSION_ID="$CERTILIA_SESSION_ID"
    STATE="$CERTILIA_STATE"
    SERVER_URL="${CERTILIA_SERVER_URL:-https://uniformly-credible-opossum.ngrok-free.app}"
else
    # Manual parameters
    AUTH_CODE="$1"
    SESSION_ID="$2"
    STATE="$3"
    SERVER_URL="${4:-https://uniformly-credible-opossum.ngrok-free.app}"
fi

# Check if we have the required parameters
if [ -z "$AUTH_CODE" ] && [ -z "$SESSION_ID" ]; then
    echo -e "${RED}❌ Error: Missing parameters${NC}"
    echo ""
    echo "Usage: $0 <auth_code> <session_id> <state> [server_url]"
    echo ""
    echo "Or first run test-oauth-flow.sh to initialize, then:"
    echo "source /tmp/certilia_tokens.sh"
    echo "$0 <auth_code>"
    exit 1
fi

# If no auth code provided, ask for it
if [ -z "$AUTH_CODE" ]; then
    echo -e "${YELLOW}Session ID:${NC} $SESSION_ID"
    echo -e "${YELLOW}State:${NC} $STATE"
    echo ""
    echo -e "${YELLOW}Enter the authorization code from the callback URL:${NC}"
    read -p "> " AUTH_CODE
fi

if [ -z "$AUTH_CODE" ]; then
    echo -e "${RED}❌ No authorization code provided${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}1. Exchanging code for tokens...${NC}"
echo "Server: $SERVER_URL"
echo "Code: ${AUTH_CODE:0:20}..."
echo "Session: ${SESSION_ID:0:20}..."
echo "State: ${STATE:0:20}..."
echo ""

# Exchange code for tokens
EXCHANGE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "${SERVER_URL}/api/auth/exchange" \
  -H "Content-Type: application/json" \
  -H "ngrok-skip-browser-warning: true" \
  -d "{
    \"code\": \"$AUTH_CODE\",
    \"state\": \"$STATE\",
    \"session_id\": \"$SESSION_ID\"
  }")

# Extract HTTP status code
HTTP_CODE=$(echo "$EXCHANGE_RESPONSE" | tail -n1)
EXCHANGE_BODY=$(echo "$EXCHANGE_RESPONSE" | sed '$d')

echo -e "${BLUE}HTTP Status Code:${NC} $HTTP_CODE"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Code exchanged successfully!${NC}"

    # Extract tokens
    ACCESS_TOKEN=$(echo "$EXCHANGE_BODY" | jq -r '.accessToken' 2>/dev/null)
    REFRESH_TOKEN=$(echo "$EXCHANGE_BODY" | jq -r '.refreshToken' 2>/dev/null)
    ID_TOKEN=$(echo "$EXCHANGE_BODY" | jq -r '.idToken' 2>/dev/null)

    # Save tokens to export file
    EXPORT_FILE="/tmp/certilia_tokens.sh"
    echo "#!/bin/bash" > "$EXPORT_FILE"
    echo "export CERTILIA_ACCESS_TOKEN='$ACCESS_TOKEN'" >> "$EXPORT_FILE"
    echo "export CERTILIA_REFRESH_TOKEN='$REFRESH_TOKEN'" >> "$EXPORT_FILE"
    echo "export CERTILIA_ID_TOKEN='$ID_TOKEN'" >> "$EXPORT_FILE"
    echo "export CERTILIA_SERVER_URL='$SERVER_URL'" >> "$EXPORT_FILE"
    chmod +x "$EXPORT_FILE"

    echo ""
    echo -e "${YELLOW}📋 User Information:${NC}"
    echo "$EXCHANGE_BODY" | jq '.user' 2>/dev/null

    echo ""
    echo -e "${YELLOW}🔑 Token Info:${NC}"
    echo "Access Token: ${ACCESS_TOKEN:0:20}..."
    echo "Refresh Token: ${REFRESH_TOKEN:0:20}..."
    echo "ID Token: ${ID_TOKEN:0:20}..."

    echo ""
    echo -e "${GREEN}💾 Tokens saved to $EXPORT_FILE${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Test extended info: source $EXPORT_FILE && ./test-extended-info.sh"
    echo "2. Test with different environment: npm run dev:prod"

else
    echo -e "${RED}❌ Code exchange failed${NC}"
    echo ""

    # Try to parse error
    ERROR=$(echo "$EXCHANGE_BODY" | jq -r '.error' 2>/dev/null)
    ERROR_DESC=$(echo "$EXCHANGE_BODY" | jq -r '.error_description' 2>/dev/null)

    if [ ! -z "$ERROR" ] && [ "$ERROR" != "null" ]; then
        echo -e "${RED}Error:${NC} $ERROR"
        if [ ! -z "$ERROR_DESC" ] && [ "$ERROR_DESC" != "null" ]; then
            echo -e "${RED}Description:${NC} $ERROR_DESC"
        fi
    else
        echo -e "${BLUE}Response:${NC}"
        echo "$EXCHANGE_BODY" | jq '.' 2>/dev/null || echo "$EXCHANGE_BODY"
    fi

    echo ""
    echo -e "${YELLOW}💡 Common issues:${NC}"
    echo "- Authorization code already used"
    echo "- Session expired (codes expire quickly)"
    echo "- State mismatch"
    echo "- Wrong environment (test vs prod)"
fi