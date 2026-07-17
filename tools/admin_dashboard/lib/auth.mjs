import crypto from "node:crypto";

export const PASSWORD_MIN_LENGTH = 12;
export const PASSWORD_MAX_LENGTH = 128;
export const USERNAME_PATTERN = /^[a-z0-9][a-z0-9._-]{2,31}$/;
export const ROLES = new Set(["owner", "analyst"]);
export const USER_STATUSES = new Set(["active", "disabled"]);

const SCRYPT_OPTIONS = Object.freeze({
  N: 16_384,
  r: 8,
  p: 1,
  maxmem: 64 * 1024 * 1024,
});
const SCRYPT_KEY_LENGTH = 64;
const DUMMY_PASSWORD_RECORD = Object.freeze({
  algorithm: "scrypt",
  N: SCRYPT_OPTIONS.N,
  r: SCRYPT_OPTIONS.r,
  p: SCRYPT_OPTIONS.p,
  salt: Buffer.alloc(16, 17).toString("base64url"),
  hash: Buffer.alloc(SCRYPT_KEY_LENGTH, 23).toString("base64url"),
});

export class AuthError extends Error {
  constructor(code, message = code) {
    super(message);
    this.name = "AuthError";
    this.code = code;
  }
}

export function normalizeUsername(value) {
  if (typeof value !== "string") {
    throw new AuthError("invalid_username");
  }
  const normalized = value.trim().toLowerCase();
  if (!USERNAME_PATTERN.test(normalized)) {
    throw new AuthError("invalid_username");
  }
  return normalized;
}

export function validatePassword(value) {
  if (typeof value !== "string" || value.length < PASSWORD_MIN_LENGTH || value.length > PASSWORD_MAX_LENGTH) {
    throw new AuthError("invalid_password");
  }
  return value;
}

export function validateRole(value) {
  if (!ROLES.has(value)) {
    throw new AuthError("invalid_role");
  }
  return value;
}

export function validateStatus(value) {
  if (!USER_STATUSES.has(value)) {
    throw new AuthError("invalid_status");
  }
  return value;
}

function scryptAsync(password, salt, options = SCRYPT_OPTIONS) {
  return new Promise((resolve, reject) => {
    crypto.scrypt(password, salt, SCRYPT_KEY_LENGTH, options, (error, derivedKey) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(derivedKey);
    });
  });
}

export async function hashPassword(password) {
  validatePassword(password);
  const salt = crypto.randomBytes(16);
  const derivedKey = await scryptAsync(password, salt);
  return {
    algorithm: "scrypt",
    N: SCRYPT_OPTIONS.N,
    r: SCRYPT_OPTIONS.r,
    p: SCRYPT_OPTIONS.p,
    salt: salt.toString("base64url"),
    hash: derivedKey.toString("base64url"),
  };
}

function normalizedPasswordRecord(record) {
  if (
    !record ||
    record.algorithm !== "scrypt" ||
    !Number.isInteger(record.N) ||
    !Number.isInteger(record.r) ||
    !Number.isInteger(record.p) ||
    typeof record.salt !== "string" ||
    typeof record.hash !== "string"
  ) {
    return DUMMY_PASSWORD_RECORD;
  }
  if (record.N < 16_384 || record.N > 32_768 || record.r < 8 || record.r > 16 || record.p < 1 || record.p > 4) {
    return DUMMY_PASSWORD_RECORD;
  }
  return record;
}

export async function verifyPassword(password, record) {
  // Keep the KDF work constant while capping untrusted request input.
  const candidate = typeof password === "string" && password.length <= PASSWORD_MAX_LENGTH ? password : "";
  const safeRecord = normalizedPasswordRecord(record);
  let salt;
  let expected;
  try {
    salt = Buffer.from(safeRecord.salt, "base64url");
    expected = Buffer.from(safeRecord.hash, "base64url");
  } catch {
    salt = Buffer.alloc(16, 17);
    expected = Buffer.alloc(SCRYPT_KEY_LENGTH, 23);
  }
  if (salt.length < 16 || expected.length !== SCRYPT_KEY_LENGTH) {
    salt = Buffer.alloc(16, 17);
    expected = Buffer.alloc(SCRYPT_KEY_LENGTH, 23);
  }
  const derivedKey = await scryptAsync(candidate, salt, {
    N: safeRecord.N,
    r: safeRecord.r,
    p: safeRecord.p,
    maxmem: 64 * 1024 * 1024,
  });
  return expected.length === derivedKey.length && crypto.timingSafeEqual(expected, derivedKey) && safeRecord !== DUMMY_PASSWORD_RECORD;
}

