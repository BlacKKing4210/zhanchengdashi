import fs from "node:fs/promises";
import path from "node:path";
import {
  AuthError,
  createOpaqueToken,
  createStateSecret,
  deriveCsrfToken,
  hashPassword,
  normalizeUsername,
  timingSafeStringEqual,
  tokenHash,
  validatePassword,
  validateRole,
  validateStatus,
  verifyPasswordAgainstUser,
} from "./auth.mjs";

export const SESSION_IDLE_MS = 30 * 60 * 1000;
export const SESSION_ABSOLUTE_MS = 8 * 60 * 60 * 1000;

export class StateError extends Error {
  constructor(code, message = code) {
    super(message);
    this.name = "StateError";
    this.code = code;
  }
}

class AsyncMutex {
  constructor() {
    this.tail = Promise.resolve();
  }

  async run(operation) {
    const previous = this.tail;
    let release;
    this.tail = new Promise((resolve) => {
      release = resolve;
    });
    await previous;
    try {
      return await operation();
    } finally {
      release();
    }
  }
}

function emptyState() {
  return {
    version: 1,
    csrf_secret: createStateSecret(),
    users: {},
    sessions: {},
  };
}

function nowMs(value = Date.now()) {
  return Number.isFinite(value) ? Math.floor(value) : Date.now();
}

function publicUser(user) {
  return {
    username: user.username,
    role: user.role,
    status: user.status,
    created_at: user.created_at,
    updated_at: user.updated_at,
  };
}

function auditText(value, maxLength = 120) {
  return String(value ?? "")
    .replace(/[\u0000-\u001f\u007f]/g, " ")
    .trim()
    .slice(0, maxLength);
}

function persistentStateIsValid(candidate) {
  return (
    candidate &&
    candidate.version === 1 &&
    typeof candidate.csrf_secret === "string" &&
    candidate.csrf_secret.length >= 32 &&
    candidate.users &&
    typeof candidate.users === "object" &&
    !Array.isArray(candidate.users) &&
    candidate.sessions &&
    typeof candidate.sessions === "object" &&
    !Array.isArray(candidate.sessions)
  );
}

async function writeJsonAtomic(targetPath, value) {
  const tempPath = `${targetPath}.${process.pid}.${Date.now()}.tmp`;
  const payload = `${JSON.stringify(value, null, 2)}\n`;
  await fs.writeFile(tempPath, payload, { encoding: "utf8", mode: 0o600 });
  try {
    await fs.chmod(tempPath, 0o600);
  } catch {
    // Windows ignores POSIX modes; the write remains available to the current user.
  }
  await fs.rename(tempPath, targetPath);
  try {
    await fs.chmod(targetPath, 0o600);
  } catch {
    // Best-effort only on platforms without POSIX permissions.
  }
}

export class DashboardState {
  static async open(stateDirectory) {
    if (!stateDirectory) {
      throw new StateError("state_directory_required");
    }
    const store = new DashboardState(path.resolve(stateDirectory));
    await store._load();
    return store;
  }

  constructor(stateDirectory) {
    this.stateDirectory = stateDirectory;
    this.statePath = path.join(stateDirectory, "dashboard_admin_state.json");
    this.auditPath = path.join(stateDirectory, "dashboard_admin_audit.jsonl");
    this.state = emptyState();
    this.mutex = new AsyncMutex();
  }

  async _load() {
    await fs.mkdir(this.stateDirectory, { recursive: true, mode: 0o700 });
    try {
      const raw = await fs.readFile(this.statePath, "utf8");
      const parsed = JSON.parse(raw);
      if (!persistentStateIsValid(parsed)) {
        throw new StateError("state_corrupt");
      }
      this.state = parsed;
    } catch (error) {
      if (error && error.code === "ENOENT") {
        this.state = emptyState();
        await this._save();
        return;
      }
      if (error instanceof StateError) {
        throw error;
      }
      if (error instanceof SyntaxError) {
        throw new StateError("state_corrupt");
      }
      throw error;
    }
  }

  async _save() {
    await writeJsonAtomic(this.statePath, this.state);
  }

  async _mutate(operation) {
    return this.mutex.run(async () => {
      const result = await operation();
      await this._save();
      return result;
    });
  }

  _user(username) {
    return this.state.users[username] ?? null;
  }

