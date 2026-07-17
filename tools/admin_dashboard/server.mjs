import fs from "node:fs/promises";
import http from "node:http";
import https from "node:https";
import os from "node:os";
import path from "node:path";
import { StringDecoder } from "node:string_decoder";
import { fileURLToPath } from "node:url";
import {
  AuthError,
  LoginRateLimiter,
  normalizeUsername,
} from "./lib/auth.mjs";
import {
  HttpError,
  applySecurityHeaders,
  clientIp,
  cookieHeader,
  hasTrustedOrigin,
  isLoopbackHost,
  parseCookies,
  parsePort,
  readJsonBody,
  sendJson,
  sendText,
} from "./lib/http_utils.mjs";
import { readDashboardSnapshot, resolveSnapshotPath } from "./lib/snapshot.mjs";
import { DashboardState, SESSION_ABSOLUTE_MS, StateError } from "./lib/state_store.mjs";

const MODULE_DIRECTORY = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC_DIRECTORY = path.join(MODULE_DIRECTORY, "public");
const SESSION_COOKIE_NAME = "jungle_admin_session";

const STATIC_FILES = new Map([
  ["/", { file: "index.html", type: "text/html; charset=utf-8" }],
  ["/index.html", { file: "index.html", type: "text/html; charset=utf-8" }],
  ["/app.js", { file: "app.js", type: "application/javascript; charset=utf-8" }],
  ["/styles.css", { file: "styles.css", type: "text/css; charset=utf-8" }],
]);

function defaultStateDirectory() {
  const appData = process.env.LOCALAPPDATA || process.env.APPDATA;
  return appData
    ? path.join(appData, "JungleLaw", "AdminDashboard")
    : path.join(os.homedir(), ".jungle-law-admin-dashboard");
}

function cleanHost(value) {
  const host = String(value ?? "127.0.0.1").trim();
  if (!host || /[\s/\\]/.test(host)) {
    throw new Error("invalid dashboard host");
  }
  return host;
}

function configValue(overrides, key, environmentKey, fallback = "") {
  if (Object.hasOwn(overrides, key) && overrides[key] !== undefined) {
    return overrides[key];
  }
  return process.env[environmentKey] ?? fallback;
}

export function buildRuntimeConfig(overrides = {}) {
  const host = cleanHost(configValue(overrides, "host", "ZHANCHENG_DASHBOARD_HOST", "127.0.0.1"));
  const requestedPort = configValue(overrides, "port", "ZHANCHENG_DASHBOARD_PORT", "24568");
  // Port 0 is intentionally reserved for node:test so the OS allocates an
  // isolated ephemeral listener. Production values still require 1..65535.
  const port = overrides.port === 0 ? 0 : parsePort(requestedPort);
  const snapshotPath = resolveSnapshotPath(configValue(overrides, "snapshotPath", "ZHANCHENG_DASHBOARD_SNAPSHOT_PATH"));
  const stateDirectory = path.resolve(configValue(overrides, "stateDirectory", "ZHANCHENG_DASHBOARD_STATE_DIR", defaultStateDirectory()));
  const tlsKeyPath = String(configValue(overrides, "tlsKeyPath", "ZHANCHENG_DASHBOARD_TLS_KEY_PATH", "")).trim();
  const tlsCertPath = String(configValue(overrides, "tlsCertPath", "ZHANCHENG_DASHBOARD_TLS_CERT_PATH", "")).trim();
  const hasTls = Boolean(tlsKeyPath || tlsCertPath);
  if (hasTls && (!tlsKeyPath || !tlsCertPath)) {
    throw new Error("both ZHANCHENG_DASHBOARD_TLS_KEY_PATH and ZHANCHENG_DASHBOARD_TLS_CERT_PATH are required for TLS");
  }
  if (!isLoopbackHost(host) && !hasTls) {
    throw new Error("non-loopback dashboard binding requires TLS");
  }
  return {
    host,
    port,
    snapshotPath,
    stateDirectory,
    tls: hasTls ? { keyPath: path.resolve(tlsKeyPath), certPath: path.resolve(tlsCertPath) } : null,
    sessionCookieSecure: hasTls,
  };
}

