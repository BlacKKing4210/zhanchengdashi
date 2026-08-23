import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const SAFE_RECEIPT_ID_PATTERN = /^(?:[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}|invalid-[0-9a-f]{32})$/;
const CARD_ID_PATTERN = /^[A-Za-z0-9_.:-]{1,64}$/;
const USER_ID_PATTERN = /^[A-Za-z0-9_.:-]{1,80}$/;
const MAX_GRANTS = 20;
const MAX_GRANT_AMOUNT = 100_000;
const MAX_ENTRY_BYTES = 8 * 1024 * 1024;
const MAX_LIST_ENTRIES = 200;
const PREVIEW_VERSION = 2;
export const GRANT_PREVIEW_TTL_MS = 2 * 60 * 1000;
export const MAX_SELECTED_TARGETS = 500;
const MAX_PREVIEW_TOKEN_LENGTH = 128 * 1024;

export class GrantError extends Error {
  constructor(status, code) {
    super(code);
    this.name = "GrantError";
    this.status = status;
    this.code = code;
  }
}

function text(value, maxLength = 64) {
  return typeof value === "string"
    ? value.replace(/[\u0000-\u001f\u007f]/g, " ").trim().slice(0, maxLength)
    : "";
}

function grantReason(value) {
  if (typeof value !== "string") throw new GrantError(400, "invalid_reason");
  if (value.length > 200) throw new GrantError(400, "invalid_reason");
  const reason = value.replace(/[\u0000-\u001f\u007f]/g, " ").trim();
  if (reason.length < 4) throw new GrantError(400, "invalid_reason");
  return reason;
}

function integer(value, fallback = 0, minimum = 0, maximum = 1_000_000_000) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.min(maximum, Math.max(minimum, Math.trunc(parsed))) : fallback;
}

function safeUserId(value) {
  const userId = text(value, 80);
  return USER_ID_PATTERN.test(userId) ? userId : "";
}

function safeCardId(value) {
  const cardId = text(value, 64);
  return CARD_ID_PATTERN.test(cardId) ? cardId : "";
}

function sanitizeGrants(value) {
  if (!Array.isArray(value)) return [];
  const grants = [];
  for (const rawGrant of value.slice(0, MAX_GRANTS)) {
    if (!rawGrant || typeof rawGrant !== "object" || Array.isArray(rawGrant)) continue;
    const resource = text(rawGrant.resource, 32).toLowerCase();
    const amount = integer(rawGrant.amount, 0, 0, MAX_GRANT_AMOUNT);
    if (resource === "gacha_tickets" && amount > 0) {
      grants.push({ resource, amount });
    } else if (resource === "card_copies" && amount > 0) {
      const cardId = safeCardId(rawGrant.card_id);
      if (cardId) grants.push({ resource, card_id: cardId, amount });
    }
  }
  return grants;
}

function sanitizeTargets(value) {
  if (!Array.isArray(value)) return [];
  const seen = new Set();
  const result = [];
  for (const rawUserId of value.slice(0, 100_000)) {
    const userId = safeUserId(rawUserId);
    if (userId && !seen.has(userId)) {
      seen.add(userId);
      result.push(userId);
    }
  }
  return result;
}

function requireExactKeys(value, allowedKeys, code = "invalid_grant_request") {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).some((key) => !allowedKeys.has(key))) {
    throw new GrantError(400, code);
  }
}

function validatePreviewGrantShape(grant, typeKey) {
  const type = text(grant?.[typeKey], 32).toLowerCase();
  const allowed = type === "card_copies"
    ? new Set([typeKey, "card_id", "amount"])
    : new Set([typeKey, "amount"]);
  requireExactKeys(grant, allowed);
}