export async function verifyPasswordAgainstUser(password, user) {
  // Always execute scrypt, including for a missing/disabled user. This prevents
  // login timing from revealing which administrator names exist.
  const verified = await verifyPassword(password, user?.password);
  return Boolean(user && user.status === "active" && verified);
}

export function createOpaqueToken() {
  return crypto.randomBytes(32).toString("base64url");
}

export function tokenHash(token) {
  return crypto.createHash("sha256").update(String(token)).digest("base64url");
}

export function createStateSecret() {
  return crypto.randomBytes(32).toString("base64url");
}

export function deriveCsrfToken(stateSecret, sessionToken) {
  return crypto
    .createHmac("sha256", Buffer.from(stateSecret, "base64url"))
    .update(String(sessionToken))
    .digest("base64url");
}

export function timingSafeStringEqual(left, right) {
  if (typeof left !== "string" || typeof right !== "string") {
    return false;
  }
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  return leftBuffer.length === rightBuffer.length && crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

export class LoginRateLimiter {
  constructor({ limit = 6, windowMs = 15 * 60 * 1000, now = () => Date.now() } = {}) {
    this.limit = limit;
    this.windowMs = windowMs;
    this.now = now;
    this.attempts = new Map();
    this.inFlight = new Map();
  }

  _key(kind, value) {
    return `${kind}:${String(value).slice(0, 160)}`;
  }

  _recordFor(key, now) {
    const entries = (this.attempts.get(key) ?? []).filter((time) => now - time < this.windowMs);
    if (entries.length > 0) {
      this.attempts.set(key, entries);
    } else {
      this.attempts.delete(key);
    }
    return entries;
  }

  _inFlightFor(key) {
    return this.inFlight.get(key) ?? 0;
  }

  _evaluate(ip, username, now) {
    const keys = [this._key("ip", ip), this._key("username", username)];
    let retryAfterMs = 0;
    for (const key of keys) {
      const failures = this._recordFor(key, now);
      const inFlight = this._inFlightFor(key);
      if (failures.length + inFlight < this.limit) {
        continue;
      }
      // An in-flight KDF has no meaningful completion deadline. Return a
      // small retry value rather than admitting unbounded parallel work.
      const failureRetry = failures.length >= this.limit ? failures[0] + this.windowMs - now : 0;
      retryAfterMs = Math.max(retryAfterMs, failureRetry, 1_000);
    }
    return {
      allowed: retryAfterMs <= 0,
      retryAfterSeconds: Math.max(1, Math.ceil(retryAfterMs / 1000)),
      keys,
    };
  }

  check(ip, username) {
    const now = this.now();
    const result = this._evaluate(ip, username, now);
    return { allowed: result.allowed, retryAfterSeconds: result.retryAfterSeconds };
  }

  admit(ip, username) {
    const now = this.now();
    const result = this._evaluate(ip, username, now);
    if (!result.allowed) {
      return { allowed: false, retryAfterSeconds: result.retryAfterSeconds, reservation: null };
    }
    for (const key of result.keys) {
      this.inFlight.set(key, this._inFlightFor(key) + 1);
    }
    return {
      allowed: true,
      retryAfterSeconds: 0,
      reservation: { keys: result.keys, settled: false },
    };
  }

  settle(reservation, { failure = false } = {}) {
    if (!reservation || reservation.settled || !Array.isArray(reservation.keys)) {
      return;
    }
    reservation.settled = true;
    const now = this.now();
    for (const key of reservation.keys) {
      const remaining = Math.max(0, this._inFlightFor(key) - 1);
      if (remaining > 0) {
        this.inFlight.set(key, remaining);
      } else {
        this.inFlight.delete(key);
      }
      if (failure) {
        const entries = this._recordFor(key, now);
        entries.push(now);
        this.attempts.set(key, entries);
      }
    }
  }

  recordFailure(ip, username) {
    const now = this.now();
    for (const [kind, value] of [["ip", ip], ["username", username]]) {
      const key = this._key(kind, value);
      const entries = this._recordFor(key, now);
      entries.push(now);
      this.attempts.set(key, entries);
    }
  }

  clear(ip, username) {
    this.attempts.delete(this._key("ip", ip));
    this.attempts.delete(this._key("username", username));
  }
}