function publicError(error) {
  if (error instanceof HttpError) {
    return { status: error.status, body: { error: error.code }, headers: error.headers };
  }
  if (error instanceof AuthError || error instanceof StateError) {
    const status = ["invalid_username", "invalid_password", "invalid_role", "invalid_status", "invalid_user_patch"].includes(error.code) ? 400
      : error.code === "user_not_found" ? 404
        : error.code === "user_exists" ? 409
          : error.code === "last_owner_protected" || error.code === "owner_initialization_closed" ? 409
            : 400;
    return { status, body: { error: error.code }, headers: {} };
  }
  return { status: 500, body: { error: "internal_error" }, headers: {} };
}

function endpointPath(requestUrl) {
  try {
    return new URL(requestUrl ?? "/", "http://dashboard.local").pathname;
  } catch {
    return "/";
  }
}

function decodedTarget(pathname, suffix) {
  try {
    return decodeURIComponent(pathname.slice(suffix.length));
  } catch {
    throw new HttpError(400, "invalid_target");
  }
}

function requireTrustedOrigin(req, config) {
  if (!hasTrustedOrigin(req, Boolean(config.tls))) {
    throw new HttpError(403, "origin_rejected");
  }
}

async function serveStatic(res, pathname, config) {
  const descriptor = STATIC_FILES.get(pathname);
  if (!descriptor) {
    throw new HttpError(404, "not_found");
  }
  const content = await fs.readFile(path.join(PUBLIC_DIRECTORY, descriptor.file), "utf8");
  applySecurityHeaders(res, { tlsEnabled: Boolean(config.tls), api: false });
  sendText(res, 200, descriptor.type, content);
}

