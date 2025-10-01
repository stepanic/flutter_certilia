#!/bin/bash

# ====================================================================
# Test Both Certilia Environments (TEST and PRODUCTION)
# ====================================================================
# This script tests OAuth flow in both TEST and PROD environments
# and compares the responses to ensure consistency
# ====================================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
BASE_URL="https://uniformly-credible-opossum.ngrok-free.app"
API_URL="$BASE_URL/api"

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Testing Both Certilia Environments               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Check which environment is currently active
echo -e "${YELLOW}1️⃣  Detecting current environment...${NC}"
CURRENT_BASE=$(grep CERTILIA_BASE_URL .env | cut -d'=' -f2)
if echo "$CURRENT_BASE" | grep -q "test.certilia"; then
    CURRENT_ENV="TEST"
else
    CURRENT_ENV="PRODUCTION"
fi
echo -e "   Current environment: ${GREEN}$CURRENT_ENV${NC}"
echo -e "   Certilia URL: $CURRENT_BASE"
echo ""

# Check if server is running
echo -e "${YELLOW}2️⃣  Checking if server is running...${NC}"
HEALTH=$(curl -s "$API_URL/health" 2>/dev/null)
if [ -z "$HEALTH" ]; then
    echo -e "${RED}❌ Server is not responding!${NC}"
    echo ""
    echo "Please ensure:"
    echo "  1. Server is running: npm run dev:test (or dev:prod)"
    echo "  2. ngrok is running: ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000"
    exit 1
fi
echo -e "   ${GREEN}✅ Server is running${NC}"
echo ""

# Function to test environment
test_environment() {
    local ENV_NAME=$1
    local ENV_CMD=$2

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Testing $ENV_NAME Environment${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Check if we need to switch environment
    CURRENT_BASE=$(grep CERTILIA_BASE_URL .env | cut -d'=' -f2)
    if [ "$ENV_NAME" = "TEST" ] && echo "$CURRENT_BASE" | grep -q "test.certilia"; then
        echo -e "${GREEN}✅ Already on TEST environment${NC}"
    elif [ "$ENV_NAME" = "PRODUCTION" ] && echo "$CURRENT_BASE" | grep -q -v "test.certilia"; then
        echo -e "${GREEN}✅ Already on PRODUCTION environment${NC}"
    else
        echo -e "${YELLOW}⚠️  Switching to $ENV_NAME environment...${NC}"
        echo ""
        echo -e "${RED}IMPORTANT: You need to restart the server!${NC}"
        echo ""
        read -p "Have you restarted server with: npm run $ENV_CMD? (y/N): " restarted
        if [ "$restarted" != "y" ] && [ "$restarted" != "Y" ]; then
            echo -e "${BLUE}→ Please restart server and run this script again${NC}"
            exit 0
        fi
    fi
    echo ""

    # Initialize OAuth flow
    echo -e "${YELLOW}3️⃣  Initializing OAuth flow...${NC}"
    INIT_RESPONSE=$(curl -s "$API_URL/auth/initialize?response_type=code&redirect_uri=$BASE_URL/api/auth/callback")

    if [ -z "$INIT_RESPONSE" ]; then
        echo -e "${RED}❌ Failed to initialize OAuth flow${NC}"
        return 1
    fi

    AUTH_URL=$(echo "$INIT_RESPONSE" | jq -r '.authorization_url')
    SESSION_ID=$(echo "$INIT_RESPONSE" | jq -r '.session_id')
    STATE=$(echo "$INIT_RESPONSE" | jq -r '.state')

    echo -e "   ${GREEN}✅ OAuth initialized${NC}"
    echo -e "   Session ID: ${BLUE}${SESSION_ID:0:20}...${NC}"
    echo -e "   State: ${BLUE}${STATE:0:20}...${NC}"
    echo ""

    # Check which Certilia endpoint is being used
    if echo "$AUTH_URL" | grep -q "test.certilia"; then
        echo -e "   ${GREEN}✅ Using TEST Certilia: idp.test.certilia.com${NC}"
    else
        echo -e "   ${GREEN}✅ Using PROD Certilia: idp.certilia.com${NC}"
    fi
    echo ""

    echo -e "${YELLOW}4️⃣  Authorization URL:${NC}"
    echo -e "   ${CYAN}$AUTH_URL${NC}"
    echo ""

    echo -e "${YELLOW}Next steps for $ENV_NAME:${NC}"
    echo "  1. Open the authorization URL in browser"
    echo "  2. Complete authentication"
    echo "  3. Copy the callback URL"
    echo ""

    read -p "Paste the callback URL (or press Enter to skip): " CALLBACK_URL

    if [ -z "$CALLBACK_URL" ]; then
        echo -e "${BLUE}→ Skipped${NC}"
        echo ""
        return 0
    fi

    # Parse callback URL
    echo -e "\n${YELLOW}5️⃣  Processing callback...${NC}"
    CODE=$(echo "$CALLBACK_URL" | grep -oP '(?<=code=)[^&]*')
    CALLBACK_STATE=$(echo "$CALLBACK_URL" | grep -oP '(?<=state=)[^&]*')

    if [ -z "$CODE" ]; then
        echo -e "${RED}❌ Could not extract code from callback URL${NC}"
        return 1
    fi

    echo -e "   ${GREEN}✅ Code extracted${NC}"
    echo ""

    # Exchange code for tokens
    echo -e "${YELLOW}6️⃣  Exchanging code for tokens...${NC}"
    EXCHANGE_RESPONSE=$(curl -s -X POST "$API_URL/auth/exchange" \
      -H "Content-Type: application/json" \
      -d "{
        \"code\": \"$CODE\",
        \"state\": \"$CALLBACK_STATE\",
        \"session_id\": \"$SESSION_ID\"
      }")

    if echo "$EXCHANGE_RESPONSE" | grep -q "error"; then
        echo -e "${RED}❌ Token exchange failed${NC}"
        echo "$EXCHANGE_RESPONSE" | jq '.'
        return 1
    fi

    ACCESS_TOKEN=$(echo "$EXCHANGE_RESPONSE" | jq -r '.accessToken')
    USER_DATA=$(echo "$EXCHANGE_RESPONSE" | jq '.user')

    echo -e "   ${GREEN}✅ Tokens received${NC}"
    echo ""
    echo -e "${YELLOW}7️⃣  User Data ($ENV_NAME):${NC}"
    echo "$USER_DATA" | jq '.'
    echo ""

    # Test extended info endpoint
    echo -e "${YELLOW}8️⃣  Testing extended info endpoint...${NC}"
    EXTENDED_RESPONSE=$(curl -s "$API_URL/user/extended-info" \
      -H "Authorization: Bearer $ACCESS_TOKEN")

    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✅ Extended info retrieved${NC}"
        echo ""
        echo -e "${YELLOW}9️⃣  Extended Info ($ENV_NAME):${NC}"

        # Show available fields
        AVAILABLE_FIELDS=$(echo "$EXTENDED_RESPONSE" | jq -r '.availableFields[]' 2>/dev/null)
        if [ ! -z "$AVAILABLE_FIELDS" ]; then
            echo -e "   ${BLUE}Available fields:${NC}"
            echo "$AVAILABLE_FIELDS" | sed 's/^/     - /'
            echo ""
        fi

        # Show user info
        USER_INFO=$(echo "$EXTENDED_RESPONSE" | jq '.userInfo' 2>/dev/null)
        if [ ! -z "$USER_INFO" ] && [ "$USER_INFO" != "null" ]; then
            echo -e "   ${BLUE}User Info:${NC}"
            echo "$USER_INFO" | jq '.'
        else
            echo -e "   ${YELLOW}⚠️  No userInfo field in response${NC}"
            echo ""
            echo -e "   ${BLUE}Full response:${NC}"
            echo "$EXTENDED_RESPONSE" | jq '.'
        fi
    else
        echo -e "   ${RED}❌ Extended info request failed${NC}"
    fi

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}$ENV_NAME Environment Test Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo ""

    # Save response for comparison
    if [ "$ENV_NAME" = "TEST" ]; then
        TEST_EXTENDED_RESPONSE="$EXTENDED_RESPONSE"
        TEST_USER_DATA="$USER_DATA"
    else
        PROD_EXTENDED_RESPONSE="$EXTENDED_RESPONSE"
        PROD_USER_DATA="$USER_DATA"
    fi
}

