#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔍 Testing Certilia OAuth2 Setup${NC}"
echo "================================"

# Test health endpoint
echo -e "\n${YELLOW}1. Testing server health...${NC}"
HEALTH=$(curl -s https://uniformly-credible-opossum.ngrok-free.app/api/health)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Server is running!${NC}"
    echo "$HEALTH" | jq '.' 2>/dev/null || echo "$HEALTH"
else
    echo -e "${RED}❌ Server is not accessible. Make sure:${NC}"
    echo "   1. Server is running: ./start-local.sh"
    echo "   2. ngrok is running: ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000"
    exit 1
fi

# Test discovery endpoint
echo -e "\n${YELLOW}2. Testing Certilia discovery endpoint...${NC}"
DISCOVERY=$(curl -s https://idp.test.certilia.com/oauth2/oidcdiscovery/.well-known/openid-configuration)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Certilia test environment is accessible!${NC}"
    echo "$DISCOVERY" | jq '.issuer, .authorization_endpoint, .token_endpoint' 2>/dev/null || echo "Discovery endpoint working"
else
    echo -e "${RED}❌ Cannot reach Certilia test environment${NC}"
fi

# Test OAuth initialization
echo -e "\n${YELLOW}3. Testing OAuth initialization...${NC}"
INIT=$(curl -s "https://uniformly-credible-opossum.ngrok-free.app/api/auth/initialize?redirect_uri=https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback")

if [ $? -eq 0 ] && [[ $INIT == *"authorization_url"* ]]; then
    echo -e "${GREEN}✅ OAuth initialization working!${NC}"
    echo "$INIT" | jq '.' 2>/dev/null || echo "$INIT"
    
    AUTH_URL=$(echo "$INIT" | jq -r '.authorization_url' 2>/dev/null)
    if [ ! -z "$AUTH_URL" ]; then
        echo -e "\n${GREEN}📋 Authorization URL generated:${NC}"
        echo "$AUTH_URL"
        echo -e "\n${YELLOW}Next steps:${NC}"
        echo "1. Open the authorization URL in a browser"
        echo "2. Complete authentication with test credentials"
        echo "3. You'll be redirected back to the callback page"
    fi
else
    echo -e "${RED}❌ OAuth initialization failed${NC}"
    echo "$INIT"
fi

echo -e "\n${GREEN}✅ Setup verification complete!${NC}"