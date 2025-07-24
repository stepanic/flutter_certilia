# Certilia OAuth2/OIDC Server Middleware

Node.js middleware server that handles OAuth2/OIDC authentication flow with Certilia IDP for mobile and web applications.

## Overview

This server acts as a secure middleware between your Flutter/mobile applications and Certilia IDP, handling:
- OAuth2 Authorization Code Flow with PKCE
- OpenID Connect (OIDC) authentication
- Token management (access, refresh, ID tokens)
- User profile retrieval
- Session management

## Certilia OAuth2 Application Registration

When registering your application on https://developer.test.certilia.com/services/idp/create, use these settings:

### Application Details
- **Application Name**: Your app name (e.g., "My Mobile App")
- **Application Type**: `Web Application` (even for mobile apps using this middleware)
- **Grant Types**: 
  - ✅ Authorization Code
  - ✅ Refresh Token
  - ❌ Client Credentials (not needed)
  - ❌ Implicit (deprecated)

### OAuth2 Configuration
- **Redirect URIs**: 
  ```
  http://localhost:3000/api/auth/callback
  https://your-production-domain.com/api/auth/callback
  ```
  (Add all environments where your server will run)

- **Allowed Scopes**:
  - ✅ `openid` (required for OIDC)
  - ✅ `profile` (for user profile data)
  - ✅ `eid` (for Croatian eID data)
  - ✅ `email` (if available)
  - ✅ `offline_access` (for refresh tokens)

- **Token Endpoint Authentication Method**: `client_secret_post`

- **Response Types**: `code` (Authorization Code)

- **PKCE**: ✅ Required (S256)

### Additional Settings
- **Allowed CORS Origins**: 
  ```
  http://localhost:8080
  http://localhost:3000
  https://your-flutter-web-app.com
  ```

- **Token Expiration**:
  - Access Token: 3600 seconds (1 hour)
  - Refresh Token: 2592000 seconds (30 days)

- **ID Token Algorithm**: RS256

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  Flutter App    │────▶│  Node.js Server │────▶│  Certilia IDP   │
│                 │◀────│   (Middleware)  │◀────│                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Installation

1. Clone the repository
2. Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

3. Update `.env` with your Certilia credentials:

```env
# Certilia OAuth Configuration
CERTILIA_CLIENT_ID=your_client_id_from_certilia
CERTILIA_CLIENT_SECRET=your_client_secret_from_certilia
CERTILIA_REDIRECT_URI=http://localhost:3000/api/auth/callback

# Security - Generate strong secrets for production!
JWT_SECRET=generate-a-strong-secret-here
SESSION_SECRET=generate-another-strong-secret-here

# CORS - Add your Flutter app URLs
ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000
```

4. Install dependencies:

```bash
npm install
```

## Running the Server

### Development
```bash
npm run dev
```

### Production
```bash
npm start
```

### Docker
```bash
docker-compose up -d
```

## API Endpoints

### 1. Initialize Authorization
```
GET /api/auth/initialize?redirect_uri=YOUR_APP_REDIRECT_URI
```

Starts the OAuth2 flow and returns:
```json
{
  "authorization_url": "https://login.certilia.com/oauth/authorize?...",
  "session_id": "uuid-v4",
  "state": "random-state"
}
```

### 2. OAuth Callback (Handled by Certilia)
```
GET /api/auth/callback?code=AUTH_CODE&state=STATE
```

This endpoint is called by Certilia after user authentication. Returns an HTML page that can be parsed by mobile apps.

### 3. Exchange Code for Tokens
```
POST /api/auth/exchange
Content-Type: application/json

{
  "code": "authorization_code_from_callback",
  "state": "state_from_callback",
  "session_id": "session_id_from_initialize"
}
```

Returns:
```json
{
  "accessToken": "jwt_access_token",
  "refreshToken": "jwt_refresh_token",
  "tokenType": "Bearer",
  "expiresIn": 3600,
  "user": {
    "sub": "user_unique_id",
    "firstName": "Ivo",
    "lastName": "Ivić",
    "oib": "12345678901",
    "email": "ivo@example.com",
    "dateOfBirth": "1990-01-01"
  }
}
```