function validatePreviewDraftShape(body) {
  requireExactKeys(body, new Set([
    "target", "grant", "scope", "target_user_id", "target_user_ids", "grants", "reason", "idempotency_key",
  ]));
  const primary = Object.hasOwn(body, "target") || Object.hasOwn(body, "grant");
  if (primary) {
    if (!Object.hasOwn(body, "target") || !Object.hasOwn(body, "grant")
      || ["scope", "target_user_id", "target_user_ids", "grants"].some((key) => Object.hasOwn(body, key))) {
      throw new GrantError(400, "invalid_grant_request");
    }
    const kind = text(body.target?.kind, 16).toLowerCase();
    const targetKeys = kind === "all"
      ? new Set(["kind"])
      : kind === "selected"
        ? new Set(["kind", "user_ids"])
        : new Set(["kind", "user_id"]);
    requireExactKeys(body.target, targetKeys);
    validatePreviewGrantShape(body.grant, "type");
    return;
  }
  if (!Object.hasOwn(body, "scope") || !Object.hasOwn(body, "grants")
    || !Array.isArray(body.grants) || Object.hasOwn(body, "target") || Object.hasOwn(body, "grant")) {
    throw new GrantError(400, "invalid_grant_request");
  }
  const scope = text(body.scope, 16).toLowerCase();
  const hasTargetUserId = Object.hasOwn(body, "target_user_id");
  const hasTargetUserIds = Object.hasOwn(body, "target_user_ids");
  if ((scope === "target" || scope === "user") !== hasTargetUserId
    || (scope === "selected") !== hasTargetUserIds
    || (hasTargetUserId && hasTargetUserIds)) {
    throw new GrantError(400, "invalid_grant_request");
  }
  for (const grant of body.grants) validatePreviewGrantShape(grant, "resource");
}

function previewSecretBuffer(secret) {
  const value = Buffer.isBuffer(secret) ? secret : Buffer.from(String(secret ?? ""), "utf8");
  if (value.length < 32) throw new Error("grant preview secret must be at least 32 bytes");
  return value;
}

