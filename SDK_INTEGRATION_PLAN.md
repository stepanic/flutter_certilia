# CertiliaSDK Integration Plan

## Overview
Plan for transforming the current flutter_certilia library into a generalized SDK that can be easily integrated into any Flutter application with minimal configuration.

## Current State Analysis

### Library Configuration (flutter_certilia)
Currently hardcoded in `lib/src/constants.dart`:
- Base URL: `https://idp.test.certilia.com`
- OAuth endpoints (authorization, token, userinfo, discovery)
- Default scopes: `['openid', 'profile', 'eid']`

### Example App Configuration
Hardcoded across multiple example files:
- Client ID: `991dffbb1cdd4d51423e1a5de323f13b15256c63`
- Server URL: `https://uniformly-credible-opossum.ngrok-free.app`
- Redirect URLs vary by platform

## Proposed .env Configuration

```env
# Core OAuth Configuration
CERTILIA_CLIENT_ID=your_client_id_here
CERTILIA_CLIENT_SECRET=your_client_secret_here
CERTILIA_REDIRECT_URL=com.example.app://callback

# Server Mode (for web and WebView implementations)
CERTILIA_SERVER_URL=https://your-server.com

# IDP Endpoints
CERTILIA_BASE_URL=https://idp.test.certilia.com
CERTILIA_AUTHORIZATION_ENDPOINT=${CERTILIA_BASE_URL}/oauth2/authorize
CERTILIA_TOKEN_ENDPOINT=${CERTILIA_BASE_URL}/oauth2/token
CERTILIA_USERINFO_ENDPOINT=${CERTILIA_BASE_URL}/oauth2/userinfo
CERTILIA_DISCOVERY_URL=${CERTILIA_BASE_URL}/oauth2/oidcdiscovery/.well-known/openid-configuration

# OAuth Scopes (space-separated)
CERTILIA_SCOPES=openid profile eid email offline_access

# Feature Flags
CERTILIA_ENABLE_LOGGING=false
CERTILIA_PREFER_EPHEMERAL_SESSION=true

# Session Configuration
CERTILIA_SESSION_TIMEOUT=3600000  # 1 hour in milliseconds
CERTILIA_REFRESH_TOKEN_TIMEOUT=2592000000  # 30 days in milliseconds
```

## SDK Architecture

### 1. Configuration Management
- Auto-load from `.env` file
- Support for multiple environments (dev, test, prod)
- Override capability for runtime configuration

### 2. Platform-Adaptive Implementation
```dart
// SDK automatically selects the best auth method
final certilia = await CertiliaSDK.initialize();
```

Platform detection logic:
- **iOS/Android**: Use AppAuth with fallback to WebView
- **Web**: Use popup/redirect flow with server support
- **Desktop**: Use WebView implementation

### 3. Simplified API

#### Installation
```yaml
dependencies:
  certilia_sdk: ^1.0.0
```

#### Basic Usage
```dart
// 1. Initialize (auto-loads .env)
final certilia = await CertiliaSDK.initialize();

// 2. Authenticate
final user = await certilia.authenticate();

// 3. Get user info
print('Welcome ${user.fullName}');

// 4. Logout
await certilia.logout();
```

#### Advanced Usage
```dart
// Custom configuration
final certilia = await CertiliaSDK.initialize(
  configPath: 'assets/.env.production',
  config: CertiliaConfig(
    clientId: 'override_client_id',
    enableLogging: true,
  ),
);

// Extended user info
final extendedInfo = await certilia.getExtendedUserInfo();

// Token management
await certilia.refreshToken();
final accessToken = certilia.currentAccessToken;
```

### 4. Migration Path

#### Step 1: Add Environment Support
- Add `flutter_dotenv` dependency
- Create `.env` loader in SDK
- Update `CertiliaConfig` to support env variables

#### Step 2: Create Factory Pattern
```dart
class CertiliaSDK {
  static Future<CertiliaClient> initialize({
    String? configPath,
    CertiliaConfig? config,
  }) async {
    // Load .env if not already loaded
    final envConfig = await _loadEnvironmentConfig(configPath);
    
    // Merge with provided config
    final finalConfig = _mergeConfigs(envConfig, config);
    
    // Auto-select implementation
    return _createClient(finalConfig);
  }
}
```

#### Step 3: Simplify Exports
Single import for all functionality:
```dart
import 'package:certilia_sdk/certilia_sdk.dart';
```

### 5. Documentation Structure

```
docs/
├── README.md              # Quick start guide
├── INSTALLATION.md        # Detailed setup instructions
├── CONFIGURATION.md       # Environment variables reference
├── PLATFORMS.md          # Platform-specific notes
├── MIGRATION.md          # Migration from flutter_certilia
└── examples/
    ├── basic/            # Minimal example
    ├── advanced/         # Full-featured example
    └── server/           # Backend integration example
```

## Implementation Timeline

### Phase 1: Environment Configuration (Week 1)
- [ ] Add flutter_dotenv dependency
- [ ] Create environment loader
- [ ] Update CertiliaConfig
- [ ] Add .env.example file

### Phase 2: SDK Wrapper (Week 2)
- [ ] Create CertiliaSDK class
- [ ] Implement factory pattern
- [ ] Add platform detection
- [ ] Create unified API

### Phase 3: Documentation (Week 3)
- [ ] Write installation guide
- [ ] Create usage examples
- [ ] Document all env variables
- [ ] Add migration guide

### Phase 4: Testing & Publishing (Week 4)
- [ ] Comprehensive testing
- [ ] Example apps for each platform
- [ ] Publish to pub.dev
- [ ] Create GitHub release

## Benefits

1. **Ease of Integration**: Single line initialization
2. **Configuration Management**: Environment-based config
3. **Platform Agnostic**: Works on all Flutter platforms
4. **Secure**: No hardcoded credentials
5. **Flexible**: Easy to switch between environments
6. **Maintainable**: Clear separation of concerns

## Next Steps

1. Review and approve this plan
2. Create feature branch for SDK development
3. Begin Phase 1 implementation
4. Set up CI/CD for automated testing