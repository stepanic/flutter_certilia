# Certilia OAuth2 Setup Guide

Quick reference for setting up OAuth2 application in Certilia Dashboard.

## Dashboard URLs

- **TEST**: https://developer.test.certilia.com/services/idp/create
- **PRODUCTION**: https://developer.certilia.com/services/idp/create

## Required Settings

### OAuth2 Configuration
- **Application Type**: Web Application
- **Grant Types**: Authorization Code, Refresh Token
- **Response Types**: code
- **Redirect URI**: `https://your-domain.ngrok-free.app/api/auth/callback`
- **Scopes**: openid, profile, eid, email, offline_access
- **Token Auth Method**: client_secret_post
- **PKCE**: Required (S256)

### Token Lifetimes
- **Access Token**: 3600 seconds (1 hour)
- **Refresh Token**: 2592000 seconds (30 days)
- **ID Token Algorithm**: RS256

## After Creation

1. Save your credentials:
   - Client ID: `certilia_xxxxxxxxxx`
   - Client Secret: `xxxxxxxxxxxxxxxxxx`

2. Configure your `.env.local` (TEST) or `.env.local.production` (PROD):
   ```env
   CERTILIA_CLIENT_ID=your_client_id
   CERTILIA_CLIENT_SECRET=your_client_secret
   CERTILIA_REDIRECT_URI=https://your-domain.ngrok-free.app/api/auth/callback
   ```

3. Start server:
   ```bash
   npm run dev:test  # for TEST
   npm run dev:prod  # for PRODUCTION
   ```