### 4. Refresh Token
```
POST /api/auth/refresh
Content-Type: application/json

{
  "refresh_token": "your_refresh_token"
}
```

### 5. Get User Info
```
GET /api/auth/user
Authorization: Bearer YOUR_ACCESS_TOKEN
```

### 6. Logout
```
POST /api/auth/logout
Authorization: Bearer YOUR_ACCESS_TOKEN
```

## OIDC Flow Implementation

This server implements the standard OIDC Authorization Code Flow:

1. **User clicks login** → Flutter app calls `/api/auth/initialize`
2. **Server prepares OAuth parameters** → Returns authorization URL with PKCE challenge
3. **App opens authorization URL** → User redirected to Certilia IDP
4. **User authenticates** → Uses Certilia Mobile ID
5. **Certilia redirects back** → To `/api/auth/callback` with authorization code
6. **App extracts code** → From callback HTML or deep link
7. **App exchanges code** → Calls `/api/auth/exchange` with code and session ID
8. **Server validates and exchanges** → Gets tokens from Certilia
9. **Server returns JWT tokens** → App receives access token and user info
10. **App uses access token** → For subsequent API calls

## Security Considerations

1. **PKCE Implementation**: Server automatically generates and validates PKCE parameters
2. **State Validation**: Prevents CSRF attacks
3. **Session Management**: Temporary sessions expire after 10 minutes
4. **Token Security**: 
   - Access tokens expire in 1 hour
   - Refresh tokens expire in 7 days
   - All tokens are signed with HS256
5. **CORS Protection**: Only configured origins allowed
6. **Rate Limiting**: 100 requests per 15 minutes per IP
7. **HTTPS Required**: Use HTTPS in production

## Flutter Integration

Update your Flutter app to use this middleware:

```dart
// Configure the client to use your Node.js server
final config = CertiliaConfig(
  clientId: 'not-needed-for-client', // Server handles this
  redirectUrl: 'your-app://callback',
  serverUrl: 'http://localhost:3000', // Your Node.js server
);

// Initialize auth flow
final response = await http.get(
  Uri.parse('${config.serverUrl}/api/auth/initialize?redirect_uri=${config.redirectUrl}'),
);

final data = jsonDecode(response.body);
final authUrl = data['authorization_url'];
final sessionId = data['session_id'];

// Open authUrl in browser/webview
// ... handle callback ...

// Exchange code for tokens
final tokenResponse = await http.post(
  Uri.parse('${config.serverUrl}/api/auth/exchange'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'code': extractedCode,
    'state': extractedState,
    'session_id': sessionId,
  }),
);
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `NODE_ENV` | Environment (development/production) | No |
| `PORT` | Server port (default: 3000) | No |
| `CERTILIA_CLIENT_ID` | OAuth2 client ID from Certilia | Yes |
| `CERTILIA_CLIENT_SECRET` | OAuth2 client secret from Certilia | Yes |
| `CERTILIA_REDIRECT_URI` | OAuth2 callback URL | Yes |
| `JWT_SECRET` | Secret for signing JWT tokens | Yes |
| `SESSION_SECRET` | Secret for session management | Yes |
| `ALLOWED_ORIGINS` | Comma-separated CORS origins | Yes |
| `REDIS_URL` | Redis connection URL | No |
| `LOG_LEVEL` | Logging level (info/debug/error) | No |

## Production Deployment

1. **Use HTTPS**: Required for OAuth2 security
2. **Set strong secrets**: Generate cryptographically secure secrets
3. **Configure Redis**: For production session storage
4. **Set up monitoring**: Use the `/api/health` endpoints
5. **Configure reverse proxy**: Use Nginx for SSL termination
6. **Enable rate limiting**: Adjust limits based on your needs

## Health Checks

- `GET /api/health` - Basic health check
- `GET /api/health/ready` - Readiness probe
- `GET /api/health/stats` - Server statistics

## License

MIT