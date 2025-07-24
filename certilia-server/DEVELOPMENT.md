# Development Setup with ngrok

This guide helps you set up the Certilia OAuth2 server for local development using ngrok.

## Prerequisites

1. Node.js 18+ installed
2. ngrok account with static domain
3. Access to Certilia Developer Dashboard

## ngrok Setup

You already have a static ngrok domain: `uniformly-credible-opossum.ngrok-free.app`

To expose your local server:

```bash
ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000
```

## Certilia OAuth2 Application Setup

### 1. Go to Certilia Developer Dashboard

Navigate to: https://developer.test.certilia.com/services/idp/create

### 2. Fill in the OAuth2 Application Form

Use these exact values for development with ngrok:

#### Basic Information
- **Application Name**: `Flutter Certilia Dev` (or your preferred name)
- **Description**: `Development OAuth2 client for Flutter Certilia SDK`
- **Application Type**: `Web Application`
- **Homepage URL**: `https://uniformly-credible-opossum.ngrok-free.app`

#### OAuth2 Settings
- **Grant Types**:
  - ✅ Authorization Code
  - ✅ Refresh Token
  - ❌ Client Credentials
  - ❌ Implicit

- **Redirect URIs** (Add this exact URL):
  ```
  https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback
  ```

- **Allowed Scopes**:
  - ✅ openid
  - ✅ profile
  - ✅ eid
  - ✅ email
  - ✅ offline_access

- **Token Endpoint Authentication Method**: `client_secret_post`

- **Response Types**: `code`

- **PKCE Required**: ✅ Yes (with S256)

#### Advanced Settings
- **ID Token Signing Algorithm**: `RS256`
- **Access Token Lifetime**: `3600` (1 hour)
- **Refresh Token Lifetime**: `2592000` (30 days)
- **Refresh Token Rotation**: ✅ Enabled (recommended)

#### CORS Settings (if available)
- **Allowed Origins**:
  ```
  https://uniformly-credible-opossum.ngrok-free.app
  http://localhost:8080
  http://localhost:3000
  ```

### 3. Save and Note Your Credentials

After creating the application, you'll receive:
- **Client ID**: `certilia_xxxxxxxxxx`
- **Client Secret**: `xxxxxxxxxxxxxxxxxx`

⚠️ **Keep these secure and never commit them to git!**

## Local Server Setup

### 1. Copy Development Environment File

```bash
cd certilia-server
cp .env.development .env
```

### 2. Update .env with Your Credentials

Edit `.env` and add your Certilia credentials:

```env
CERTILIA_CLIENT_ID=certilia_your_actual_client_id
CERTILIA_CLIENT_SECRET=your_actual_client_secret
```

### 3. Generate Secure Secrets

Even for development, use secure secrets:

```bash
# Generate JWT secret
openssl rand -base64 32

# Generate Session secret
openssl rand -base64 32
```

Update these in your `.env` file.

### 4. Install Dependencies

```bash
npm install
```

### 5. Start the Development Server

```bash
npm run dev
```

### 6. Start ngrok

In a separate terminal:

```bash
ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000
```

## Testing the OAuth Flow

### 1. Check Server Health

```bash
curl https://uniformly-credible-opossum.ngrok-free.app/api/health
```

### 2. Initialize OAuth Flow

```bash
curl "https://uniformly-credible-opossum.ngrok-free.app/api/auth/initialize?redirect_uri=https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback"
```

This returns:
```json
{
  "authorization_url": "https://login.certilia.com/oauth/authorize?...",
  "session_id": "uuid",
  "state": "random-state"
}
```

### 3. Test in Browser

Open the `authorization_url` in a browser to test the full flow.

## Flutter App Configuration

Update your Flutter app to use the ngrok URL:

```dart
// Development configuration
const serverUrl = 'https://uniformly-credible-opossum.ngrok-free.app';

final config = CertiliaConfig(
  clientId: 'not-used-by-client',
  redirectUrl: 'com.example.app://callback',
  serverUrl: serverUrl,
);
```

## Troubleshooting

### ngrok Issues

1. **"Tunnel not found" error**
   - Make sure you're using the exact domain: `uniformly-credible-opossum.ngrok-free.app`
   - Check that you're logged into ngrok: `ngrok authtoken YOUR_TOKEN`

2. **CORS errors**
   - Verify `ALLOWED_ORIGINS` in `.env` includes your Flutter app URL
   - Check browser console for specific CORS error messages

### Certilia Issues

1. **"Invalid redirect_uri" error**
   - Ensure the redirect URI in Certilia Dashboard exactly matches:
     `https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback`
   - No trailing slashes!

2. **"Invalid client" error**
   - Double-check CLIENT_ID and CLIENT_SECRET in `.env`
   - Ensure you're using the credentials from the correct environment (test vs production)

3. **"Invalid scope" error**
   - Verify all required scopes are enabled in Certilia Dashboard
   - Check that your app is approved for `eid` scope

### Server Issues

1. **Port 3000 already in use**
   ```bash
   # Find process using port 3000
   lsof -i :3000
   # Kill it if needed
   kill -9 <PID>
   ```

2. **Module not found errors**
   ```bash
   rm -rf node_modules package-lock.json
   npm install
   ```

## Security Notes for Development

Even in development:
1. Never commit `.env` files
2. Use strong secrets for JWT and sessions
3. Keep ngrok URL private if it contains sensitive data
4. Regularly rotate development credentials
5. Don't use production Certilia credentials in development

## Next Steps

1. Test the complete OAuth flow
2. Integrate with your Flutter app
3. Test error scenarios
4. Monitor logs for issues
5. Prepare for production deployment

## Environment Notes

The server is configured to use Certilia TEST environment by default:
- Base URL: `https://idp.test.certilia.com`
- All endpoints use `/oauth2/` prefix (not `/oauth/`)

For production, update the BASE_URL to `https://idp.certilia.com`