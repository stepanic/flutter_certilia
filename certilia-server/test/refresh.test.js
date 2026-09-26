import { jest } from '@jest/globals';
import jwt from 'jsonwebtoken';

// The session services start cleanup intervals when imported.
jest.useFakeTimers();

process.env.CERTILIA_CLIENT_ID ??= 'test-client';
process.env.CERTILIA_CLIENT_SECRET ??= 'test-secret';
process.env.JWT_SECRET ??= 'test-jwt-secret';

const { default: tokenService } = await import('../src/services/tokenService.js');
const { refreshToken } = await import('../src/controllers/authController.js');
const { config } = await import('../src/config/index.js');

/** Calls the /refresh controller; resolves with {status, body} or the error. */
function callRefresh(body) {
  return new Promise((resolve) => {
    const res = { json: (b) => resolve({ status: 200, body: b }) };
    refreshToken({ body, headers: {} }, res, (error) => resolve({ error }));
  });
}

const user = {
  sub: '12345678903',
  given_name: 'Ana',
  family_name: 'Horvat',
  email: 'ana@example.com',
  certilia_tokens: { access_token: 'cat', id_token: 'cit' },
};

describe('POST /api/auth/refresh', () => {
  test('keeps the user claims and certilia_tokens', async () => {
    const pair = tokenService.generateTokenPair(user);
    const r = await callRefresh({ refresh_token: pair.refreshToken, access_token: pair.accessToken });
    expect(r.status).toBe(200);
    const claims = jwt.decode(r.body.accessToken);
    expect(claims).toMatchObject({
      sub: user.sub,
      given_name: 'Ana',
      family_name: 'Horvat',
      email: 'ana@example.com',
      certilia_tokens: user.certilia_tokens,
      type: 'access',
    });
  });

  test('accepts an expired access token', async () => {
    const pair = tokenService.generateTokenPair(user);
    const expired = jwt.sign(
      { ...jwt.decode(pair.accessToken), exp: Math.floor(Date.now() / 1000) - 60 },
      config.jwt.secret,
      { algorithm: 'HS256' },
    );
    const r = await callRefresh({ refresh_token: pair.refreshToken, access_token: expired });
    expect(r.status).toBe(200);
    expect(jwt.decode(r.body.accessToken).given_name).toBe('Ana');
  });

  test('refuses an access token signed with another secret', async () => {
    const pair = tokenService.generateTokenPair(user);
    const forged = jwt.sign({ ...user, type: 'access', given_name: 'Mallory' }, 'other-secret', {
      algorithm: 'HS256',
    });
    const r = await callRefresh({ refresh_token: pair.refreshToken, access_token: forged });
    expect(r.error).toBeDefined();
    expect(r.error.message).toBe('Invalid access token');
  });

  test("refuses another user's access token", async () => {
    const mine = tokenService.generateTokenPair(user);
    const theirs = tokenService.generateTokenPair({ ...user, sub: '00000000001' });
    const r = await callRefresh({ refresh_token: mine.refreshToken, access_token: theirs.accessToken });
    expect(r.error).toBeDefined();
    expect(r.error.message).toBe('Access token belongs to another user');
  });

  test('refuses a refresh token passed as the access token', async () => {
    const pair = tokenService.generateTokenPair(user);
    const r = await callRefresh({ refresh_token: pair.refreshToken, access_token: pair.refreshToken });
    expect(r.error.message).toBe('Invalid token type');
  });

  test('without an access token, refreshes with sub only', async () => {
    const pair = tokenService.generateTokenPair(user);
    const r = await callRefresh({ refresh_token: pair.refreshToken });
    expect(r.status).toBe(200);
    const claims = jwt.decode(r.body.accessToken);
    expect(claims.sub).toBe(user.sub);
    expect(claims.given_name).toBeUndefined();
  });
});
