# Certilia OAuth2 Server

Node.js middleware server that handles OAuth2/OIDC authentication flow with Certilia IDP for Flutter applications.

## Quick Start

### Prerequisites
- Node.js 18+
- ngrok (for local development)

### Installation
```bash
npm install
```

### Running the Server

#### TEST Environment (idp.test.certilia.com)
```bash
npm run dev:test
```

#### PRODUCTION Environment (idp.certilia.com)
```bash
npm run dev:prod
```

Both commands automatically:
- Copy the correct `.env` file
- Start server with auto-reload
- Use the appropriate Certilia endpoint

### Development with ngrok
```bash
# Terminal 1
ngrok http --url=your-domain.ngrok-free.app 3000

# Terminal 2
npm run dev:test  # or dev:prod
```

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Flutter App    │────▶│  Node.js Server │────▶│  Certilia IDP   │
│                 │◀────│   (Middleware)  │◀────│                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## API Endpoints

### Initialize Authorization
```
GET /api/auth/initialize?redirect_uri=YOUR_APP_REDIRECT_URI
```
Returns:
- `authorization_url`: URL to redirect user for authentication
- `session_id`: Session identifier for this auth flow
- `state`: CSRF protection state parameter

### Exchange Code for Tokens
```
POST /api/auth/exchange
```
Body:
```json
{
  "code": "authorization_code",
  "state": "state_from_callback",
  "session_id": "session_id_from_initialize"
}
```
Returns: Access token, refresh token, ID token, and user information

### Refresh Token
```
POST /api/auth/refresh
```
Body:
```json
{
  "refresh_token": "your_refresh_token"
}
```

### Get User Info
```
GET /api/auth/user
Authorization: Bearer YOUR_ACCESS_TOKEN
```

### Get Extended User Info
```
GET /api/user/extended-info
Authorization: Bearer YOUR_ACCESS_TOKEN
```
Returns all available user fields from Certilia

### Health Check
```
GET /api/health
```

## Environment Configuration

Create `.env.local` for TEST environment:
```env
NODE_ENV=development
PORT=3000

# Certilia OAuth Config
CERTILIA_BASE_URL=https://idp.test.certilia.com
CERTILIA_CLIENT_ID=your_client_id
CERTILIA_CLIENT_SECRET=your_client_secret
CERTILIA_REDIRECT_URI=https://your-domain.ngrok-free.app/api/auth/callback

# Security
JWT_SECRET=your_jwt_secret
SESSION_SECRET=your_session_secret

# CORS
ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000
```

Create `.env.local.production` for PRODUCTION environment with production credentials.

## Available Scripts

| Command | Description |
|---------|-------------|
| `npm run dev:test` | Start with TEST environment |
| `npm run dev:prod` | Start with PRODUCTION environment |
| `npm run dev` | Start with current .env |
| `npm run switch:test` | Switch to TEST config (without starting) |
| `npm run switch:prod` | Switch to PROD config (without starting) |
| `npm start` | Production mode (no auto-reload) |

## Testing

### Test OAuth Flow
```bash
./test-oauth-flow.sh
```

### Test Both Environments
```bash
./test-both-environments.sh
```

### Compare Extended Info (TEST vs PROD)
```bash
./compare-extended-info.sh
```

## Security Notes

1. **Never commit credentials** - Use environment variables
2. **PKCE Required** - Server implements PKCE for OAuth security
3. **Session Management** - Sessions expire after 10 minutes
4. **Token Security** - Access tokens expire in 1 hour
5. **CORS Protection** - Only configured origins allowed
6. **Rate Limiting** - Configured per IP

## Deployment

### Google Cloud Run
```bash
./deploy-cloud-run.sh
# Enter credentials when prompted
```

### Docker
```bash
docker build -t certilia-server .
docker run -p 3000:3000 --env-file .env certilia-server
```

## License

MIT