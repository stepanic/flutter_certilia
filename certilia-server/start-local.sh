#!/bin/bash

echo "🚀 Starting Certilia OAuth2 Server - Local Setup"
echo "=============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check for environment argument
ENV_TYPE=${1:-test}

# Validate environment type
if [ "$ENV_TYPE" != "test" ] && [ "$ENV_TYPE" != "prod" ]; then
    echo -e "${RED}❌ Invalid environment. Use 'test' or 'prod'${NC}"
    echo "Usage: ./start-local.sh [test|prod]"
    exit 1
fi

# Set environment-specific variables
if [ "$ENV_TYPE" = "test" ]; then
    ENV_FILE=".env.local.test"
    ENV_NAME="TEST"
    CERTILIA_HOST="idp.test.certilia.com"
    CLIENT_ID="991dffbb1cdd4d51423e1a5de323f13b15256c63"
else
    ENV_FILE=".env.local.production"
    ENV_NAME="PRODUCTION"
    CERTILIA_HOST="idp.certilia.com"
    CLIENT_ID="1a6ec445bbe092c1465f3d19aea9757e3e278a75"
fi

# Check if environment file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file $ENV_FILE not found!${NC}"
    echo "Please create it from the example files."
    exit 1
fi

# Install dependencies if needed
if [ ! -d node_modules ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Create logs directory
if [ ! -d logs ]; then
    mkdir -p logs
fi

echo ""
echo -e "${GREEN}📋 Configuration Summary:${NC}"
echo "================================"
echo -e "Environment: ${BLUE}$ENV_NAME${NC}"
echo "Client ID: $CLIENT_ID"
echo "Server URL: https://uniformly-credible-opossum.ngrok-free.app"
echo "Callback URL: https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback"
echo "Certilia Environment: $CERTILIA_HOST"
echo ""

echo -e "${YELLOW}🔧 Starting Steps:${NC}"
echo ""
echo "1️⃣  Server will start on port 3000"
echo ""
echo "2️⃣  In another terminal, run ngrok:"
echo -e "${GREEN}    ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000${NC}"
echo ""
echo "3️⃣  Test endpoints:"
echo "    Health: https://uniformly-credible-opossum.ngrok-free.app/api/health"
echo "    Init Auth: https://uniformly-credible-opossum.ngrok-free.app/api/auth/initialize"
echo ""

echo -e "${GREEN}🚀 Starting server...${NC}"

# Run appropriate npm script based on environment
if [ "$ENV_TYPE" = "test" ]; then
    npm run dev:test-env
else
    npm run dev:prod-env
fi