# Test both environments
echo -e "${YELLOW}Which environments do you want to test?${NC}"
echo "  1) TEST only"
echo "  2) PRODUCTION only"
echo "  3) Both (sequential)"
echo ""
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        test_environment "TEST" "dev:test"
        ;;
    2)
        test_environment "PRODUCTION" "dev:prod"
        ;;
    3)
        echo -e "${YELLOW}Testing TEST environment first...${NC}"
        echo ""
        test_environment "TEST" "dev:test"

        echo ""
        read -p "Ready to test PRODUCTION? (Restart server with: npm run dev:prod) (y/N): " ready
        if [ "$ready" = "y" ] || [ "$ready" = "Y" ]; then
            test_environment "PRODUCTION" "dev:prod"

            # Compare results
            echo ""
            echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║  Comparison Summary                                ║${NC}"
            echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
            echo ""

            if [ ! -z "$TEST_USER_DATA" ] && [ ! -z "$PROD_USER_DATA" ]; then
                echo -e "${BLUE}Basic user data structure:${NC}"
                echo -e "  TEST fields: $(echo "$TEST_USER_DATA" | jq -r 'keys | length')"
                echo -e "  PROD fields: $(echo "$PROD_USER_DATA" | jq -r 'keys | length')"
                echo ""
            fi

            if [ ! -z "$TEST_EXTENDED_RESPONSE" ] && [ ! -z "$PROD_EXTENDED_RESPONSE" ]; then
                echo -e "${BLUE}Extended info comparison:${NC}"
                TEST_FIELD_COUNT=$(echo "$TEST_EXTENDED_RESPONSE" | jq -r '.availableFields | length' 2>/dev/null || echo "0")
                PROD_FIELD_COUNT=$(echo "$PROD_EXTENDED_RESPONSE" | jq -r '.availableFields | length' 2>/dev/null || echo "0")
                echo -e "  TEST available fields: $TEST_FIELD_COUNT"
                echo -e "  PROD available fields: $PROD_FIELD_COUNT"

                if [ "$TEST_FIELD_COUNT" != "$PROD_FIELD_COUNT" ]; then
                    echo -e "  ${YELLOW}⚠️  Different number of fields!${NC}"
                else
                    echo -e "  ${GREEN}✅ Same number of fields${NC}"
                fi
            fi
        fi
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}🎉 Testing complete!${NC}"