export async function createDashboardServer(overrides = {}) {
  const config = buildRuntimeConfig(overrides);
  const state = overrides.state ?? await DashboardState.open(config.stateDirectory);
  const limiter = overrides.limiter ?? new LoginRateLimiter();
  const tlsOptions = config.tls ? {
    key: await fs.readFile(config.tls.keyPath),
    cert: await fs.readFile(config.tls.certPath),
  } : null;

  async function requireSession(req) {
    const cookies = parseCookies(req.headers.cookie);
    const sessionToken = cookies[SESSION_COOKIE_NAME] ?? "";
    const session = await state.sessionForToken(sessionToken);
    if (!session) {
      throw new HttpError(401, "authentication_required");
    }
    if (session.user.role !== "owner" && session.user.role !== "analyst") {
      throw new HttpError(403, "role_rejected");
    }
    return { ...session, sessionToken };
  }

  function requireOwner(session) {
    if (session.user.role !== "owner") {
      throw new HttpError(403, "owner_required");
    }
  }

  function requireCsrf(req, session) {
    requireTrustedOrigin(req, config);
    if (!state.verifyCsrf(session.sessionToken, String(req.headers["x-csrf-token"] ?? ""))) {
      throw new HttpError(403, "csrf_rejected");
    }
  }

  async function appendAuditSafe(entry) {
    try {
      await state.appendAudit(entry);
    } catch {
      // Audit storage failures must not reveal internal paths or credentials.
      // The mutation itself has already been durably written by DashboardState.
    }
  }

  async function handleApi(req, res, pathname) {
    const method = req.method ?? "GET";
    const ip = clientIp(req);
    applySecurityHeaders(res, { tlsEnabled: Boolean(config.tls), api: true });

    if (method === "GET" && pathname === "/api/health") {
      const dashboard = await readDashboardSnapshot(config.snapshotPath);
      sendJson(res, 200, { ok: true, availability: dashboard.availability });
      return;
    }

    if (method === "POST" && pathname === "/api/auth/login") {
      requireTrustedOrigin(req, config);
      const body = await readJsonBody(req);
      const usernameKey = typeof body.username === "string" ? body.username.trim().toLowerCase().slice(0, 64) : "";
      const admission = limiter.admit(ip, usernameKey);
      if (!admission.allowed) {
        await appendAuditSafe({ event: "login_rate_limited", target: usernameKey, ip });
        throw new HttpError(429, "login_rate_limited", "login_rate_limited", { "Retry-After": String(admission.retryAfterSeconds) });
      }
      let result;
      try {
        result = await state.authenticate(body.username, body.password);
      } catch (error) {
        limiter.settle(admission.reservation);
        throw error;
      }
      if (!result.ok) {
        limiter.settle(admission.reservation, { failure: true });
        await appendAuditSafe({ event: "login_failed", target: usernameKey, ip });
        throw new HttpError(401, "invalid_credentials");
      }
      limiter.settle(admission.reservation);
      await appendAuditSafe({ event: "login_success", actor: result.user.username, ip });
      const maxAgeSeconds = Math.floor(SESSION_ABSOLUTE_MS / 1000);
      sendJson(res, 200, {
        user: result.user,
        csrf_token: result.csrf_token,
        expires_at: result.expires_at,
      }, {
        "Set-Cookie": cookieHeader(SESSION_COOKIE_NAME, result.session_token, {
          maxAgeSeconds,
          secure: config.sessionCookieSecure,
        }),
      });
      return;
    }

    if (method === "GET" && pathname === "/api/session") {
      const session = await requireSession(req);
      sendJson(res, 200, {
        user: session.user,
        csrf_token: session.csrf_token,
        expires_at: session.expires_at,
      });
      return;
    }

    if (method === "POST" && pathname === "/api/auth/logout") {
      const session = await requireSession(req);
      requireCsrf(req, session);
      await state.logout(session.sessionToken);
      await appendAuditSafe({ event: "logout", actor: session.user.username, ip });
      sendJson(res, 200, { ok: true }, {
        "Set-Cookie": cookieHeader(SESSION_COOKIE_NAME, "", { secure: config.sessionCookieSecure, clear: true }),
      });
      return;
    }

    if (method === "GET" && pathname === "/api/dashboard") {
      await requireSession(req);
      const dashboard = await readDashboardSnapshot(config.snapshotPath);
      sendJson(res, 200, dashboard);
      return;
    }

    if (method === "GET" && pathname === "/api/admins") {
      const session = await requireSession(req);
      requireOwner(session);
      sendJson(res, 200, { users: await state.listUsers() });
      return;
    }

    if (method === "POST" && pathname === "/api/admins") {
      const session = await requireSession(req);
      requireOwner(session);
      requireCsrf(req, session);
      const body = await readJsonBody(req);
      const user = await state.createUser({
        username: body.username,
        password: body.password,
        role: body.role,
      });
      await appendAuditSafe({ event: "admin_created", actor: session.user.username, target: user.username, ip, detail: user.role });
      sendJson(res, 201, { user });
      return;
    }

    if (method === "PATCH" && pathname.startsWith("/api/admins/")) {
      const session = await requireSession(req);
      requireOwner(session);
      requireCsrf(req, session);
      const target = decodedTarget(pathname, "/api/admins/");
      if (!target || target.includes("/")) {
        throw new HttpError(404, "not_found");
      }
      const body = await readJsonBody(req);
      const patch = {};
      if (Object.hasOwn(body, "role")) patch.role = body.role;
      if (Object.hasOwn(body, "status")) patch.status = body.status;
      if (Object.hasOwn(body, "password")) patch.password = body.password;
      const updated = await state.updateUser(target, patch);
      await appendAuditSafe({ event: "admin_updated", actor: session.user.username, target: updated.user.username, ip, detail: `${updated.user.role}/${updated.user.status}` });
      sendJson(res, 200, updated);
      return;
    }

    if (method === "POST" && pathname.startsWith("/api/admins/") && pathname.endsWith("/revoke-sessions")) {
      const session = await requireSession(req);
      requireOwner(session);
      requireCsrf(req, session);
      const target = decodedTarget(pathname, "/api/admins/").replace(/\/revoke-sessions$/, "");
      if (!target || target.includes("/")) {
        throw new HttpError(404, "not_found");
      }
      const revoked = await state.revokeSessionsFor(target);
      await appendAuditSafe({ event: "sessions_revoked", actor: session.user.username, target, ip, detail: String(revoked) });
      sendJson(res, 200, { revoked_sessions: revoked });
      return;
    }

    if (method === "GET" && pathname === "/api/audit") {
      const session = await requireSession(req);
      requireOwner(session);
      const parsed = new URL(req.url ?? "/", "http://dashboard.local");
      sendJson(res, 200, { entries: await state.readAudit(parsed.searchParams.get("limit")) });
      return;
    }

    throw new HttpError(404, "not_found");
  }

  async function requestHandler(req, res) {
    try {
      const pathname = endpointPath(req.url);
      if (pathname.startsWith("/api/")) {
        await handleApi(req, res, pathname);
        return;
      }
      if ((req.method ?? "GET") !== "GET") {
        applySecurityHeaders(res, { tlsEnabled: Boolean(config.tls), api: false });
        throw new HttpError(405, "method_not_allowed", "method_not_allowed", { Allow: "GET" });
      }
      await serveStatic(res, pathname, config);
    } catch (error) {
      const response = publicError(error);
      if (!res.headersSent) {
        applySecurityHeaders(res, { tlsEnabled: Boolean(config.tls), api: endpointPath(req.url).startsWith("/api/") });
        sendJson(res, response.status, response.body, response.headers);
      } else if (!res.writableEnded) {
        res.end();
      }
    }
  }

  const server = tlsOptions
    ? https.createServer(tlsOptions, (req, res) => void requestHandler(req, res))
    : http.createServer((req, res) => void requestHandler(req, res));

  return {
    config,
    state,
    server,
    async listen() {
      await new Promise((resolve, reject) => {
        const onError = (error) => {
          server.off("listening", onListening);
          reject(error);
        };
        const onListening = () => {
          server.off("error", onError);
          resolve();
        };
        server.once("error", onError);
        server.once("listening", onListening);
        server.listen(config.port, config.host);
      });
      return server.address();
    },
    async close() {
      if (!server.listening) {
        return;
      }
      await new Promise((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())));
    },
  };
}