function timingSafeBufferEqual(left, right) {
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

function previewSessionBinding(secret, sessionId) {
  const normalizedSessionId = text(sessionId, 256);
  if (!normalizedSessionId) throw new Error("grant preview session is required");
  return crypto.createHmac("sha256", previewSecretBuffer(secret))
    .update(`grant-preview-session:${normalizedSessionId}`, "utf8")
    .digest("base64url");
}

function targetDigest(targetUserIds) {
  return crypto.createHash("sha256")
    .update(JSON.stringify([...targetUserIds].sort()), "utf8")
    .digest("base64url");
}

function signPreviewPayload(payload, secret) {
  const encoded = Buffer.from(JSON.stringify(payload), "utf8").toString("base64url");
  const signature = crypto.createHmac("sha256", previewSecretBuffer(secret))
    .update(`grant-preview-v${PREVIEW_VERSION}.${encoded}`, "utf8")
    .digest("base64url");
  return `v${PREVIEW_VERSION}.${encoded}.${signature}`;
}

function verifyPreviewToken(token, secret) {
  if (typeof token !== "string" || token.length < 32 || token.length > MAX_PREVIEW_TOKEN_LENGTH) {
    throw new GrantError(400, "invalid_preview_token");
  }
  const parts = token.split(".");
  if (parts.length !== 3 || parts[0] !== `v${PREVIEW_VERSION}`) {
    throw new GrantError(400, "invalid_preview_token");
  }
  const expected = crypto.createHmac("sha256", previewSecretBuffer(secret))
    .update(`grant-preview-v${PREVIEW_VERSION}.${parts[1]}`, "utf8")
    .digest();
  let supplied;
  try {
    supplied = Buffer.from(parts[2], "base64url");
  } catch {
    throw new GrantError(400, "invalid_preview_token");
  }
  if (!timingSafeBufferEqual(expected, supplied)) {
    throw new GrantError(400, "invalid_preview_token");
  }
  try {
    const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
    if (!payload || typeof payload !== "object" || Array.isArray(payload) || payload.version !== PREVIEW_VERSION) {
      throw new Error("invalid payload");
    }
    return payload;
  } catch {
    throw new GrantError(400, "invalid_preview_token");
  }
}

export function sanitizeGrantEntry(value, fallbackStatus = "unknown") {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const commandId = text(value.command_id, 80).toLowerCase();
  if (!SAFE_RECEIPT_ID_PATTERN.test(commandId)) return null;
  const status = ["pending", "processed", "failed"].includes(text(value.status, 16))
    ? text(value.status, 16)
    : fallbackStatus;
  const targetUserIds = sanitizeTargets(value.target_user_ids);
  const accounts = Array.isArray(value.accounts)
    ? value.accounts.slice(0, 100_000).flatMap((entry) => {
      if (!entry || typeof entry !== "object" || Array.isArray(entry)) return [];
      const userId = safeUserId(entry.user_id);
      return userId ? [{ user_id: userId, profile_revision: integer(entry.profile_revision, 1, 1, Number.MAX_SAFE_INTEGER) }] : [];
    })
    : [];
  return {
    version: 1,
    command_id: commandId,
    idempotency_key: text(value.idempotency_key, 80).toLowerCase(),
    status,
    scope: ["target", "selected", "all"].includes(text(value.scope, 16)) ? text(value.scope, 16) : "unknown",
    actor: text(value.actor, 40),
    reason: text(value.reason, 200),
    target_user_ids: targetUserIds,
    target_count: integer(value.target_count, targetUserIds.length, 0, 100_000),
    grants: sanitizeGrants(value.grants),
    created_at_unix: integer(value.created_at_unix, 0, 0, 4_102_444_800),
    processed_at_unix: integer(value.processed_at_unix, 0, 0, 4_102_444_800),
    error: text(value.error, 64),
    accounts,
  };
}

function canonicalGrantPayload(value) {
  const entry = sanitizeGrantEntry(value, "pending");
  if (!entry) return "";
  const grants = entry.grants
    .map((grant) => ({
      resource: grant.resource,
      card_id: grant.card_id ?? "",
      amount: grant.amount,
    }))
    .sort((left, right) => `${left.resource}:${left.card_id}`.localeCompare(`${right.resource}:${right.card_id}`));
  return JSON.stringify({
    actor: entry.actor,
    reason: entry.reason,
    scope: entry.scope,
    target_user_ids: [...entry.target_user_ids].sort(),
    grants,
  });
}

export function grantPayloadMatches(existing, requested) {
  const left = canonicalGrantPayload(existing);
  const right = canonicalGrantPayload(requested);
  return Boolean(left && right && left === right);
}

export function resolveCommandRoot(commandRoot) {
  if (typeof commandRoot !== "string" || commandRoot.trim() === "") {
    throw new Error("ZHANCHENG_DASHBOARD_COMMAND_ROOT is required");
  }
  const resolved = path.resolve(commandRoot);
  if (path.parse(resolved).root === resolved) {
    throw new Error("dashboard command root cannot be a filesystem root");
  }
  return resolved;
}

function bucketPath(commandRoot, bucket) {
  return path.join(resolveCommandRoot(commandRoot), bucket);
}

function entryPath(commandRoot, bucket, commandId) {
  return path.join(bucketPath(commandRoot, bucket), `${commandId}.json`);
}

async function readJsonFile(filePath) {
  const metadata = await fs.stat(filePath);
  if (!metadata.isFile() || metadata.size <= 0 || metadata.size > MAX_ENTRY_BYTES) return null;
  return JSON.parse(await fs.readFile(filePath, "utf8"));
}

async function readGrantEntryFromBucket(commandRoot, bucket, commandId) {
  try {
    const raw = await readJsonFile(entryPath(commandRoot, bucket, commandId));
    const entry = sanitizeGrantEntry(raw, bucket);
    if (!entry && (bucket === "processed" || bucket === "failed")) {
      throw new GrantError(409, "invalid_terminal_entry");
    }
    if (entry) entry.status = bucket;
    return entry;
  } catch (error) {
    if (error && error.code === "ENOENT") return null;
    throw error;
  }
}

async function terminalGrantEntries(commandRoot, commandId) {
  const [processed, failed] = await Promise.all([
    readGrantEntryFromBucket(commandRoot, "processed", commandId),
    readGrantEntryFromBucket(commandRoot, "failed", commandId),
  ]);
  return { processed, failed };
}

async function quarantineConflictingPending(commandRoot, commandId) {
  const pendingPath = entryPath(commandRoot, "pending", commandId);
  const quarantinePath = path.join(
    bucketPath(commandRoot, "pending"),
    `.quarantine-${commandId}-terminal-conflict-${Date.now()}-${crypto.randomBytes(6).toString("hex")}.json.disabled`,
  );
  try {
    await fs.rename(pendingPath, quarantinePath);
  } catch (error) {
    if (!error || error.code !== "ENOENT") throw error;
  }
  return quarantinePath;
}

async function reconcilePendingWithTerminal(commandRoot, commandId) {
  const { processed, failed } = await terminalGrantEntries(commandRoot, commandId);
  if (!processed && !failed) return null;
  const pendingPath = entryPath(commandRoot, "pending", commandId);
  if (processed && failed) {
    await quarantineConflictingPending(commandRoot, commandId);
    if (await readGrantEntryFromBucket(commandRoot, "pending", commandId)) {
      throw new GrantError(503, "command_reconciliation_failed");
    }
    throw new GrantError(409, "terminal_state_conflict");
  }
  try {
    await fs.unlink(pendingPath);
  } catch (error) {
    if (!error || error.code !== "ENOENT") throw error;
  }
  if (await readGrantEntryFromBucket(commandRoot, "pending", commandId)) {
    throw new GrantError(503, "command_reconciliation_failed");
  }
  return processed ?? failed;
}

export async function findGrantEntry(commandRoot, commandId) {
  const normalizedId = text(commandId, 80).toLowerCase();
  if (!UUID_PATTERN.test(normalizedId)) return null;
  return await reconcilePendingWithTerminal(commandRoot, normalizedId)
    ?? await readGrantEntryFromBucket(commandRoot, "pending", normalizedId);
}

export function prepareGrantCommand({ body, accountSnapshot, actor, now = Date.now() }) {
  if (!body || typeof body !== "object" || Array.isArray(body)) throw new GrantError(400, "invalid_grant_request");
  if (!accountSnapshot || accountSnapshot.availability !== "ready" || !Array.isArray(accountSnapshot.accounts)) {
    throw new GrantError(503, "account_snapshot_unavailable");
  }
  const commandId = text(body.idempotency_key, 80).toLowerCase();
  if (!UUID_PATTERN.test(commandId)) throw new GrantError(400, "invalid_idempotency_key");
  const primaryTarget = body.target && typeof body.target === "object" && !Array.isArray(body.target) ? body.target : null;
  const requestedScope = text(primaryTarget?.kind ?? body.scope, 16).toLowerCase();
  const scope = requestedScope === "user" ? "target" : requestedScope;
  if (!new Set(["target", "selected", "all"]).has(scope)) throw new GrantError(400, "invalid_scope");
  const availableUserIds = [...new Set(accountSnapshot.accounts.map((entry) => safeUserId(entry.user_id)).filter(Boolean))].sort();
  const availableUserIdSet = new Set(availableUserIds);
  let targetUserIds;
  if (scope === "all") {
    if ((body.confirmation ?? body.all_confirmation) !== "SEND TO ALL") throw new GrantError(400, "all_confirmation_required");
    targetUserIds = availableUserIds;
  } else if (scope === "selected") {
    if (body.confirmation !== "SEND") throw new GrantError(400, "target_confirmation_required");
    const rawTargetUserIds = primaryTarget?.user_ids ?? body.target_user_ids;
    if (!Array.isArray(rawTargetUserIds) || rawTargetUserIds.length < 2) {
      throw new GrantError(400, "selected_targets_required");
    }
    if (rawTargetUserIds.length > MAX_SELECTED_TARGETS) throw new GrantError(400, "selected_target_limit");
    const seenTargetUserIds = new Set();
    targetUserIds = [];
    for (const rawTargetUserId of rawTargetUserIds) {
      const targetUserId = safeUserId(rawTargetUserId);
      if (!targetUserId || !availableUserIdSet.has(targetUserId)) throw new GrantError(404, "target_not_found");
      if (seenTargetUserIds.has(targetUserId)) throw new GrantError(400, "duplicate_target");
      seenTargetUserIds.add(targetUserId);
      targetUserIds.push(targetUserId);
    }
    targetUserIds.sort();
    if (targetUserIds.length === availableUserIds.length) throw new GrantError(400, "all_scope_required");
  } else {
    if (body.confirmation !== "SEND") throw new GrantError(400, "target_confirmation_required");
    const targetUserId = safeUserId(primaryTarget?.user_id ?? body.target_user_id);
    if (!targetUserId || !availableUserIdSet.has(targetUserId)) throw new GrantError(404, "target_not_found");
    targetUserIds = [targetUserId];
  }
  if (targetUserIds.length === 0) throw new GrantError(409, "no_target_accounts");
  const primaryGrant = body.grant && typeof body.grant === "object" && !Array.isArray(body.grant)
    ? { ...body.grant, resource: body.grant.type }
    : null;
  const requestedGrants = primaryGrant ? [primaryGrant] : body.grants;
  if (!Array.isArray(requestedGrants) || requestedGrants.length < 1 || requestedGrants.length > MAX_GRANTS) {
    throw new GrantError(400, "invalid_grants");
  }
  const reason = grantReason(body.reason);
  const grants = [];
  const grantKeys = new Set();
  for (const rawGrant of requestedGrants) {
    if (!rawGrant || typeof rawGrant !== "object" || Array.isArray(rawGrant)) throw new GrantError(400, "invalid_grant");
    const resource = text(rawGrant.resource, 32).toLowerCase();
    const amount = Number(rawGrant.amount);
    if (!Number.isInteger(amount) || amount < 1 || amount > MAX_GRANT_AMOUNT) throw new GrantError(400, "invalid_grant_amount");
    if (resource === "gacha_tickets") {
      if (grantKeys.has(resource)) throw new GrantError(400, "duplicate_grant");
      grantKeys.add(resource);
      grants.push({ resource, amount });
    } else if (resource === "card_copies") {
      const cardId = safeCardId(rawGrant.card_id);
      if (!cardId) throw new GrantError(400, "invalid_card_id");
      const grantKey = `${resource}:${cardId}`;
      if (grantKeys.has(grantKey)) throw new GrantError(400, "duplicate_grant");
      grantKeys.add(grantKey);
      grants.push({ resource, card_id: cardId, amount });
    } else {
      throw new GrantError(400, "unsupported_resource");
    }
  }
  return {
    version: 1,
    command_id: commandId,
    idempotency_key: commandId,
    status: "pending",
    actor: text(actor, 40),
    reason,
    scope,
    all_confirmation: scope === "all" ? "SEND TO ALL" : "",
    target_user_ids: targetUserIds,
    target_count: targetUserIds.length,
    grants,
    created_at_unix: Math.max(0, Math.floor(now / 1000)),
  };
}

export function createGrantPreview({
  body,
  accountSnapshot,
  actor,
  sessionId,
  secret,
  now = Date.now(),
  ttlMs = GRANT_PREVIEW_TTL_MS,
}) {
  validatePreviewDraftShape(body);
  if (!Number.isFinite(ttlMs) || ttlMs < 1_000 || ttlMs > GRANT_PREVIEW_TTL_MS) {
    throw new Error("invalid grant preview ttl");
  }
  const primaryTarget = body?.target && typeof body.target === "object" && !Array.isArray(body.target) ? body.target : null;
  const requestedScope = text(primaryTarget?.kind ?? body?.scope, 16).toLowerCase();
  const confirmation = requestedScope === "all" ? "SEND TO ALL" : "SEND";
  const command = prepareGrantCommand({
    body: { ...body, confirmation },
    accountSnapshot,
    actor,
    now,
  });
  const issuedAtMs = Math.floor(now);
  const payload = {
    version: PREVIEW_VERSION,
    issued_at_ms: issuedAtMs,
    expires_at_ms: issuedAtMs + Math.floor(ttlMs),
    session_binding: previewSessionBinding(secret, sessionId),
    actor: command.actor,
    command_id: command.command_id,
    scope: command.scope,
    target_user_id: command.scope === "target" ? command.target_user_ids[0] : "",
    target_user_ids: command.scope === "selected" ? [...command.target_user_ids] : [],
    target_count: command.target_count,
    targets_digest: targetDigest(command.target_user_ids),
    reason: command.reason,
    grants: command.grants,
  };
  return {
    preview_token: signPreviewPayload(payload, secret),
    expires_at_unix: Math.floor(payload.expires_at_ms / 1000),
    target_count: payload.target_count,
    scope: payload.scope,
    target_user_ids: command.scope === "all" ? [] : [...command.target_user_ids],
    targets_digest: payload.targets_digest,
    grants: command.grants,
    reason: command.reason,
    idempotency_key: command.idempotency_key,
  };
}

export function commandFromGrantPreview({
  body,
  accountSnapshot,
  actor,
  sessionId,
  secret,
  now = Date.now(),
}) {
  if (!body || typeof body !== "object" || Array.isArray(body)) throw new GrantError(400, "invalid_grant_request");
  // Single and selected targets use the already-authenticated Owner session and
  // signed one-use preview. Broad all-account grants additionally carry password
  // and explicit text confirmation, which the HTTP layer verifies before enqueue.
  const allowedBodyFields = new Set(["preview_token", "idempotency_key", "password", "confirmation"]);
  if (Object.keys(body).some((key) => !allowedBodyFields.has(key))) {
    throw new GrantError(400, "invalid_preview_request");
  }
  const payload = verifyPreviewToken(body.preview_token, secret);
  const nowMs = Math.floor(now);
  if (!Number.isFinite(payload.issued_at_ms) || !Number.isFinite(payload.expires_at_ms)
    || payload.issued_at_ms > nowMs + 30_000 || payload.expires_at_ms <= nowMs
    || payload.expires_at_ms - payload.issued_at_ms > GRANT_PREVIEW_TTL_MS) {
    throw new GrantError(409, "preview_expired");
  }
  const expectedBinding = Buffer.from(previewSessionBinding(secret, sessionId), "utf8");
  const suppliedBinding = Buffer.from(String(payload.session_binding ?? ""), "utf8");
  if (!timingSafeBufferEqual(expectedBinding, suppliedBinding) || payload.actor !== text(actor, 40)) {
    throw new GrantError(403, "preview_session_mismatch");
  }
  const commandId = text(payload.command_id, 80).toLowerCase();
  const requestedCommandId = text(body.idempotency_key, 80).toLowerCase();
  if (!UUID_PATTERN.test(commandId) || (requestedCommandId && requestedCommandId !== commandId)) {
    throw new GrantError(400, "invalid_preview_request");
  }
  const scope = text(payload.scope, 16);
  if (!new Set(["target", "selected", "all"]).has(scope)) throw new GrantError(400, "invalid_preview_token");
  if (scope === "all") {
    if (body.confirmation !== "SEND TO ALL") throw new GrantError(400, "all_confirmation_required");
    if (typeof body.password !== "string" || body.password.length < 1 || body.password.length > 256) {
      throw new GrantError(401, "owner_reauthentication_failed");
    }
  } else if (Object.hasOwn(body, "password") || Object.hasOwn(body, "confirmation")) {
    throw new GrantError(400, "invalid_preview_request");
  }
  if (!accountSnapshot || accountSnapshot.availability !== "ready" || !Array.isArray(accountSnapshot.accounts)) {
    throw new GrantError(503, "account_snapshot_unavailable");
  }
  const availableUserIds = [...new Set(accountSnapshot.accounts.map((entry) => safeUserId(entry.user_id)).filter(Boolean))].sort();
  const availableUserIdSet = new Set(availableUserIds);
  let targetUserIds;
  if (scope === "all") {
    targetUserIds = availableUserIds;
  } else if (scope === "target") {
    targetUserIds = [safeUserId(payload.target_user_id)].filter((userId) => userId && availableUserIdSet.has(userId));
  } else {
    const rawTargetUserIds = payload.target_user_ids;
    if (!Array.isArray(rawTargetUserIds) || rawTargetUserIds.length < 2
      || rawTargetUserIds.length > MAX_SELECTED_TARGETS) {
      throw new GrantError(400, "invalid_preview_token");
    }
    const seenTargetUserIds = new Set();
    targetUserIds = [];
    for (const rawTargetUserId of rawTargetUserIds) {
      const targetUserId = safeUserId(rawTargetUserId);
      if (!targetUserId || !availableUserIdSet.has(targetUserId) || seenTargetUserIds.has(targetUserId)) {
        throw new GrantError(409, "preview_stale");
      }
      seenTargetUserIds.add(targetUserId);
      targetUserIds.push(targetUserId);
    }
    targetUserIds.sort();
    if (targetUserIds.length === availableUserIds.length) throw new GrantError(409, "all_scope_required");
  }
  if (targetUserIds.length === 0) throw new GrantError(409, "preview_stale");
  if (payload.target_count !== targetUserIds.length || payload.targets_digest !== targetDigest(targetUserIds)) {
    throw new GrantError(409, "preview_stale");
  }
  let reason;
  try {
    reason = grantReason(payload.reason);
  } catch {
    throw new GrantError(400, "invalid_preview_token");
  }
  const grants = sanitizeGrants(payload.grants);
  if (grants.length === 0 || grants.length !== payload.grants?.length) {
    throw new GrantError(400, "invalid_preview_token");
  }
  return {
    version: 1,
    command_id: commandId,
    idempotency_key: commandId,
    status: "pending",
    actor: text(actor, 40),
    reason,
    scope,
    all_confirmation: scope === "all" ? "SEND TO ALL" : "",
    target_user_ids: targetUserIds,
    target_count: targetUserIds.length,
    grants,
    created_at_unix: Math.max(0, Math.floor(nowMs / 1000)),
  };
}

async function writeJsonNoReplace(targetPath, value) {
  await fs.mkdir(path.dirname(targetPath), { recursive: true, mode: 0o700 });
  const tempPath = path.join(path.dirname(targetPath), `.${path.basename(targetPath)}.${process.pid}.${crypto.randomBytes(8).toString("hex")}.tmp`);
  const handle = await fs.open(tempPath, "wx", 0o660);
  try {
    await handle.writeFile(`${JSON.stringify(value, null, 2)}\n`, "utf8");
    await handle.sync();
  } finally {
    await handle.close();
  }
  try {
    await fs.link(tempPath, targetPath);
  } finally {
    await fs.unlink(tempPath).catch(() => {});
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
  try {
    await fs.chmod(targetPath, 0o660);
  } catch {
    // Windows does not implement POSIX ownership modes.
  }
}

export async function enqueueGrantCommand(commandRoot, command, testHooks = {}) {
  const sanitized = sanitizeGrantEntry(command, "pending");
  if (!sanitized || !UUID_PATTERN.test(sanitized.command_id)) throw new GrantError(400, "invalid_command");
  const existing = await findGrantEntry(commandRoot, sanitized.command_id);
  if (existing) {
    if (!grantPayloadMatches(existing, command)) throw new GrantError(409, "idempotency_conflict");
    return { command: existing, idempotent: true };
  }
  if (typeof testHooks.afterPreflight === "function") await testHooks.afterPreflight();
  try {
    await writeJsonNoReplace(entryPath(commandRoot, "pending", sanitized.command_id), command);
    if (typeof testHooks.afterPendingWrite === "function") await testHooks.afterPendingWrite();
    const terminal = await reconcilePendingWithTerminal(commandRoot, sanitized.command_id);
    if (terminal) {
      if (!grantPayloadMatches(terminal, command)) throw new GrantError(409, "idempotency_conflict");
      return { command: terminal, idempotent: false };
    }
    const settled = await findGrantEntry(commandRoot, sanitized.command_id);
    if (settled && settled.status !== "pending") {
      await reconcilePendingWithTerminal(commandRoot, sanitized.command_id);
      if (!grantPayloadMatches(settled, command)) throw new GrantError(409, "idempotency_conflict");
      return { command: settled, idempotent: false };
    }
    if (!settled || !grantPayloadMatches(settled, command)) {
      throw new GrantError(503, "command_reconciliation_failed");
    }
    const lateTerminal = await reconcilePendingWithTerminal(commandRoot, sanitized.command_id);
    if (lateTerminal) {
      if (!grantPayloadMatches(lateTerminal, command)) throw new GrantError(409, "idempotency_conflict");
      return { command: lateTerminal, idempotent: false };
    }
    return { command: settled, idempotent: false };
  } catch (error) {
    if (error && error.code === "EEXIST") {
      const raced = await findGrantEntry(commandRoot, sanitized.command_id);
      if (raced) {
        if (!grantPayloadMatches(raced, command)) throw new GrantError(409, "idempotency_conflict");
        return { command: raced, idempotent: true };
      }
    }
    throw error;
  }
}

export async function readGrantEntries(commandRoot, limit = MAX_LIST_ENTRIES) {
  const entries = [];
  for (const [bucket, status] of [["pending", "pending"], ["processed", "processed"], ["failed", "failed"]]) {
    const directory = bucketPath(commandRoot, bucket);
    let names;
    try {
      names = await fs.readdir(directory);
    } catch (error) {
      if (error && error.code === "ENOENT") continue;
      throw error;
    }
    for (const name of names.slice(-1_000)) {
      if (!name.endsWith(".json")) continue;
      try {
        const entry = sanitizeGrantEntry(await readJsonFile(path.join(directory, name)), status);
        if (entry) {
          entry.status = status;
          entries.push(entry);
        }
      } catch {
        // A partial/corrupt entry stays unavailable instead of leaking raw bytes.
      }
    }
  }
  const byCommandId = new Map();
  for (const entry of entries) {
    const existing = byCommandId.get(entry.command_id);
    if (!existing) {
      byCommandId.set(entry.command_id, entry);
      continue;
    }
    const terminal = new Set(["processed", "failed"]);
    if (terminal.has(existing.status) && terminal.has(entry.status) && existing.status !== entry.status) {
      byCommandId.set(entry.command_id, { ...entry, status: "failed", error: "terminal_state_conflict" });
    } else if (!terminal.has(existing.status) && terminal.has(entry.status)) {
      byCommandId.set(entry.command_id, entry);
    }
  }
  const uniqueEntries = [...byCommandId.values()];
  uniqueEntries.sort((left, right) => (right.processed_at_unix || right.created_at_unix) - (left.processed_at_unix || left.created_at_unix)
    || right.created_at_unix - left.created_at_unix
    || left.command_id.localeCompare(right.command_id));
  return uniqueEntries.slice(0, Math.max(1, Math.min(MAX_LIST_ENTRIES, Number.parseInt(limit, 10) || MAX_LIST_ENTRIES)));
}
