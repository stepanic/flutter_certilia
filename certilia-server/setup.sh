#!/bin/bash

echo "🚀 Certilia OAuth2 Server Setup"
echo "==============================="

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✅ .env file created"
    echo ""
    echo "⚠️  IMPORTANT: Please edit .env file and add your Certilia credentials:"
    echo "   - CERTILIA_CLIENT_ID"
    echo "   - CERTILIA_CLIENT_SECRET"
    echo "   - JWT_SECRET (generate a strong secret)"
    echo "   - SESSION_SECRET (generate a strong secret)"
    echo ""
else
    echo "✅ .env file already exists"
fi

# Create logs directory
if [ ! -d logs ]; then
    echo "📁 Creating logs directory..."
    mkdir -p logs
    echo "✅ Logs directory created"
fi

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
npm install

# Generate secure secrets if requested
read -p "Would you like to generate secure secrets for JWT and SESSION? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    JWT_SECRET=$(openssl rand -base64 32)
    SESSION_SECRET=$(openssl rand -base64 32)
    
    echo ""
    echo "🔐 Generated secrets:"
    echo "JWT_SECRET=$JWT_SECRET"
    echo "SESSION_SECRET=$SESSION_SECRET"
    echo ""
    echo "Please add these to your .env file"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit .env file with your Certilia credentials"
echo "2. Run 'npm run dev' for development"
echo "3. Run 'npm start' for production"
echo "4. Or use 'docker-compose up' for Docker deployment"