function parseCommandLine(argumentsList) {
  const options = {};
  const positionals = [];
  for (let index = 0; index < argumentsList.length; index += 1) {
    const value = argumentsList[index];
    if (!value.startsWith("--")) {
      positionals.push(value);
      continue;
    }
    const [name, inlineValue] = value.slice(2).split("=", 2);
    if (!name) {
      throw new Error("invalid option");
    }
    if (inlineValue !== undefined) {
      options[name] = inlineValue;
      continue;
    }
    if (["state-dir", "host", "port", "tls-key", "tls-cert", "username"].includes(name)) {
      index += 1;
      if (index >= argumentsList.length) {
        throw new Error(`missing value for --${name}`);
      }
      options[name] = argumentsList[index];
    } else {
      options[name] = true;
    }
  }
  return { command: positionals[0] ?? "serve", options };
}

async function promptLine(prompt) {
  if (!process.stdin.isTTY) {
    throw new Error("owner initialization requires an interactive local terminal");
  }
  process.stdout.write(prompt);
  return new Promise((resolve, reject) => {
    let value = "";
    const onData = (chunk) => {
      const text = chunk.toString("utf8");
      for (const character of text) {
        if (character === "\u0003") {
          cleanup();
          reject(new Error("cancelled"));
          return;
        }
        if (character === "\r" || character === "\n") {
          cleanup();
          process.stdout.write("\n");
          resolve(value);
          return;
        }
        value += character;
      }
    };
    const cleanup = () => {
      process.stdin.off("data", onData);
      process.stdin.pause();
    };
    process.stdin.resume();
    process.stdin.on("data", onData);
  });
}