  _activeOwnerCount({ replacingUsername = "", replacement = null } = {}) {
    return Object.entries(this.state.users).reduce((count, [username, user]) => {
      const candidate = username === replacingUsername && replacement ? replacement : user;
      return count + (candidate.role === "owner" && candidate.status === "active" ? 1 : 0);
    }, 0);
  }

  hasAnyUsers() {
    return Object.keys(this.state.users).length > 0;
  }

  async initializeOwner(usernameInput, password, metadata = {}) {
    const username = normalizeUsername(usernameInput);
    validatePassword(password);
    return this._mutate(async () => {
      if (this.hasAnyUsers()) {
        throw new StateError("owner_initialization_closed");
      }
      const timestamp = nowMs(metadata.now);
      this.state.users[username] = {
        username,
        role: "owner",
        status: "active",
        password: await hashPassword(password),
        created_at: timestamp,
        updated_at: timestamp,
      };
      return publicUser(this.state.users[username]);
    });
  }

  async authenticate(usernameInput, password, timestamp = Date.now()) {
    const loginKey = typeof usernameInput === "string" ? usernameInput.trim().toLowerCase().slice(0, 64) : "";
    let username = "";
    try {
      username = normalizeUsername(usernameInput);
    } catch (error) {
      if (!(error instanceof AuthError)) {
        throw error;
      }
    }
    const verifiedUser = username ? this._user(username) : null;
    const valid = await verifyPasswordAgainstUser(password, verifiedUser);
    if (!valid || !verifiedUser) {
      return { ok: false, login_key: loginKey };
    }
    return this._mutate(async () => {
      // Recheck after the KDF so a concurrent password reset, role change, or
      // disable operation cannot issue a new session from a stale user record.
      const user = this._user(username);
      if (!user || user.status !== "active" || user.password?.hash !== verifiedUser.password?.hash) {
        return { ok: false, login_key: loginKey };
      }
      const now = nowMs(timestamp);
      const sessionToken = createOpaqueToken();
      const hash = tokenHash(sessionToken);
      const expiresAt = Math.min(now + SESSION_IDLE_MS, now + SESSION_ABSOLUTE_MS);
      this.state.sessions[hash] = {
        username,
        created_at: now,
        last_seen_at: now,
        expires_at: expiresAt,
        absolute_expires_at: now + SESSION_ABSOLUTE_MS,
      };
      return {
        ok: true,
        session_token: sessionToken,
        csrf_token: deriveCsrfToken(this.state.csrf_secret, sessionToken),
        expires_at: expiresAt,
        user: publicUser(user),
      };
    });
  }

  async sessionForToken(sessionToken, timestamp = Date.now()) {
    if (typeof sessionToken !== "string" || sessionToken.length < 32 || sessionToken.length > 128) {
      return null;
    }
    const sessionHash = tokenHash(sessionToken);
    // Unknown bearer tokens are common background noise. Do not turn them
    // into disk writes merely by looking them up.
    if (!this.state.sessions[sessionHash]) {
      return null;
    }
    return this._mutate(async () => {
      const session = this.state.sessions[sessionHash];
      const now = nowMs(timestamp);
      if (!session) {
        return null;
      }
      const user = this._user(session.username);
      if (
        !user ||
        user.status !== "active" ||
        !Number.isFinite(session.expires_at) ||
        !Number.isFinite(session.absolute_expires_at) ||
        now >= session.expires_at ||
        now >= session.absolute_expires_at
      ) {
        delete this.state.sessions[sessionHash];
        return null;
      }
      session.last_seen_at = now;
      session.expires_at = Math.min(now + SESSION_IDLE_MS, session.absolute_expires_at);
      this.state.sessions[sessionHash] = session;
      return {
        session_hash: sessionHash,
        expires_at: session.expires_at,
        user: publicUser(user),
        csrf_token: deriveCsrfToken(this.state.csrf_secret, sessionToken),
      };
    });
  }

  verifyCsrf(sessionToken, suppliedToken) {
    if (typeof sessionToken !== "string" || typeof suppliedToken !== "string") {
      return false;
    }
    const expected = deriveCsrfToken(this.state.csrf_secret, sessionToken);
    return timingSafeStringEqual(expected, suppliedToken);
  }

  async logout(sessionToken) {
    if (typeof sessionToken !== "string") {
      return false;
    }
    const sessionHash = tokenHash(sessionToken);
    return this._mutate(async () => {
      const existed = Boolean(this.state.sessions[sessionHash]);
      delete this.state.sessions[sessionHash];
      return existed;
    });
  }

