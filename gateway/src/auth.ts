/**
 * Device-token auth (M3-T16).
 *
 * The app sends `Authorization: Bearer <device token>`. The expected token is the
 * `DEVICE_TOKEN` Worker secret (HG3, Christopher only). It is never in code or config.
 *
 * Both tokens are hashed with SHA-256 first, so the byte compare always runs over two
 * 32-byte digests: its cost does not depend on where the tokens differ or on their
 * lengths. Missing or empty `DEVICE_TOKEN` fails closed (every request is unauthorized).
 * Tokens are never logged.
 */

const BEARER = /^Bearer[ \t]+(\S+)[ \t]*$/i;

export type AuthResult =
  | { ok: true; tokenKey: string }
  | { ok: false };

/** Extracts the bearer token, or null when the header is missing or malformed. */
export function bearerToken(header: string | null): string | null {
  if (header === null) return null;
  const match = BEARER.exec(header);
  return match ? match[1] : null;
}

/**
 * Constant-time equality for two byte arrays. Visits every index of the longer
 * array and never returns early, so timing does not reveal the first mismatch.
 * Callers pass equal-length SHA-256 digests; unequal lengths still return false.
 */
export function constantTimeEqual(a: ArrayLike<number>, b: ArrayLike<number>): boolean {
  const length = Math.max(a.length, b.length);
  let diff = a.length ^ b.length;
  for (let i = 0; i < length; i += 1) {
    const x = i < a.length ? a[i] : 0;
    const y = i < b.length ? b[i] : 0;
    diff |= x ^ y;
  }
  return diff === 0;
}

async function sha256(text: string): Promise<Uint8Array> {
  const bytes = new TextEncoder().encode(text);
  return new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
}

function hex(bytes: Uint8Array): string {
  let out = "";
  for (const byte of bytes) out += byte.toString(16).padStart(2, "0");
  return out;
}

/**
 * Authenticates a request against `expectedToken`. On success returns a `tokenKey`
 * (SHA-256 hex of the token) so per-token limits never keep the raw token in memory.
 */
export async function authenticate(
  request: Pick<Request, "headers">,
  expectedToken: string | undefined,
): Promise<AuthResult> {
  if (!expectedToken) return { ok: false };
  const presented = bearerToken(request.headers.get("authorization"));
  if (presented === null) return { ok: false };

  const [presentedDigest, expectedDigest] = await Promise.all([
    sha256(presented),
    sha256(expectedToken),
  ]);
  if (!constantTimeEqual(presentedDigest, expectedDigest)) return { ok: false };
  return { ok: true, tokenKey: hex(presentedDigest) };
}
