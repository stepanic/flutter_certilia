#!/bin/bash

echo "🚀 Starting Certilia OAuth2 Server in Development Mode"
echo "====================================================="

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Setting up development environment..."
    cp .env.development .env
    echo "✅ Created .env from .env.development"
    echo ""
    echo "⚠️  IMPORTANT: Edit .env and add your Certilia credentials:"
    echo "   - CERTILIA_CLIENT_ID"
    echo "   - CERTILIA_CLIENT_SECRET"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Check if node_modules exists
if [ ! -d node_modules ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Check if logs directory exists
if [ ! -d logs ]; then
    mkdir -p logs
fi

# Check if CLIENT_ID is set
if grep -q "your_client_id_here" .env; then
    echo "❌ ERROR: Please update your Certilia credentials in .env file"
    echo "   Edit .env and replace:"
    echo "   - CERTILIA_CLIENT_ID=your_client_id_here"
    echo "   - CERTILIA_CLIENT_SECRET=your_client_secret_here"
    echo ""
    echo "   With your actual credentials from Certilia Dashboard"
    exit 1
fi

echo ""
echo "📋 Current Configuration:"
echo "-------------------------"
echo "Server URL: https://uniformly-credible-opossum.ngrok-free.app"
echo "Local Port: 3000"
echo "Redirect URI: https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback"
echo ""

# Start the server
echo "🌐 Starting server on port 3000..."
echo ""
echo "👉 Next step: In another terminal, run:"
echo "   ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000"
echo ""
echo "📱 Server endpoints will be available at:"
echo "   https://uniformly-credible-opossum.ngrok-free.app/api/health"
echo "   https://uniformly-credible-opossum.ngrok-free.app/api/auth/initialize"
echo ""

# Start with nodemon for auto-reload
npm run dev