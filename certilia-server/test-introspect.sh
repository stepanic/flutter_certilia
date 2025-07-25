#!/bin/bash

# Test token introspection
echo "Testing Token Introspection"
echo "==========================="

# These should be provided as arguments or extracted from your token response
ACCESS_TOKEN=$1
CLIENT_ID="1a6ec445bbe092c1465f3d19aea9757e3e278a75"
CLIENT_SECRET="c902f1e7ae253022d45050526df49525b02eea95"

if [ -z "$ACCESS_TOKEN" ]; then
    echo "Usage: ./test-introspect.sh <access_token>"
    exit 1
fi

echo "Introspecting token..."
curl -X POST https://idp.certilia.com/oauth2/introspect \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -d "token=$ACCESS_TOKEN" | jq '.'