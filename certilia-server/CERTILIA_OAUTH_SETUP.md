# Certilia OAuth2 Application Setup Guide

This guide shows exactly how to fill out the OAuth2 application form on Certilia Dashboard for development with ngrok.

## Step 1: Access Certilia Developer Dashboard

Go to: https://developer.test.certilia.com/services/idp/create

**Note**: This guide is for the TEST environment (idp.test.certilia.com). For production, use the production dashboard and endpoints.

## Step 2: Fill Out the Form

### Section 1: Basic Information

| Field | Value |
|-------|-------|
| **Application Name** | `Flutter Certilia Dev` |
| **Description** | `OAuth2 client for Flutter Certilia SDK development` |
| **Application Type** | Select: `Web Application` |
| **Homepage URL** | `https://uniformly-credible-opossum.ngrok-free.app` |

### Section 2: OAuth2 Configuration

| Field | Value |
|-------|-------|
| **Grant Types** | ✅ Authorization Code<br>✅ Refresh Token<br>❌ Client Credentials<br>❌ Implicit |
| **Response Types** | ✅ `code` only |

### Section 3: Redirect URIs

Add this EXACT URL (copy-paste to avoid typos):

```
https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback
```

⚠️ **IMPORTANT**: 
- No trailing slash!
- Must be HTTPS
- Must match exactly what's in your server config

### Section 4: Scopes

Select ALL of these:
- ✅ `openid` - Required for OpenID Connect
- ✅ `profile` - Access to user profile
- ✅ `eid` - Access to Croatian eID data
- ✅ `email` - User email (if available)
- ✅ `offline_access` - For refresh tokens

### Section 5: Security Settings

| Field | Value |
|-------|-------|
| **Token Endpoint Auth Method** | `client_secret_post` |
| **Require PKCE** | ✅ Yes |
| **PKCE Method** | `S256` |

### Section 6: Token Configuration

| Field | Value | Notes |
|-------|-------|-------|
| **Access Token Lifetime** | `3600` | 1 hour |
| **Refresh Token Lifetime** | `2592000` | 30 days |
| **ID Token Lifetime** | `3600` | 1 hour |
| **Refresh Token Rotation** | ✅ Enabled | Recommended |
| **ID Token Algorithm** | `RS256` | Default |

### Section 7: CORS Settings (if present)

Add these origins:
```
https://uniformly-credible-opossum.ngrok-free.app
http://localhost:8080
http://localhost:3000
http://localhost:4200
```

### Section 8: Additional Settings

| Field | Value |
|-------|-------|
| **Logout URL** | `https://uniformly-credible-opossum.ngrok-free.app` |
| **Terms of Service URL** | Leave empty for dev |
| **Privacy Policy URL** | Leave empty for dev |

## Step 3: Submit and Save Credentials

1. Click **Create Application** or **Submit**

2. You'll receive:
   ```
   Client ID: certilia_xxxxxxxxxxxxxxxxxx
   Client Secret: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

3. **IMMEDIATELY** save these somewhere secure!

## Step 4: Configure Your Server

1. Edit `certilia-server/.env`:

```env
CERTILIA_CLIENT_ID=certilia_your_actual_client_id_here
CERTILIA_CLIENT_SECRET=your_actual_secret_here
```

2. Verify the redirect URI matches:
```env
CERTILIA_REDIRECT_URI=https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback
```

## Common Mistakes to Avoid

### ❌ DON'T:
- Add trailing slashes to URLs
- Use HTTP instead of HTTPS
- Forget to enable all required scopes
- Mix production and test credentials
- Commit credentials to git

### ✅ DO:
- Copy-paste URLs exactly
- Enable PKCE with S256
- Use client_secret_post auth method
- Save credentials securely
- Test immediately after setup

## Verification Checklist

After setup, verify:

- [ ] Application created successfully
- [ ] Client ID starts with `certilia_`
- [ ] Client Secret is saved securely
- [ ] Redirect URI is exactly: `https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback`
- [ ] All 5 scopes are enabled
- [ ] PKCE is required
- [ ] Grant types include Authorization Code and Refresh Token

## Testing Your Setup

1. Start your server:
```bash
cd certilia-server
./dev-start.sh
```

2. In another terminal, start ngrok:
```bash
ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000
```

3. Test the initialization endpoint:
```bash
curl "https://uniformly-credible-opossum.ngrok-free.app/api/auth/initialize?redirect_uri=https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback"
```

If successful, you'll get an authorization URL!

## Troubleshooting

### "Invalid client" Error
- Double-check CLIENT_ID in .env matches Dashboard
- Ensure CLIENT_SECRET is correct
- Wait 1-2 minutes after creating app (propagation delay)

### "Invalid redirect_uri" Error
- Must match EXACTLY what's in Dashboard
- Check for trailing slashes
- Ensure HTTPS protocol

### "Invalid scope" Error
- Verify all scopes are enabled in Dashboard
- Check spelling in server config
- Ensure your app is approved for eid scope

## Production Notes

For production deployment:
1. Create a separate OAuth app
2. Use your production domain
3. Implement proper secret management
4. Enable stricter security settings
5. Set appropriate token lifetimes