  async listUsers() {
    return Object.values(this.state.users)
      .map(publicUser)
      .sort((left, right) => left.username.localeCompare(right.username));
  }

  async createUser({ username: usernameInput, password, role }, timestamp = Date.now()) {
    const username = normalizeUsername(usernameInput);
    validatePassword(password);
    validateRole(role);
    return this._mutate(async () => {
      if (this._user(username)) {
        throw new StateError("user_exists");
      }
      const now = nowMs(timestamp);
      this.state.users[username] = {
        username,
        role,
        status: "active",
        password: await hashPassword(password),
        created_at: now,
        updated_at: now,
      };
      return publicUser(this.state.users[username]);
    });
  }

  async updateUser(targetInput, patch, timestamp = Date.now()) {
    const target = normalizeUsername(targetInput);
    if (!patch || typeof patch !== "object" || Array.isArray(patch)) {
      throw new StateError("invalid_user_patch");
    }
    if (!Object.hasOwn(patch, "role") && !Object.hasOwn(patch, "status") && !Object.hasOwn(patch, "password")) {
      throw new StateError("invalid_user_patch");
    }
    return this._mutate(async () => {
      const current = this._user(target);
      if (!current) {
        throw new StateError("user_not_found");
      }
      const replacement = { ...current };
      let revokeSessions = false;
      if (Object.hasOwn(patch, "role")) {
        replacement.role = validateRole(patch.role);
        revokeSessions = true;
      }
      if (Object.hasOwn(patch, "status")) {
        replacement.status = validateStatus(patch.status);
        revokeSessions = true;
      }
      if (Object.hasOwn(patch, "password")) {
        validatePassword(patch.password);
        replacement.password = await hashPassword(patch.password);
        revokeSessions = true;
      }
      if (this._activeOwnerCount({ replacingUsername: target, replacement }) < 1) {
        throw new StateError("last_owner_protected");
      }
      replacement.updated_at = nowMs(timestamp);
      this.state.users[target] = replacement;
      const revoked = revokeSessions ? this._revokeSessionsUnsafe(target) : 0;
      return { user: publicUser(replacement), revoked_sessions: revoked };
    });
  }

  _revokeSessionsUnsafe(username) {
    let revoked = 0;
    for (const [hash, session] of Object.entries(this.state.sessions)) {
      if (session.username === username) {
        delete this.state.sessions[hash];
        revoked += 1;
      }
    }
    return revoked;
  }

  async revokeSessionsFor(targetInput) {
    const target = normalizeUsername(targetInput);
    return this._mutate(async () => {
      if (!this._user(target)) {
        throw new StateError("user_not_found");
      }
      return this._revokeSessionsUnsafe(target);
    });
  }

  async appendAudit({ event, actor = "", target = "", ip = "", detail = "", timestamp = Date.now() }) {
    const entry = {
      at: nowMs(timestamp),
      event: auditText(event, 64),
      actor: auditText(actor, 40),
      target: auditText(target, 40),
      ip: auditText(ip, 80),
      detail: auditText(detail, 240),
    };
    if (!entry.event) {
      throw new StateError("invalid_audit_event");
    }
    await fs.appendFile(this.auditPath, `${JSON.stringify(entry)}\n`, { encoding: "utf8", mode: 0o600 });
    try {
      await fs.chmod(this.auditPath, 0o600);
    } catch {
      // Best-effort on Windows.
    }
    return entry;
  }

  async readAudit(limit = 100) {
    const safeLimit = Math.max(1, Math.min(200, Number.parseInt(limit, 10) || 100));
    try {
      const raw = await fs.readFile(this.auditPath, "utf8");
      return raw
        .split("\n")
        .filter(Boolean)
        .slice(-safeLimit)
        .flatMap((line) => {
          try {
            const entry = JSON.parse(line);
            if (!entry || typeof entry !== "object" || typeof entry.event !== "string") {
              return [];
            }
            return [{
              at: nowMs(entry.at),
              event: auditText(entry.event, 64),
              actor: auditText(entry.actor, 40),
              target: auditText(entry.target, 40),
              ip: auditText(entry.ip, 80),
              detail: auditText(entry.detail, 240),
            }];
          } catch {
            return [];
          }
        })
        .reverse();
    } catch (error) {
      if (error && error.code === "ENOENT") {
        return [];
      }
      throw error;
    }
  }
}
