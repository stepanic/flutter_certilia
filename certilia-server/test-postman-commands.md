# Postman Curl Commands for Testing Extended Info Endpoint

## Prerequisites
First, you need to complete OAuth flow to get an access token. You can use the test-complete-flow.sh script and save the tokens.

## 1. Source the saved tokens
After running `./test-complete-flow.sh`, tokens are saved to `/tmp/certilia_tokens.sh`:

```bash
source /tmp/certilia_tokens.sh
```

## 2. Test Extended User Info Endpoint

### Basic curl command:
```bash
curl -X GET https://uniformly-credible-opossum.ngrok-free.app/api/user/extended-info \
  -H "Authorization: Bearer $CERTILIA_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "ngrok-skip-browser-warning: true"
```

### Verbose curl command with full headers:
```bash
curl -v -X GET https://uniformly-credible-opossum.ngrok-free.app/api/user/extended-info \
  -H "Authorization: Bearer $CERTILIA_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "ngrok-skip-browser-warning: true" \
  -H "Accept: application/json"
```

### With response headers and HTTP status:
```bash
curl -i -X GET https://uniformly-credible-opossum.ngrok-free.app/api/user/extended-info \
  -H "Authorization: Bearer $CERTILIA_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "ngrok-skip-browser-warning: true"
```

## 3. Import to Postman

### Step 1: Create new request
- Method: `GET`
- URL: `https://uniformly-credible-opossum.ngrok-free.app/api/user/extended-info`

### Step 2: Set Headers
- `Authorization`: `Bearer YOUR_ACCESS_TOKEN_HERE`
- `Content-Type`: `application/json`
- `ngrok-skip-browser-warning`: `true`

### Step 3: Replace YOUR_ACCESS_TOKEN_HERE
After running the OAuth flow, copy the access token from the test script output and paste it in place of `YOUR_ACCESS_TOKEN_HERE`.

## 4. Debug Endpoints (if ENABLE_DEBUG_ENDPOINTS=true)

### Test JWT validation directly:
```bash
curl -X GET https://uniformly-credible-opossum.ngrok-free.app/api/debug/validate-jwt \
  -H "Authorization: Bearer $CERTILIA_ACCESS_TOKEN" \
  -H "ngrok-skip-browser-warning: true"
```

### Get server environment info:
```bash
curl -X GET https://uniformly-credible-opossum.ngrok-free.app/api/debug/env \
  -H "ngrok-skip-browser-warning: true"
```

### Check token info:
```bash
curl -X GET https://uniformly-credible-opossum.ngrok-free.app/api/debug/token-info \
  -H "Authorization: Bearer $CERTILIA_ACCESS_TOKEN" \
  -H "ngrok-skip-browser-warning: true"
```

## 5. Raw Postman Collection JSON

You can import this directly into Postman:

```json
{
  "info": {
    "name": "Certilia Extended Info Test",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Get Extended User Info",
      "request": {
        "method": "GET",
        "header": [
          {
            "key": "Authorization",
            "value": "Bearer {{access_token}}",
            "type": "text"
          },
          {
            "key": "Content-Type",
            "value": "application/json",
            "type": "text"
          },
          {
            "key": "ngrok-skip-browser-warning",
            "value": "true",
            "type": "text"
          }
        ],
        "url": {
          "raw": "https://uniformly-credible-opossum.ngrok-free.app/api/user/extended-info",
          "protocol": "https",
          "host": ["uniformly-credible-opossum", "ngrok-free", "app"],
          "path": ["api", "user", "extended-info"]
        }
      }
    },
    {
      "name": "Validate JWT",
      "request": {
        "method": "GET",
        "header": [
          {
            "key": "Authorization",
            "value": "Bearer {{access_token}}",
            "type": "text"
          },
          {
            "key": "ngrok-skip-browser-warning",
            "value": "true",
            "type": "text"
          }
        ],
        "url": {
          "raw": "https://uniformly-credible-opossum.ngrok-free.app/api/debug/validate-jwt",
          "protocol": "https",
          "host": ["uniformly-credible-opossum", "ngrok-free", "app"],
          "path": ["api", "debug", "validate-jwt"]
        }
      }
    },
    {
      "name": "Token Info",
      "request": {
        "method": "GET",
        "header": [
          {
            "key": "Authorization",
            "value": "Bearer {{access_token}}",
            "type": "text"
          },
          {
            "key": "ngrok-skip-browser-warning",
            "value": "true",
            "type": "text"
          }
        ],
        "url": {
          "raw": "https://uniformly-credible-opossum.ngrok-free.app/api/debug/token-info",
          "protocol": "https",
          "host": ["uniformly-credible-opossum", "ngrok-free", "app"],
          "path": ["api", "debug", "token-info"]
        }
      }
    }
  ],
  "variable": [
    {
      "key": "access_token",
      "value": "PASTE_YOUR_ACCESS_TOKEN_HERE",
      "type": "string"
    }
  ]
}
```

## 6. Troubleshooting Production Issues

The main difference between TEST and PROD environments:

### TEST Environment (.env.local):
- `SKIP_USERINFO_ENDPOINT=false`
- Calls Certilia's `/oauth2/userinfo` endpoint
- Returns full user data from userinfo endpoint

### PROD Environment (.env.local.production):
- `SKIP_USERINFO_ENDPOINT=true`
- Skips userinfo endpoint entirely
- Uses ID token claims directly (line 39-95 in userController.js)
- This is because production userinfo endpoint has token binding issues

### What to check:
1. Verify the ID token contains user claims:
   ```bash
   echo $CERTILIA_ID_TOKEN | cut -d. -f2 | base64 -d | jq .
   ```

2. Check if the server is actually using PROD config:
   ```bash
   curl https://uniformly-credible-opossum.ngrok-free.app/api/debug/env \
     -H "ngrok-skip-browser-warning: true" | jq .
   ```

3. Check JWT validation and what's in the token:
   ```bash
   curl https://uniformly-credible-opossum.ngrok-free.app/api/debug/token-info \
     -H "Authorization: Bearer $CERTILIA_ACCESS_TOKEN" \
     -H "ngrok-skip-browser-warning: true" | jq .
   ```

## 7. Manual Token Extraction

If you need to manually extract tokens from the OAuth callback:

```bash
# After authentication, copy the full callback URL
CALLBACK_URL="https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback?code=YOUR_CODE&state=YOUR_STATE"

# Extract code and state
CODE=$(echo "$CALLBACK_URL" | grep -o 'code=[^&]*' | cut -d= -f2)
STATE=$(echo "$CALLBACK_URL" | grep -o 'state=[^&]*' | cut -d= -f2)

# Exchange for tokens
curl -X POST https://uniformly-credible-opossum.ngrok-free.app/api/auth/exchange \
  -H "Content-Type: application/json" \
  -H "ngrok-skip-browser-warning: true" \
  -d "{
    \"code\": \"$CODE\",
    \"state\": \"$STATE\",
    \"session_id\": \"YOUR_SESSION_ID\"
  }"
```

## Notes

- The access token is a JWT issued by your server, not by Certilia directly
- The server stores Certilia's tokens internally and issues its own JWT
- The extended-info endpoint requires the server's JWT in the Authorization header
- Debug endpoints help troubleshoot what data is available in the tokens