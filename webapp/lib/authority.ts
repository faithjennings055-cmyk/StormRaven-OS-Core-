import crypto from "node:crypto"

// Minimal HS256 JWT implementation for the "authority token" issued after the
// time-gated TOTP handshake. Signed with BETTER_AUTH_SECRET.

const SECRET = process.env.BETTER_AUTH_SECRET ?? "insecure-dev-secret"

function b64url(input: Buffer | string): string {
  return Buffer.from(input)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")
}

function b64urlJson(obj: unknown): string {
  return b64url(JSON.stringify(obj))
}

function sign(data: string): string {
  return b64url(crypto.createHmac("sha256", SECRET).update(data).digest())
}

export type AuthorityClaims = {
  sub: string // userId
  amr: string[] // authentication methods, e.g. ["pwd", "totp"]
  iat: number
  exp: number
}

export function issueAuthority(userId: string, ttlSeconds = 60 * 60 * 8): string {
  const header = { alg: "HS256", typ: "JWT" }
  const now = Math.floor(Date.now() / 1000)
  const payload: AuthorityClaims = {
    sub: userId,
    amr: ["pwd", "totp"],
    iat: now,
    exp: now + ttlSeconds,
  }
  const head = b64urlJson(header)
  const body = b64urlJson(payload)
  const sig = sign(`${head}.${body}`)
  return `${head}.${body}.${sig}`
}

export function verifyAuthority(token: string | undefined): AuthorityClaims | null {
  if (!token) return null
  const parts = token.split(".")
  if (parts.length !== 3) return null
  const [head, body, sig] = parts
  const expected = sign(`${head}.${body}`)
  // constant-time compare
  const a = Buffer.from(sig)
  const b = Buffer.from(expected)
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null
  try {
    const payload = JSON.parse(
      Buffer.from(body.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString(),
    ) as AuthorityClaims
    if (payload.exp * 1000 < Date.now()) return null
    return payload
  } catch {
    return null
  }
}

export const AUTHORITY_COOKIE = "forge_authority"
