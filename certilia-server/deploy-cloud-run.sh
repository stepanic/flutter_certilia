#!/bin/bash

# ====================================================================
# Deploy Certilia Server to Google Cloud Run
# ====================================================================
# This script deploys the Node.js OAuth proxy server to Cloud Run
# Make sure you have gcloud CLI installed and authenticated
# ====================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Deploying Certilia Server to Google Cloud Run${NC}"
echo "=================================================="

# Configuration
SERVICE_NAME="certilia-server"
REGION="europe-west1"
PLATFORM="managed"

# Prompt for environment
echo -e "\n${YELLOW}Select environment:${NC}"
echo "1) TEST (idp.test.certilia.com)"
echo "2) PRODUCTION (idp.certilia.com)"
read -p "Enter choice [1-2]: " env_choice

case $env_choice in
    1)
        ENV_TYPE="test"
        CERTILIA_BASE_URL="https://idp.test.certilia.com"
        CLIENT_ID="991dffbb1cdd4d51423e1a5de323f13b15256c63"
        CLIENT_SECRET="997a2a9a810db68286ad0c250a2d2f5cd469f15f"
        echo -e "${GREEN}✅ Using TEST environment${NC}"
        ;;
    2)
        ENV_TYPE="production"
        CERTILIA_BASE_URL="https://idp.certilia.com"
        CLIENT_ID="1a6ec445bbe092c1465f3d19aea9757e3e278a75"
        CLIENT_SECRET="c902f1e7ae253022d45050526df49525b02eea95"
        echo -e "${GREEN}✅ Using PRODUCTION environment${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice. Exiting.${NC}"
        exit 1
        ;;
esac

# Get project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ No GCP project configured. Run: gcloud config set project YOUR_PROJECT_ID${NC}"
    exit 1
fi

echo -e "\n${BLUE}📋 Deployment Configuration:${NC}"
echo "Project ID: $PROJECT_ID"
echo "Service Name: $SERVICE_NAME"
echo "Region: $REGION"
echo "Environment: $ENV_TYPE"
echo "Certilia URL: $CERTILIA_BASE_URL"

# Generate secure secrets
JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(64).toString('hex'))")
SESSION_SECRET=$(node -e "console.log(require('crypto').randomBytes(64).toString('hex'))")

echo -e "\n${YELLOW}🔐 Generated secure secrets for JWT and Session${NC}"

# Prompt for CORS origins
read -p "Enter allowed CORS origins (comma-separated) [default: *]: " CORS_ORIGINS
if [ -z "$CORS_ORIGINS" ]; then
    CORS_ORIGINS="*"
fi

# Build and deploy
echo -e "\n${YELLOW}🏗️  Building and deploying to Cloud Run...${NC}"

gcloud run deploy $SERVICE_NAME \
    --source . \
    --region $REGION \
    --platform $PLATFORM \
    --allow-unauthenticated \
    --set-env-vars "NODE_ENV=production" \
    --set-env-vars "PORT=8080" \
    --set-env-vars "CERTILIA_CLIENT_ID=$CLIENT_ID" \
    --set-env-vars "CERTILIA_BASE_URL=$CERTILIA_BASE_URL" \
    --set-env-vars "CERTILIA_AUTH_ENDPOINT=/oauth2/authorize" \
    --set-env-vars "CERTILIA_TOKEN_ENDPOINT=/oauth2/token" \
    --set-env-vars "CERTILIA_USERINFO_ENDPOINT=/oauth2/userinfo" \
    --set-env-vars "CERTILIA_DISCOVERY_ENDPOINT=/oauth2/oidcdiscovery/.well-known/openid-configuration" \
    --set-env-vars "JWT_SECRET=$JWT_SECRET" \
    --set-env-vars "SESSION_SECRET=$SESSION_SECRET" \
    --set-env-vars "ALLOWED_ORIGINS=$CORS_ORIGINS" \
    --set-env-vars "LOG_LEVEL=info" \
    --set-env-vars "RATE_LIMIT_WINDOW_MS=900000" \
    --set-env-vars "RATE_LIMIT_MAX_REQUESTS=100" \
    --update-secrets "CERTILIA_CLIENT_SECRET=$SERVICE_NAME-client-secret:latest" \
    --memory 512Mi \
    --cpu 1 \
    --concurrency 80 \
    --max-instances 10 \
    --timeout 60

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✅ Deployment successful!${NC}"

    # Get service URL
    SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)')

    echo -e "\n${BLUE}📋 Deployment Summary:${NC}"
    echo "Service URL: $SERVICE_URL"
    echo "Health Check: $SERVICE_URL/api/health"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT NEXT STEPS:${NC}"
    echo "1. Create the Cloud Run secret for CLIENT_SECRET:"
    echo -e "   ${GREEN}echo -n \"$CLIENT_SECRET\" | gcloud secrets create $SERVICE_NAME-client-secret --data-file=-${NC}"
    echo ""
    echo "2. Grant Cloud Run access to the secret:"
    echo -e "   ${GREEN}gcloud secrets add-iam-policy-binding $SERVICE_NAME-client-secret \\
      --member=serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com \\
      --role=roles/secretmanager.secretAccessor${NC}"
    echo ""
    echo "3. Update Certilia redirect URI in Certilia admin portal:"
    echo -e "   ${GREEN}$SERVICE_URL/api/auth/callback${NC}"
    echo ""
    echo "4. Update your Flutter app with the server URL:"
    echo -e "   ${GREEN}serverUrl: '$SERVICE_URL'${NC}"
    echo ""
    echo -e "${GREEN}🎉 All done! Test your deployment at: $SERVICE_URL${NC}"
else
    echo -e "\n${RED}❌ Deployment failed. Check the error messages above.${NC}"
    exit 1
fi