// Registry of Certilia OAuth clients this proxy can use.
//
// Certilia allows exactly one callback URL per registered client and matches
// it exactly. Each login flow with its own callback (the proxy's own
// /api/auth/callback, a mobile custom scheme, an https App Link / web
// callback page) therefore needs its own client_id/client_secret. The proxy
// picks the client by the redirect_uri the app sends to /api/auth/initialize.
//
// Configuration:
//   CERTILIA_CLIENT_ID / CERTILIA_CLIENT_SECRET / CERTILIA_REDIRECT_URI
//     the default client, used when no other client matches.
//   CERTILIA_CLIENTS (optional)
//     JSON array of additional clients:
//     [{"client_id": "...", "client_secret": "...", "redirect_uri": "..."}]

/**
 * Parse the client list from environment variables.
 * The default client comes first.
 * @param {Object} env - process.env or a test double
 * @returns {Array<{clientId: string, clientSecret: string, redirectUri: string}>}
 */
export function parseClients(env) {
  const clients = [
    {
      clientId: env.CERTILIA_CLIENT_ID,
      clientSecret: env.CERTILIA_CLIENT_SECRET,
      redirectUri: env.CERTILIA_REDIRECT_URI || 'http://localhost:3000/auth/callback',
    },
  ];

  if (env.CERTILIA_CLIENTS && env.CERTILIA_CLIENTS.trim() !== '') {
    let extra;
    try {
      extra = JSON.parse(env.CERTILIA_CLIENTS);
    } catch (e) {
      throw new Error(`CERTILIA_CLIENTS is not valid JSON: ${e.message}`);
    }
    if (!Array.isArray(extra)) {
      throw new Error('CERTILIA_CLIENTS must be a JSON array');
    }
    extra.forEach((c, i) => {
      if (!c.client_id || !c.client_secret || !c.redirect_uri) {
        throw new Error(
          `CERTILIA_CLIENTS[${i}] needs client_id, client_secret and redirect_uri`
        );
      }
      clients.push({
        clientId: c.client_id,
        clientSecret: c.client_secret,
        redirectUri: c.redirect_uri,
      });
    });
  }

  const seen = new Set();
  for (const c of clients) {
    if (seen.has(c.redirectUri)) {
      throw new Error(`Two Certilia clients share redirect_uri ${c.redirectUri}`);
    }
    seen.add(c.redirectUri);
  }

  return clients;
}

/**
 * Pick the client registered for redirectUri. Falls back to the default
 * client, which passes the redirect_uri through to Certilia unchanged;
 * Certilia then rejects it unless it is the default client's callback.
 * @param {Array} clients - result of parseClients
 * @param {string|undefined} redirectUri
 */
export function resolveClientByRedirectUri(clients, redirectUri) {
  return clients.find(c => c.redirectUri === redirectUri) || clients[0];
}

/**
 * Look up a client by client_id (stored in the OAuth session).
 * @param {Array} clients - result of parseClients
 * @param {string|undefined} clientId
 */
export function resolveClientById(clients, clientId) {
  return clients.find(c => c.clientId === clientId) || clients[0];
}
