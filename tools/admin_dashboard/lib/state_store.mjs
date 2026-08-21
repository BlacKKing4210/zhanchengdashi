import crypto from "node:crypto";
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
    audit_outbox: {},
    audit_integrity_degraded: false,
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
    !Array.isArray(candidate.sessions) &&
    (candidate.audit_outbox === undefined || (
      candidate.audit_outbox &&
      typeof candidate.audit_outbox === "object" &&
      !Array.isArray(candidate.audit_outbox)
    )) &&
    (candidate.audit_integrity_degraded === undefined || typeof candidate.audit_integrity_degraded === "boolean")
  );
}

async function writeJsonAtomic(targetPath, value) {
  const tempPath = `${targetPath}.${process.pid}.${crypto.randomBytes(8).toString("hex")}.tmp`;
  const payload = `${JSON.stringify(value, null, 2)}\n`;
  const handle = await fs.open(tempPath, "wx", 0o600);
  try {
    try {
      await handle.writeFile(payload, "utf8");
      await handle.sync();
    } finally {
      await handle.close();
    }
    await fs.rename(tempPath, targetPath);
    try {
      await fs.chmod(targetPath, 0o600);
    } catch {
      // Best-effort only on platforms without POSIX permissions.
    }
    try {
      const directoryHandle = await fs.open(path.dirname(targetPath), "r");
      try {
        await directoryHandle.sync();
      } finally {
        await directoryHandle.close();
      }
    } catch {
      // Best effort on platforms that cannot fsync directories.
    }
  } finally {
    await fs.unlink(tempPath).catch(() => {});
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
    this.auditFlushError = false;
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
      if (!this.state.audit_outbox) {
        this.state.audit_outbox = {};
      }
      if (typeof this.state.audit_integrity_degraded !== "boolean") this.state.audit_integrity_degraded = false;
      await this._save();
      try {
        await this._flushAuditOutboxUnsafe();
      } catch {
        this.auditFlushError = true;
      }
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
      const previousState = structuredClone(this.state);
      try {
        const result = await operation();
        await this._save();
        return result;
      } catch (error) {
        this.state = previousState;
        throw error;
      }
    });
  }

  _auditEntry({ id = "", event, actor = "", target = "", ip = "", detail = "", timestamp = Date.now() }) {
    const entry = {
      id: auditText(id, 80) || crypto.randomUUID(),
      at: nowMs(timestamp),
      event: auditText(event, 64),
      actor: auditText(actor, 40),
      target: auditText(target, 40),
      ip: auditText(ip, 80),
      detail: auditText(detail, 240),
    };
    if (!entry.event) throw new StateError("invalid_audit_event");
    return entry;
  }

  _queueAuditUnsafe(value) {
    const entry = this._auditEntry(value);
    this.state.audit_outbox[entry.id] = entry;
    return entry;
  }

  async _inspectAuditFile() {
    try {
      const buffer = await fs.readFile(this.auditPath);
      const raw = buffer.toString("utf8");
      const needsSeparator = buffer.length > 0 && buffer[buffer.length - 1] !== 0x0a;
      const lines = raw.split("\n");
      const tail = needsSeparator ? lines.pop() ?? "" : "";
      const idCounts = new Map();
      let invalidLines = 0;
      const inspectLine = (line) => {
        if (!line) return;
        try {
          const entry = JSON.parse(line);
          if (typeof entry?.id === "string" && entry.id) {
            idCounts.set(entry.id, (idCounts.get(entry.id) ?? 0) + 1);
          } else {
            invalidLines += 1;
          }
        } catch {
          invalidLines += 1;
        }
      };
      for (const line of lines) inspectLine(line);
      let invalidTail = false;
      if (needsSeparator && tail) {
        const before = invalidLines;
        inspectLine(tail);
        invalidTail = invalidLines > before;
      }
      return { idCounts, invalidLines, invalidTail, needsSeparator };
    } catch (error) {
      if (error && error.code === "ENOENT") {
        return { idCounts: new Map(), invalidLines: 0, invalidTail: false, needsSeparator: false };
      }
      throw error;
    }
  }

  async _flushAuditOutboxUnsafe() {
    const entries = Object.values(this.state.audit_outbox ?? {})
      .filter((entry) => entry && typeof entry === "object" && typeof entry.id === "string" && entry.id)
      .sort((left, right) => left.at - right.at || left.id.localeCompare(right.id));
    let inspection = await this._inspectAuditFile();
    if (inspection.invalidLines > 0 || inspection.invalidTail
      || [...inspection.idCounts.values()].some((count) => count > 1)) {
      this.state.audit_integrity_degraded = true;
    }
    const uncommitted = entries.filter((entry) => !inspection.idCounts.has(entry.id));
    if (inspection.needsSeparator || uncommitted.length > 0) {
      const auditHandle = await fs.open(this.auditPath, "a", 0o600);
      try {
        if (inspection.needsSeparator) await auditHandle.writeFile("\n", "utf8");
        for (const entry of uncommitted) {
          await auditHandle.writeFile(`${JSON.stringify(entry)}\n`, "utf8");
        }
        await auditHandle.sync();
      } finally {
        await auditHandle.close();
      }
      try {
        await fs.chmod(this.auditPath, 0o600);
      } catch {
        // Best-effort on Windows.
      }
    }
    inspection = await this._inspectAuditFile();
    if (inspection.invalidLines > 0 || inspection.invalidTail
      || [...inspection.idCounts.values()].some((count) => count > 1)) {
      this.state.audit_integrity_degraded = true;
    }
    if (entries.some((entry) => (inspection.idCounts.get(entry.id) ?? 0) < 1)) {
      throw new StateError("audit_readback_failed");
    }
    for (const entry of entries) delete this.state.audit_outbox[entry.id];
    await this._save();
    this.auditFlushError = false;
    return { flushed: uncommitted.length, pending: 0 };
  }

  async flushAuditOutbox() {
    return this.mutex.run(async () => {
      try {
        return await this._flushAuditOutboxUnsafe();
      } catch (error) {
        this.auditFlushError = true;
        throw error;
      }
    });
  }

  auditStatus() {
    const pending = Object.keys(this.state.audit_outbox ?? {}).length;
    return {
      pending,
      integrity_degraded: Boolean(this.state.audit_integrity_degraded),
      degraded: this.auditFlushError || pending > 0 || Boolean(this.state.audit_integrity_degraded),
    };
  }

  async _mutateWithAudit(operation, auditForResult) {
    return this.mutex.run(async () => {
      const previousState = structuredClone(this.state);
      let result;
      let auditEntry;
      try {
        result = await operation();
        auditEntry = this._queueAuditUnsafe(auditForResult(result));
        await this._save();
      } catch (error) {
        this.state = previousState;
        throw error;
      }
      let auditPending = false;
      try {
        await this._flushAuditOutboxUnsafe();
      } catch {
        this.auditFlushError = true;
        auditPending = true;
      }
      return { result, audit_id: auditEntry.id, audit_pending: auditPending };
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
    const initialized = await this.initializeOwnerAudited(usernameInput, password, metadata);
    return initialized.user;
  }

  async initializeOwnerAudited(usernameInput, password, metadata = {}) {
    const username = normalizeUsername(usernameInput);
    validatePassword(password);
    const timestamp = nowMs(metadata.now);
    const outcome = await this._mutateWithAudit(async () => {
      if (this.hasAnyUsers()) {
        throw new StateError("owner_initialization_closed");
      }
      this.state.users[username] = {
        username,
        role: "owner",
        status: "active",
        password: await hashPassword(password),
        created_at: timestamp,
        updated_at: timestamp,
      };
      return publicUser(this.state.users[username]);
    }, (user) => ({
      event: "owner_initialized",
      actor: user.username,
      target: user.username,
      detail: `before=absent;after=role:owner,status:active;source=${auditText(metadata.source || "local_bootstrap", 32)}`,
      timestamp,
    }));
    return { user: outcome.result, audit_id: outcome.audit_id, audit_pending: outcome.audit_pending };
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

  async verifyPasswordForUser(usernameInput, password) {
    let username = "";
    try {
      username = normalizeUsername(usernameInput);
    } catch (error) {
      if (!(error instanceof AuthError)) throw error;
    }
    const verifiedUser = username ? this._user(username) : null;
    const valid = await verifyPasswordAgainstUser(password, verifiedUser);
    if (!valid || !verifiedUser) return false;
    const current = this._user(username);
    return Boolean(current && current.status === "active" && current.password?.hash === verifiedUser.password?.hash);
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
    return this._mutate(() => this._createUserUnsafe({ username, password, role }, timestamp));
  }

  async _createUserUnsafe({ username, password, role }, timestamp) {
    if (this._user(username)) throw new StateError("user_exists");
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
  }

  async createUserAudited({ username: usernameInput, password, role }, audit = {}, timestamp = Date.now()) {
    const username = normalizeUsername(usernameInput);
    validatePassword(password);
    validateRole(role);
    const outcome = await this._mutateWithAudit(
      () => this._createUserUnsafe({ username, password, role }, timestamp),
      (user) => ({
        ...audit,
        event: "admin_created",
        target: user.username,
        detail: `before=absent;after=role:${user.role},status:${user.status}`,
        timestamp,
      }),
    );
    return { user: outcome.result, audit_id: outcome.audit_id, audit_pending: outcome.audit_pending };
  }

  async updateUser(targetInput, patch, timestamp = Date.now()) {
    const target = normalizeUsername(targetInput);
    if (!patch || typeof patch !== "object" || Array.isArray(patch)) {
      throw new StateError("invalid_user_patch");
    }
    if (!Object.hasOwn(patch, "role") && !Object.hasOwn(patch, "status") && !Object.hasOwn(patch, "password")) {
      throw new StateError("invalid_user_patch");
    }
    return this._mutate(() => this._updateUserUnsafe(target, patch, timestamp));
  }

  async _updateUserUnsafe(target, patch, timestamp) {
    const current = this._user(target);
    if (!current) throw new StateError("user_not_found");
    const before = publicUser(current);
    const replacement = { ...current };
    let revokeSessions = false;
    let passwordRotated = false;
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
      passwordRotated = true;
    }
    if (this._activeOwnerCount({ replacingUsername: target, replacement }) < 1) {
      throw new StateError("last_owner_protected");
    }
    replacement.updated_at = nowMs(timestamp);
    this.state.users[target] = replacement;
    const revoked = revokeSessions ? this._revokeSessionsUnsafe(target) : 0;
    return {
      user: publicUser(replacement),
      before,
      revoked_sessions: revoked,
      password_rotated: passwordRotated,
    };
  }

  async updateUserAudited(targetInput, patch, audit = {}, timestamp = Date.now()) {
    const target = normalizeUsername(targetInput);
    if (!patch || typeof patch !== "object" || Array.isArray(patch)
      || (!Object.hasOwn(patch, "role") && !Object.hasOwn(patch, "status") && !Object.hasOwn(patch, "password"))) {
      throw new StateError("invalid_user_patch");
    }
    const outcome = await this._mutateWithAudit(
      () => this._updateUserUnsafe(target, patch, timestamp),
      (result) => ({
        ...audit,
        event: "admin_updated",
        target: result.user.username,
        detail: `before=role:${result.before.role},status:${result.before.status};after=role:${result.user.role},status:${result.user.status};password_rotated=${result.password_rotated};sessions_revoked=${result.revoked_sessions}`,
        timestamp,
      }),
    );
    const { before: _before, password_rotated: _rotated, ...publicResult } = outcome.result;
    return { ...publicResult, audit_id: outcome.audit_id, audit_pending: outcome.audit_pending };
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
    return this._mutate(() => this._revokeSessionsForUnsafe(target).revoked_sessions);
  }

  _revokeSessionsForUnsafe(target) {
    const user = this._user(target);
    if (!user) throw new StateError("user_not_found");
    return { revoked_sessions: this._revokeSessionsUnsafe(target), user: publicUser(user) };
  }

  async revokeSessionsForAudited(targetInput, audit = {}, timestamp = Date.now()) {
    const target = normalizeUsername(targetInput);
    const outcome = await this._mutateWithAudit(
      () => this._revokeSessionsForUnsafe(target),
      (result) => ({
        ...audit,
        event: "sessions_revoked",
        target: result.user.username,
        detail: `user=role:${result.user.role},status:${result.user.status};sessions_revoked=${result.revoked_sessions}`,
        timestamp,
      }),
    );
    return {
      revoked_sessions: outcome.result.revoked_sessions,
      audit_id: outcome.audit_id,
      audit_pending: outcome.audit_pending,
    };
  }

  async appendAudit({ event, actor = "", target = "", ip = "", detail = "", timestamp = Date.now() }) {
    return this.mutex.run(async () => {
      const previousState = structuredClone(this.state);
      let entry;
      try {
        entry = this._queueAuditUnsafe({ event, actor, target, ip, detail, timestamp });
        await this._save();
      } catch (error) {
        this.state = previousState;
        throw error;
      }
      try {
        await this._flushAuditOutboxUnsafe();
      } catch (error) {
        this.auditFlushError = true;
        throw error;
      }
      return entry;
    });
  }

  async readAudit(limit = 100) {
    const safeLimit = Math.max(1, Math.min(200, Number.parseInt(limit, 10) || 100));
    let diskEntries = [];
    try {
      const raw = await fs.readFile(this.auditPath, "utf8");
      diskEntries = raw
        .split("\n")
        .filter(Boolean)
        .flatMap((line) => {
          try {
            const entry = JSON.parse(line);
            if (!entry || typeof entry !== "object" || typeof entry.event !== "string") {
              return [];
            }
            return [{
              id: auditText(entry.id, 80),
              at: nowMs(entry.at),
              event: auditText(entry.event, 64),
              actor: auditText(entry.actor, 40),
              target: auditText(entry.target, 40),
              ip: auditText(entry.ip, 80),
              detail: auditText(entry.detail, 240),
              pending: false,
            }];
          } catch {
            return [];
          }
        });
    } catch (error) {
      if (!error || error.code !== "ENOENT") this.auditFlushError = true;
    }
    const pendingEntries = Object.values(this.state.audit_outbox ?? {}).map((entry) => ({
      id: auditText(entry.id, 80),
      at: nowMs(entry.at),
      event: auditText(entry.event, 64),
      actor: auditText(entry.actor, 40),
      target: auditText(entry.target, 40),
      ip: auditText(entry.ip, 80),
      detail: auditText(entry.detail, 240),
      pending: true,
    }));
    const merged = new Map();
    for (const [index, entry] of [...diskEntries, ...pendingEntries].entries()) {
      const key = entry.id || `legacy-${index}`;
      merged.set(key, entry);
    }
    return [...merged.values()]
      .sort((left, right) => right.at - left.at || right.id.localeCompare(left.id))
      .slice(0, safeLimit);
  }
}
