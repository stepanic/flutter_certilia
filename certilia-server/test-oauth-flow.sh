#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🧪 Testing Certilia OAuth2 Flow${NC}"
echo "================================="

# Configuration
BASE_URL="https://uniformly-credible-opossum.ngrok-free.app"
API_URL="$BASE_URL/api"

# Check if server is running
echo -e "\n${YELLOW}1. Checking server health...${NC}"
HEALTH_RESPONSE=$(curl -s "$API_URL/health")

if [ -z "$HEALTH_RESPONSE" ]; then
    echo -e "${RED}❌ Server is not responding. Make sure:${NC}"
    echo "   1. Server is running (./dev-start.sh)"
    echo "   2. ngrok is running with correct domain"
    exit 1
fi

echo -e "${GREEN}✅ Server is healthy${NC}"
echo "$HEALTH_RESPONSE" | jq '.'

# Initialize OAuth flow
echo -e "\n${YELLOW}2. Initializing OAuth flow...${NC}"
INIT_RESPONSE=$(curl -s "$API_URL/auth/initialize?response_type=code&redirect_uri=$BASE_URL/api/auth/callback")

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
echo "3. After redirect, check the URL for 'code' and 'state' parameters"
echo "4. Use the test-exchange.sh script to complete the flow"
echo ""
echo -e "${YELLOW}📝 Save these values for the exchange step:${NC}"
echo "SESSION_ID=$SESSION_ID"
echo "STATE=$STATE"

# Create exchange test script
cat > test-exchange.sh << 'EOF'
#!/bin/bash

# Configuration
BASE_URL="https://uniformly-credible-opossum.ngrok-free.app"
API_URL="$BASE_URL/api"

echo "🔄 Testing Code Exchange"
echo "======================="

read -p "Enter the authorization code from callback: " CODE
read -p "Enter the session ID: " SESSION_ID
read -p "Enter the state: " STATE

echo -e "\nExchanging code for tokens..."

EXCHANGE_RESPONSE=$(curl -s -X POST "$API_URL/auth/exchange" \
  -H "Content-Type: application/json" \
  -d "{
    \"code\": \"$CODE\",
    \"state\": \"$STATE\",
    \"session_id\": \"$SESSION_ID\"
  }")

if [ -z "$EXCHANGE_RESPONSE" ]; then
    echo "❌ Failed to exchange code"
    exit 1
fi

echo "✅ Code exchanged successfully!"
echo "$EXCHANGE_RESPONSE" | jq '.'

# Extract access token
ACCESS_TOKEN=$(echo "$EXCHANGE_RESPONSE" | jq -r '.accessToken')

if [ "$ACCESS_TOKEN" != "null" ]; then
    echo -e "\n📤 Testing authenticated endpoint..."
    USER_RESPONSE=$(curl -s "$API_URL/auth/user" \
      -H "Authorization: Bearer $ACCESS_TOKEN")
    
    echo "✅ User info retrieved:"
    echo "$USER_RESPONSE" | jq '.'
fi
EOF

chmod +x test-exchange.sh

echo -e "\n${GREEN}✅ Created test-exchange.sh for completing the flow${NC}"

# Wait for callback URL
echo -e "\n${YELLOW}⏳ Waiting for callback URL...${NC}"
echo "After you authenticate, paste the ENTIRE callback URL here:"
read -p "> " CALLBACK_URL

if [ ! -z "$CALLBACK_URL" ]; then
    echo -e "\n${YELLOW}🔄 Processing callback URL...${NC}"
    
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
    echo -e "\n${YELLOW}🔄 Exchanging code for tokens...${NC}"
    
    EXCHANGE_RESPONSE=$(curl -s -X POST "$API_URL/auth/exchange" \
      -H "Content-Type: application/json" \
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
    echo "$EXCHANGE_RESPONSE" | jq '.' 2>/dev/null || echo "$EXCHANGE_RESPONSE"
    
    # Extract access token
    ACCESS_TOKEN=$(echo "$EXCHANGE_RESPONSE" | jq -r '.accessToken' 2>/dev/null)
    
    if [ "$ACCESS_TOKEN" != "null" ] && [ ! -z "$ACCESS_TOKEN" ]; then
        echo -e "\n${YELLOW}📤 Testing authenticated endpoint...${NC}"
        USER_RESPONSE=$(curl -s "$API_URL/auth/user" \
          -H "Authorization: Bearer $ACCESS_TOKEN")
        
        echo -e "${GREEN}✅ User info retrieved:${NC}"
        echo "$USER_RESPONSE" | jq '.' 2>/dev/null || echo "$USER_RESPONSE"
        
        # Save token for future use
        echo -e "\n${GREEN}💾 Access token ${NC}"
        echo "$ACCESS_TOKEN"
    fi
    
    echo -e "\n${GREEN}🎉 OAuth flow completed successfully!${NC}"
fi