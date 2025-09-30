#!/bin/bash

# ====================================================================
# Quick Start Script for Certilia Server
# ====================================================================
# One-command setup and start for local development
# ====================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🚀 Certilia Server - Quick Start              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Check environment selection
ENV_TYPE=${1:-test}

if [ "$ENV_TYPE" != "test" ] && [ "$ENV_TYPE" != "prod" ]; then
    echo -e "${RED}❌ Invalid environment!${NC}"
    echo ""
    echo "Usage:"
    echo -e "  ${GREEN}./quick-start.sh test${NC}   - Start with TEST environment (idp.test.certilia.com)"
    echo -e "  ${GREEN}./quick-start.sh prod${NC}   - Start with PRODUCTION environment (idp.certilia.com)"
    echo ""
    exit 1
fi

# Set environment-specific configuration
if [ "$ENV_TYPE" = "test" ]; then
    ENV_FILE=".env.example.test"
    ENV_NAME="TEST"
    CERTILIA_HOST="idp.test.certilia.com"
    CLIENT_ID="991dffbb..."
else
    ENV_FILE=".env.example.production"
    ENV_NAME="PRODUCTION"
    CERTILIA_HOST="idp.certilia.com"
    CLIENT_ID="1a6ec445..."
fi

echo -e "${YELLOW}📋 Configuration:${NC}"
echo "  Environment: $ENV_NAME"
echo "  Certilia: $CERTILIA_HOST"
echo ""

# Step 1: Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}1️⃣  Creating .env from $ENV_FILE...${NC}"
    cp "$ENV_FILE" .env
    echo -e "${GREEN}   ✅ .env created${NC}"
else
    echo -e "${YELLOW}1️⃣  .env file already exists${NC}"
    read -p "   Overwrite with $ENV_FILE? (y/N): " overwrite
    if [ "$overwrite" = "y" ] || [ "$overwrite" = "Y" ]; then
        cp "$ENV_FILE" .env
        echo -e "${GREEN}   ✅ .env updated${NC}"
    else
        echo -e "${BLUE}   → Keeping existing .env${NC}"
    fi
fi
echo ""

# Step 2: Install dependencies
if [ ! -d node_modules ]; then
    echo -e "${YELLOW}2️⃣  Installing dependencies...${NC}"
    npm install
    echo -e "${GREEN}   ✅ Dependencies installed${NC}"
else
    echo -e "${YELLOW}2️⃣  Dependencies already installed${NC}"
    echo -e "${BLUE}   → Run 'npm install' if you need to update${NC}"
fi
echo ""

# Step 3: Create logs directory
if [ ! -d logs ]; then
    echo -e "${YELLOW}3️⃣  Creating logs directory...${NC}"
    mkdir -p logs
    echo -e "${GREEN}   ✅ Logs directory created${NC}"
else
    echo -e "${YELLOW}3️⃣  Logs directory exists${NC}"
fi
echo ""

# Step 4: Display startup instructions
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           🎉 Setup Complete!                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo ""
echo -e "${BLUE}1️⃣  Start ngrok in a separate terminal:${NC}"
echo -e "   ${GREEN}ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000${NC}"
echo ""
echo -e "${BLUE}2️⃣  Start the server:${NC}"
echo -e "   ${GREEN}npm run dev${NC}"
echo ""
echo -e "${BLUE}3️⃣  Test the server:${NC}"
echo -e "   ${GREEN}curl https://uniformly-credible-opossum.ngrok-free.app/api/health${NC}"
echo ""
echo -e "${BLUE}4️⃣  Test OAuth flow:${NC}"
echo -e "   ${GREEN}./test-oauth-flow.sh${NC}"
echo ""
echo -e "${YELLOW}🔗 Important URLs:${NC}"
echo "   Server: https://uniformly-credible-opossum.ngrok-free.app"
echo "   Health: https://uniformly-credible-opossum.ngrok-free.app/api/health"
echo "   Docs: https://uniformly-credible-opossum.ngrok-free.app/"
echo ""

# Ask if user wants to start the server immediately
read -p "Start the server now? (Y/n): " start_now
if [ "$start_now" != "n" ] && [ "$start_now" != "N" ]; then
    echo ""
    echo -e "${GREEN}🚀 Starting server...${NC}"
    echo -e "${YELLOW}⚠️  Make sure ngrok is running in another terminal!${NC}"
    sleep 2
    npm run dev
fi