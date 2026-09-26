import { parseClients, resolveClientByRedirectUri, resolveClientById } from '../src/config/clients.js';

const base = {
  CERTILIA_CLIENT_ID: 'default-id',
  CERTILIA_CLIENT_SECRET: 'default-secret',
  CERTILIA_REDIRECT_URI: 'https://proxy.example/api/auth/callback',
};

describe('parseClients', () => {
  test('default client only', () => {
    const clients = parseClients(base);
    expect(clients).toHaveLength(1);
    expect(clients[0]).toEqual({
      clientId: 'default-id',
      clientSecret: 'default-secret',
      redirectUri: 'https://proxy.example/api/auth/callback',
    });
  });

  test('extra clients from CERTILIA_CLIENTS', () => {
    const clients = parseClients({
      ...base,
      CERTILIA_CLIENTS: JSON.stringify([
        { client_id: 'native-id', client_secret: 'native-secret', redirect_uri: 'hr.example.app:1/callback' },
      ]),
    });
    expect(clients.map(c => c.clientId)).toEqual(['default-id', 'native-id']);
  });

  test('rejects invalid JSON', () => {
    expect(() => parseClients({ ...base, CERTILIA_CLIENTS: '[{' })).toThrow(/not valid JSON/);
  });

  test('rejects a non-array', () => {
    expect(() => parseClients({ ...base, CERTILIA_CLIENTS: '{}' })).toThrow(/JSON array/);
  });

  test('rejects an entry without a secret', () => {
    expect(() =>
      parseClients({ ...base, CERTILIA_CLIENTS: JSON.stringify([{ client_id: 'x', redirect_uri: 'y' }]) })
    ).toThrow(/CERTILIA_CLIENTS\[0\]/);
  });

  test('rejects two clients with the same redirect_uri', () => {
    expect(() =>
      parseClients({
        ...base,
        CERTILIA_CLIENTS: JSON.stringify([
          { client_id: 'x', client_secret: 's', redirect_uri: base.CERTILIA_REDIRECT_URI },
        ]),
      })
    ).toThrow(/share redirect_uri/);
  });
});

describe('client resolution', () => {
  const clients = parseClients({
    ...base,
    CERTILIA_CLIENTS: JSON.stringify([
      { client_id: 'native-id', client_secret: 'native-secret', redirect_uri: 'hr.example.app:1/callback' },
    ]),
  });

  test('picks the client registered for the redirect_uri', () => {
    expect(resolveClientByRedirectUri(clients, 'hr.example.app:1/callback').clientId).toBe('native-id');
  });

  test('falls back to the default client for an unknown redirect_uri', () => {
    expect(resolveClientByRedirectUri(clients, 'https://other.example/cb').clientId).toBe('default-id');
    expect(resolveClientByRedirectUri(clients, undefined).clientId).toBe('default-id');
  });

  test('finds a client by id, default when missing', () => {
    expect(resolveClientById(clients, 'native-id').clientSecret).toBe('native-secret');
    expect(resolveClientById(clients, undefined).clientId).toBe('default-id');
  });
});
