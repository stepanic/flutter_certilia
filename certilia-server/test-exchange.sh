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
