#!/bin/bash

echo "Testing Certilia OIDC Discovery Endpoints"
echo "=========================================="

echo -e "\n1. Testing TEST environment:"
curl -s https://idp.test.certilia.com/oauth2/oidcdiscovery/.well-known/openid-configuration | jq '.'

echo -e "\n\n2. Testing PRODUCTION environment:"
curl -s https://idp.certilia.com/oauth2/oidcdiscovery/.well-known/openid-configuration | jq '.'