async function promptHidden(prompt) {
  if (!process.stdin.isTTY || typeof process.stdin.setRawMode !== "function") {
    throw new Error("owner initialization requires an interactive local terminal");
  }
  process.stdout.write(prompt);
  const wasRaw = process.stdin.isRaw;
  process.stdin.setRawMode(true);
  process.stdin.resume();
  return new Promise((resolve, reject) => {
    const decoder = new StringDecoder("utf8");
    const characters = [];
    const cleanup = () => {
      process.stdin.off("data", onData);
      process.stdin.setRawMode(Boolean(wasRaw));
      process.stdin.pause();
    };
    const onData = (chunk) => {
      for (const character of decoder.write(chunk)) {
        if (character === "\u0003") {
          cleanup();
          process.stdout.write("\n");
          reject(new Error("cancelled"));
          return;
        }
        if (character === "\r" || character === "\n") {
          cleanup();
          process.stdout.write("\n");
          resolve(characters.join(""));
          return;
        }
        if (character === "\b" || character === "\u007f") {
          characters.pop();
          continue;
        }
        characters.push(character);
      }
    };
    process.stdin.on("data", onData);
  });
}

function cliOverrides(options) {
  return {
    host: options.host,
    port: options.port,
    stateDirectory: options["state-dir"],
    tlsKeyPath: options["tls-key"],
    tlsCertPath: options["tls-cert"],
  };
}

function printUsage() {
  console.log("Usage:");
  console.log("  node server.mjs init-owner [--state-dir <directory>] [--username <name>]");
  console.log("  ZHANCHENG_DASHBOARD_SNAPSHOT_PATH=<.../dashboard_snapshot.json> node server.mjs [--host 127.0.0.1] [--port 24568]");
}

export async function runCli(argumentsList = process.argv.slice(2)) {
  const { command, options } = parseCommandLine(argumentsList);
  if (command === "--help" || command === "help" || options.help) {
    printUsage();
    return 0;
  }
  if (command === "init-owner") {
    const stateDirectory = path.resolve(options["state-dir"] ?? process.env.ZHANCHENG_DASHBOARD_STATE_DIR ?? defaultStateDirectory());
    const state = await DashboardState.open(stateDirectory);
    const username = options.username ?? await promptLine("Owner username: ");
    const password = await promptHidden("Owner password (min 12 chars): ");
    const confirmation = await promptHidden("Confirm owner password: ");
    if (password !== confirmation) {
      throw new Error("password confirmation does not match");
    }
    const user = await state.initializeOwner(username, password);
    await state.appendAudit({ event: "owner_initialized", actor: user.username, detail: "local_cli" });
    console.log(`Owner '${user.username}' initialized in ${stateDirectory}.`);
    return 0;
  }
  if (command !== "serve") {
    printUsage();
    throw new Error(`unknown command: ${command}`);
  }
  const app = await createDashboardServer(cliOverrides(options));
  const address = await app.listen();
  const protocol = app.config.tls ? "https" : "http";
  const host = typeof address === "object" && address ? address.address : app.config.host;
  const port = typeof address === "object" && address ? address.port : app.config.port;
  console.log(`Jungle Law admin dashboard listening on ${protocol}://${host}:${port}`);
  const shutdown = async () => {
    await app.close();
    process.exit(0);
  };
  process.once("SIGINT", shutdown);
  process.once("SIGTERM", shutdown);
  return new Promise(() => {});
}

const isEntrypoint = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isEntrypoint) {
  runCli().catch((error) => {
    console.error(`Dashboard startup failed: ${error.message}`);
    process.exitCode = 1;
  });
}
