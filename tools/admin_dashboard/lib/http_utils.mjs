export class HttpError extends Error {
  constructor(status, code, message = code, headers = {}) {
    super(message);
    this.name = "HttpError";
    this.status = status;
    this.code = code;
    this.headers = headers;
  }
}

export function isLoopbackHost(host) {
  const normalized = String(host ?? "").trim().toLowerCase();
  return normalized === "localhost" || normalized === "::1" || normalized === "[::1]" || /^127(?:\.\d{1,3}){3}$/.test(normalized);
}

export function parsePort(value, fallback = 24568) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isInteger(parsed) && parsed >= 1 && parsed <= 65535 ? parsed : fallback;
}

export function parseCookies(header) {
  const cookies = {};
  for (const part of String(header ?? "").split(";")) {
    const separator = part.indexOf("=");
    if (separator <= 0) {
      continue;
    }
    const name = part.slice(0, separator).trim();
    const value = part.slice(separator + 1).trim();
    if (!name || Object.hasOwn(cookies, name)) {
      continue;
    }
    try {
      cookies[name] = decodeURIComponent(value);
    } catch {
      // Ignore malformed cookie values.
    }
  }
  return cookies;
}

export function cookieHeader(name, value, { maxAgeSeconds = 0, secure = false, clear = false } = {}) {
  const parts = [
    `${name}=${encodeURIComponent(value ?? "")}`,
    "Path=/",
    "HttpOnly",
    "SameSite=Strict",
  ];
  if (secure) {
    parts.push("Secure");
  }
  if (clear) {
    parts.push("Max-Age=0", "Expires=Thu, 01 Jan 1970 00:00:00 GMT");
  } else if (maxAgeSeconds > 0) {
    parts.push(`Max-Age=${Math.floor(maxAgeSeconds)}`);
  }
  return parts.join("; ");
}

export function clientIp(req) {
  // Intentionally do not trust X-Forwarded-For. The service is direct TLS or
  // loopback-only; a proxy must pass traffic through a separate trusted setup.
  return String(req.socket?.remoteAddress ?? "unknown").slice(0, 80);
}

export function requestOrigin(req, tlsEnabled) {
  const host = String(req.headers.host ?? "").trim();
  if (!host || /[\s/\\]/.test(host)) {
    return "";
  }
  return `${tlsEnabled ? "https" : "http"}://${host}`;
}

export function hasTrustedOrigin(req, tlsEnabled) {
  const origin = req.headers.origin;
  if (typeof origin !== "string" || !origin) {
    return false;
  }
  return origin === requestOrigin(req, tlsEnabled);
}

export async function readJsonBody(req, maxBytes = 32 * 1024) {
  const contentType = String(req.headers["content-type"] ?? "").toLowerCase();
  if (!contentType.startsWith("application/json")) {
    throw new HttpError(415, "json_required");
  }
  const chunks = [];
  let total = 0;
  for await (const chunk of req) {
    total += chunk.length;
    if (total > maxBytes) {
      throw new HttpError(413, "body_too_large");
    }
    chunks.push(chunk);
  }
  if (total === 0) {
    throw new HttpError(400, "invalid_json");
  }
  try {
    const parsed = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("body must be object");
    }
    return parsed;
  } catch {
    throw new HttpError(400, "invalid_json");
  }
}

export function applySecurityHeaders(res, { tlsEnabled = false, api = false } = {}) {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("X-Frame-Options", "DENY");
  res.setHeader("Referrer-Policy", "no-referrer");
  res.setHeader("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=(), usb=()");
  res.setHeader("Cross-Origin-Opener-Policy", "same-origin");
  res.setHeader("Cross-Origin-Resource-Policy", "same-origin");
  res.setHeader(
    "Content-Security-Policy",
    "default-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; connect-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self'; font-src 'self'",
  );
  if (api) {
    res.setHeader("Cache-Control", "no-store, max-age=0");
  } else {
    res.setHeader("Cache-Control", "no-cache");
  }
  if (tlsEnabled) {
    res.setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
  }
}

export function sendJson(res, status, payload, headers = {}) {
  res.statusCode = status;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  for (const [name, value] of Object.entries(headers)) {
    res.setHeader(name, value);
  }
  res.end(`${JSON.stringify(payload)}\n`);
}

export function sendText(res, status, contentType, text, headers = {}) {
  res.statusCode = status;
  res.setHeader("Content-Type", contentType);
  for (const [name, value] of Object.entries(headers)) {
    res.setHeader(name, value);
  }
  res.end(text);
}
