#!/bin/bash

echo "🚀 Starting Certilia OAuth2 Server - Local Setup"
echo "=============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Copy local env if .env doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env from .env.local..."
    cp .env.local .env
    echo -e "${GREEN}✅ Created .env with your Certilia credentials${NC}"
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
echo "Client ID: 991dffbb1cdd4d51423e1a5de323f13b15256c63"
echo "Server URL: https://uniformly-credible-opossum.ngrok-free.app"
echo "Callback URL: https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback"
echo "Certilia Environment: TEST (idp.test.certilia.com)"
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
npm run dev