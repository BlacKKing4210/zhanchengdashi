import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { sanitizeAccountSnapshot } from "../../tools/admin_dashboard/lib/account_snapshot.mjs";
import { hashPassword, LoginRateLimiter, verifyPassword } from "../../tools/admin_dashboard/lib/auth.mjs";
import {
  commandFromGrantPreview,
  createGrantPreview,
  enqueueGrantCommand,
  GRANT_PREVIEW_TTL_MS,
  prepareGrantCommand,
} from "../../tools/admin_dashboard/lib/resource_grants.mjs";
import { sanitizeDashboardSnapshot } from "../../tools/admin_dashboard/lib/snapshot.mjs";
import { DashboardState, SESSION_IDLE_MS } from "../../tools/admin_dashboard/lib/state_store.mjs";
import { buildRuntimeConfig, createDashboardServer, isEntrypointPath, resetOwnerPassword, runCli } from "../../tools/admin_dashboard/server.mjs";

const execFileAsync = promisify(execFile);
const PROJECT_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

async function temporaryDirectory(testContext) {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "jungle-dashboard-test-"));
  testContext.after(async () => fs.rm(directory, { recursive: true, force: true }));
  return directory;
}

function cookiePair(response) {
  return String(response.headers.get("set-cookie") ?? "").split(";")[0];
}

test("CLI entrypoint remains active when server.mjs is invoked through a current-release symlink", async (context) => {
  const workspaceTemporaryRoot = path.join(PROJECT_ROOT, "temp", "qa", "admin-dashboard-entrypoint-tests");
  await fs.mkdir(workspaceTemporaryRoot, { recursive: true });
  const directory = await fs.mkdtemp(path.join(workspaceTemporaryRoot, "case-"));
  context.after(async () => fs.rm(directory, { recursive: true, force: true }));
  const releaseDirectory = path.join(PROJECT_ROOT, "tools", "admin_dashboard");
  const currentDirectory = path.join(directory, "current");
  await fs.symlink(releaseDirectory, currentDirectory, process.platform === "win32" ? "junction" : "dir");
  const linkedEntrypoint = path.join(currentDirectory, "server.mjs");

  assert.equal(isEntrypointPath(linkedEntrypoint), true);
  const { stdout, stderr } = await execFileAsync(process.execPath, [linkedEntrypoint, "--help"], {
    encoding: "utf8",
    timeout: 5_000,
  });
  assert.match(stdout, /Usage:/);
  assert.equal(stderr, "");
});

async function jsonRequest(baseUrl, pathname, options = {}) {
  const response = await fetch(`${baseUrl}${pathname}`, {
    ...options,
    headers: {
      ...(options.headers ?? {}),
    },
  });
  return { response, body: await response.json() };
}

async function waitUntil(predicate, timeoutMs = 1_000) {
  const deadline = Date.now() + timeoutMs;
  while (!predicate()) {
    if (Date.now() >= deadline) {
      throw new Error("timed out waiting for asynchronous test condition");
    }
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
}

test("scrypt credentials verify correctly without accepting an incorrect password", async () => {
  const record = await hashPassword("A sufficiently secure password");
  assert.equal(record.algorithm, "scrypt");
  assert.notEqual(record.hash, "A sufficiently secure password");
  assert.equal(await verifyPassword("A sufficiently secure password", record), true);
  assert.equal(await verifyPassword("A different password", record), false);
});

test("dashboard state has no default account and only permits one local owner bootstrap", async (context) => {
  const directory = await temporaryDirectory(context);
  const state = await DashboardState.open(directory);
  assert.equal(state.hasAnyUsers(), false);
  const owner = await state.initializeOwner("owner-one", "Owner password one 123");
  assert.deepEqual(owner.role, "owner");
  assert.equal(state.hasAnyUsers(), true);
  await assert.rejects(
    () => state.initializeOwner("owner-two", "Owner password two 123"),
    (error) => error.code === "owner_initialization_closed",
  );
});

test("offline Owner password rotation is audited, revokes sessions and refuses password arguments", async (context) => {
  const directory = await temporaryDirectory(context);
  const state = await DashboardState.open(directory);
  const oldPassword = "Owner password before rotation 123";
  const newPassword = "Owner password after rotation 456";
  await state.initializeOwner("owner-one", oldPassword);
  const login = await state.authenticate("owner-one", oldPassword);
  assert.equal(login.ok, true);

  const rotated = await resetOwnerPassword(state, "owner-one", newPassword, newPassword);
  assert.equal(rotated.user.role, "owner");
  assert.equal(rotated.revoked_sessions, 1);
  assert.equal(await state.sessionForToken(login.session_token), null);
  assert.equal((await state.authenticate("owner-one", oldPassword)).ok, false);
  assert.equal((await state.authenticate("owner-one", newPassword)).ok, true);
  const auditText = JSON.stringify(await state.readAudit());
  assert.match(auditText, /admin_updated/);
  assert.match(auditText, /password_rotated=true/);
  assert.doesNotMatch(auditText, new RegExp(newPassword));

  await assert.rejects(
    () => runCli(["reset-owner-password", "--state-dir", directory, "--username", "owner-one", `--password=${newPassword}`]),
    /unknown option: --password/,
  );
});

test("sessions expire after inactivity and cannot be revived", async (context) => {
  const directory = await temporaryDirectory(context);
  const state = await DashboardState.open(directory);
  await state.initializeOwner("owner-one", "Owner password one 123");
  const createdAt = 500_000;
  const login = await state.authenticate("owner-one", "Owner password one 123", createdAt);
  assert.equal(login.ok, true);
  assert.ok(await state.sessionForToken(login.session_token, createdAt + SESSION_IDLE_MS - 1));
  assert.equal(await state.sessionForToken(login.session_token, createdAt + SESSION_IDLE_MS * 2), null);
  assert.equal(await state.sessionForToken(login.session_token, createdAt + SESSION_IDLE_MS * 2 + 1), null);
});

test("login rate limiter applies independent IP and username limits", () => {
  let now = 10_000;
  const limiter = new LoginRateLimiter({ limit: 2, windowMs: 1_000, now: () => now });
  assert.equal(limiter.check("127.0.0.1", "tester").allowed, true);
  limiter.recordFailure("127.0.0.1", "tester");
  limiter.recordFailure("127.0.0.1", "tester");
  assert.equal(limiter.check("127.0.0.1", "tester").allowed, false);
  assert.equal(limiter.check("127.0.0.2", "tester").allowed, false);
  now += 1_001;
  assert.equal(limiter.check("127.0.0.1", "tester").allowed, true);
});

test("concurrent login pressure reserves KDF capacity before authentication", async (context) => {
  const directory = await temporaryDirectory(context);
  const snapshotPath = path.join(directory, "dashboard_snapshot.json");
  await fs.writeFile(snapshotPath, "{}");
  const pendingAuthentications = [];
  const state = {
    authenticate() {
      return new Promise((resolve) => pendingAuthentications.push(resolve));
    },
    async appendAudit() {},
  };
  const app = await createDashboardServer({
    host: "127.0.0.1",
    port: 0,
    snapshotPath,
    stateDirectory: path.join(directory, "state"),
    state,
    limiter: new LoginRateLimiter({ limit: 2 }),
  });
  context.after(() => app.close());
  const address = await app.listen();
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const requests = Array.from({ length: 8 }, () => jsonRequest(baseUrl, "/api/auth/login", {
    method: "POST",
    headers: { Origin: baseUrl, "Content-Type": "application/json" },
    body: JSON.stringify({ username: "owner-one", password: "wrong password" }),
  }));
  await waitUntil(() => pendingAuthentications.length >= 2);
  const admittedCount = pendingAuthentications.length;
  pendingAuthentications.forEach((resolve) => resolve({ ok: false }));
  const responses = await Promise.all(requests);
  assert.equal(admittedCount, 2, "only the configured KDF budget should be in flight");
  assert.equal(responses.filter(({ response }) => response.status === 401).length, 2);
  assert.equal(responses.filter(({ response }) => response.status === 429).length, 6);
});

test("snapshot sanitizer keeps only dashboard allow-list fields", () => {
  const snapshot = sanitizeDashboardSnapshot({
    generated_at_unix: 1_700_000_000,
    password_hash: "must-not-leak",
    overview: { matches: 9, players: 2, active_24h: 1, season: "S1", source: "all_completed_authenticated_battles_by_type", account: "must-not-leak" },
    battle_types: [{
      battle_type: "classic_ranked_ai",
      matches: 4,
      authorities: { authenticated_client_reported: 4, hidden_authority: 99 },
    }],
    leaderboard: [{
      rank: 1,
      user_id: "U-TEST",
      display_name: "测试玩家",
      rank_key: "king",
      rank_stars: 12,
      elo: 1510,
      matches: 9,
      wins: 6,
      losses: 3,
      account: "must-not-leak",
      password_hash: "must-not-leak",
      deck: ["rabbit", "wolf", "invalid card id"],
      card_levels: { rabbit: 4, wolf: 3, hidden: 99 },
    }],
    animals: [{
      card_id: "rabbit",
      name: "兔子",
      battle_type: "classic_ranked_ai",
      games: 9,
      wins: 6,
      losses: 3,
      pick_rate: 0.5,
      placement_samples: 9,
      placement_sum: 13,
      placement_score_sum: 5,
      placement_field_size_sum: 18,
      balance_signal: "observe",
      confidence: { sample_sufficient: false, win_rate_lower: 0.35, win_rate_upper: 0.88, rationale: "样本不足" },
      private_note: "must-not-leak",
    }],
    animals_by_battle_type: {
      classic_ranked_ai: [{
        card_id: "rabbit",
        name: "兔子",
        games: 4,
        wins: 3,
        losses: 1,
        placement_samples: 4,
        placement_sum: 5,
      }],
    },
    recent_matches: [{
      match_id: "server-match-1",
      map_id: "1v1_crossroads",
      battle_type: "multiplayer_1v1",
      analytics_authority: "server_authoritative",
      state: "finalized",
      finalized_at_unix: 1_700_000_001,
      private_note: "must-not-leak",
      team_outcomes: { 1: "win", 4: "loss", 99: "hidden" },
      players: [{ user_id: "U-TEST", display_name: "测试玩家", team_id: 1, rank_key: "king", rank_stars: 12, password_hash: "must-not-leak" }],
    }],
  });
  assert.equal(snapshot.leaderboard.length, 1);
  assert.deepEqual(snapshot.leaderboard[0].deck, ["rabbit", "wolf"]);
  assert.deepEqual(snapshot.leaderboard[0].card_levels, { rabbit: 4, wolf: 3 });
  assert.equal(Object.hasOwn(snapshot, "password_hash"), false);
  assert.equal(Object.hasOwn(snapshot.leaderboard[0], "account"), false);
  assert.equal(Object.hasOwn(snapshot.animals[0], "private_note"), false);
  assert.equal(snapshot.animals[0].pick_rate, 0.5);
  assert.equal(snapshot.animals[0].average_placement, 13 / 9);
  assert.equal(snapshot.animals[0].average_placement_score, 5 / 9);
  assert.equal(snapshot.animals[0].average_field_size, 2);
  assert.equal(snapshot.animals[0].balance_signal, "observe");
  assert.deepEqual(snapshot.animals[0].confidence, {
    sample_sufficient: false,
    win_rate_lower: 0.35,
    win_rate_upper: 0.88,
    rationale: "样本不足",
  });
  assert.equal(snapshot.overview.source, "all_completed_authenticated_battles_by_type");
  assert.deepEqual(snapshot.battle_types, [{
    battle_type: "classic_ranked_ai",
    matches: 4,
    authorities: { authenticated_client_reported: 4, legacy_server_recorded: 99 },
  }]);
  assert.equal(snapshot.animals[0].battle_type, "classic_ranked_ai");
  assert.equal(snapshot.animals_by_battle_type.classic_ranked_ai[0].average_placement, 1.25);
  assert.equal(snapshot.recent_matches.length, 1);
  assert.equal(snapshot.recent_matches[0].battle_type, "multiplayer_1v1");
  assert.equal(snapshot.recent_matches[0].analytics_authority, "server_authoritative");
  assert.deepEqual(snapshot.recent_matches[0].team_outcomes, { 1: "win", 4: "loss" });
  assert.equal(Object.hasOwn(snapshot.recent_matches[0], "private_note"), false);
  assert.equal(Object.hasOwn(snapshot.recent_matches[0].players[0], "password_hash"), false);
  const analyticsCompatible = sanitizeDashboardSnapshot({
    leaderboard: [{ user_id: "U-ONE", rank_key: "gold", rank_stars: 4 }],
    animals: [{ card_id: "wolf", appearances: 7, wins: 4, losses: 3, win_rate: null }],
  });
  assert.equal(analyticsCompatible.leaderboard[0].elo, null);
  assert.equal(analyticsCompatible.animals[0].games, 7);
  assert.equal(analyticsCompatible.animals[0].pick_rate, null);
  assert.equal(analyticsCompatible.animals[0].win_rate, 4 / 7);
});

test("protected HTTP dashboard enforces RBAC, cookies, CSRF/origin and session revocation", async (context) => {
  const directory = await temporaryDirectory(context);
  const snapshotPath = path.join(directory, "dashboard_snapshot.json");
  await fs.writeFile(snapshotPath, JSON.stringify({
    generated_at_unix: 1_700_000_000,
    overview: { matches: 2, players: 1, active_24h: 1, season: "S1" },
    leaderboard: [{
      rank: 1,
      user_id: "U-TEST",
      display_name: "榜首玩家",
      rank_key: "king",
      rank_stars: 6,
      elo: 1600,
      matches: 2,
      wins: 2,
      deck: ["rabbit"],
      card_levels: { rabbit: 4 },
      account: "must-not-leak",
    }],
    animals: [{ card_id: "rabbit", name: "兔子", games: 2, wins: 2, pick_rate: 0.5 }],
  }));
  const stateDirectory = path.join(directory, "state");
  const state = await DashboardState.open(stateDirectory);
  await state.initializeOwner("owner-one", "Owner password one 123");
  await state.createUser({ username: "analyst-one", password: "Analyst password one 123", role: "analyst" });
  const app = await createDashboardServer({
    host: "127.0.0.1",
    port: 0,
    snapshotPath,
    stateDirectory,
    state,
  });
  context.after(() => app.close());
  const address = await app.listen();
  const baseUrl = `http://127.0.0.1:${address.port}`;

  const ownerLogin = await jsonRequest(baseUrl, "/api/auth/login", {
    method: "POST",
    headers: { Origin: baseUrl, "Content-Type": "application/json" },
    body: JSON.stringify({ username: "owner-one", password: "Owner password one 123" }),
  });
  assert.equal(ownerLogin.response.status, 200);
  assert.match(ownerLogin.response.headers.get("set-cookie") ?? "", /HttpOnly/);
  assert.match(ownerLogin.response.headers.get("set-cookie") ?? "", /SameSite=Strict/);
  assert.doesNotMatch(ownerLogin.response.headers.get("set-cookie") ?? "", /Secure/);
  const ownerCookie = cookiePair(ownerLogin.response);
  const ownerCsrf = ownerLogin.body.csrf_token;

  const landing = await fetch(`${baseUrl}/`);
  assert.equal(landing.status, 200);
  assert.match(landing.headers.get("content-security-policy") ?? "", /default-src 'self'/);
  assert.match(await landing.text(), /运营数据后台|赛事数据中心/);

  const dashboard = await jsonRequest(baseUrl, "/api/dashboard", { headers: { Cookie: ownerCookie } });
  assert.equal(dashboard.response.status, 200);
  assert.equal(dashboard.body.leaderboard[0].display_name, "榜首玩家");
  assert.equal(Object.hasOwn(dashboard.body.leaderboard[0], "account"), false);

  const analystLogin = await jsonRequest(baseUrl, "/api/auth/login", {
    method: "POST",
    headers: { Origin: baseUrl, "Content-Type": "application/json" },
    body: JSON.stringify({ username: "analyst-one", password: "Analyst password one 123" }),
  });
  const analystCookie = cookiePair(analystLogin.response);
  const analystAdminList = await jsonRequest(baseUrl, "/api/admins", { headers: { Cookie: analystCookie } });
  assert.equal(analystAdminList.response.status, 403);
  assert.equal(analystAdminList.body.error, "owner_required");

  const noCsrf = await jsonRequest(baseUrl, "/api/admins", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "Content-Type": "application/json" },
    body: JSON.stringify({ username: "analyst-two", password: "Analyst password two 123", role: "analyst" }),
  });
  assert.equal(noCsrf.response.status, 403);
  assert.equal(noCsrf.body.error, "csrf_rejected");

  const wrongOrigin = await jsonRequest(baseUrl, "/api/admins", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: "http://evil.example", "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({ username: "analyst-two", password: "Analyst password two 123", role: "analyst" }),
  });
  assert.equal(wrongOrigin.response.status, 403);
  assert.equal(wrongOrigin.body.error, "origin_rejected");

  const createAnalyst = await jsonRequest(baseUrl, "/api/admins", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({ username: "analyst-two", password: "Analyst password two 123", role: "analyst" }),
  });
  assert.equal(createAnalyst.response.status, 201);
  assert.equal(createAnalyst.body.user.role, "analyst");

  const revoke = await jsonRequest(baseUrl, "/api/admins/analyst-one/revoke-sessions", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({}),
  });
  assert.equal(revoke.response.status, 200);
  const revokedDashboard = await jsonRequest(baseUrl, "/api/dashboard", { headers: { Cookie: analystCookie } });
  assert.equal(revokedDashboard.response.status, 401);

  const audit = await state.readAudit();
  const auditText = JSON.stringify(audit);
  assert.match(auditText, /login_success/);
  assert.doesNotMatch(auditText, /Owner password one 123/);
  assert.doesNotMatch(auditText, /jungle_admin_session/);
});

test("account snapshot sanitizer exposes saved decks and resources without credential material", () => {
  const snapshot = sanitizeAccountSnapshot({
    generated_at_unix: 1_700_000_000,
    card_names: { rabbit: "兔子", wolf: "狼", "invalid card id": "不应出现" },
    accounts: [{
      user_id: "U-ONE",
      username: "  狐狸队长\u0000  ",
      masked_account: "f***e",
      account: "fieldmouse",
      salt: "must-not-leak",
      password_hash: "must-not-leak",
      session_token: "must-not-leak",
      installation_id: "must-not-leak",
      profile_revision: 7,
      deck: ["rabbit", "wolf", "invalid card id"],
      card_levels: { rabbit: 4, wolf: 3, reserve_card: 2, "invalid card id": 99 },
      rank: { rank_key: "gold", rank_stars: 8, elo: 1234 },
      rank_mirrors: {
        gold: [{ mirror_id: "mirror-1", player_id: "U-MIRROR", deck: ["rabbit"], card_levels: { rabbit: 4 }, password_hash: "must-not-leak" }],
      },
      resources: { gacha_tickets: 19, card_copies: { rabbit: 7, wolf: 2 } },
    }, {
      user_id: "U-KING",
      username: "A",
      masked_account: "k***g",
      profile_revision: 2,
      deck: ["wolf"],
      card_levels: { wolf: 5 },
      rank: { rank_key: "king", rank_stars: 1, elo: 1400 },
      resources: {},
    }],
  });
  assert.equal(snapshot.availability, "ready");
  assert.equal(snapshot.accounts.length, 2);
  assert.deepEqual(snapshot.card_names, { rabbit: "兔子", wolf: "狼" });
  assert.deepEqual(snapshot.accounts.map((entry) => entry.user_id), ["U-KING", "U-ONE"]);
  assert.equal(snapshot.accounts[0].username, "");
  assert.equal(snapshot.accounts[1].username, "狐狸队长");
  assert.deepEqual(snapshot.accounts[1].deck, ["rabbit", "wolf"]);
  assert.deepEqual(snapshot.accounts[1].card_levels, { rabbit: 4, wolf: 3, reserve_card: 2 });
  assert.equal(snapshot.accounts[1].resources.gacha_tickets, 19);
  assert.equal(snapshot.accounts[1].resources.card_copies.rabbit, 7);
  const serialized = JSON.stringify(snapshot);
  assert.doesNotMatch(serialized, /fieldmouse|must-not-leak|password_hash|installation_id|session_token/);
});

test("resource grant contracts require exact confirmations and an auditable reason", () => {
  const accountSnapshot = {
    availability: "ready",
    accounts: [{ user_id: "U-ONE" }, { user_id: "U-TWO" }],
  };
  const primary = prepareGrantCommand({
    actor: "owner-one",
    now: 1_700_000_000_000,
    accountSnapshot,
    body: {
      target: { kind: "all" },
      grant: { type: "card_copies", card_id: "rabbit", amount: 8 },
      reason: "平衡性补偿",
      confirmation: "SEND TO ALL",
      idempotency_key: "11111111-1111-4111-8111-111111111111",
    },
  });
  assert.equal(primary.scope, "all");
  assert.deepEqual(primary.target_user_ids, ["U-ONE", "U-TWO"]);
  assert.deepEqual(primary.grants, [{ resource: "card_copies", card_id: "rabbit", amount: 8 }]);
  assert.equal(primary.reason, "平衡性补偿");
  assert.throws(
    () => prepareGrantCommand({
      actor: "owner-one",
      accountSnapshot,
      body: {
        target: { kind: "all" },
        grant: { type: "gacha_tickets", amount: 1 },
        reason: "测试",
        confirmation: "yes",
        idempotency_key: "22222222-2222-4222-8222-222222222222",
      },
    }),
    (error) => error.code === "all_confirmation_required",
  );
  assert.throws(
    () => prepareGrantCommand({
      actor: "owner-one",
      accountSnapshot,
      body: {
        scope: "target",
        target_user_id: "U-ONE",
        grants: [{ resource: "gacha_tickets", amount: 3 }],
        reason: "定向补发",
        confirmation: "WRONG",
        idempotency_key: "33333333-3333-4333-8333-333333333333",
      },
    }),
    (error) => error.code === "target_confirmation_required",
  );
  assert.throws(
    () => prepareGrantCommand({
      actor: "owner-one",
      accountSnapshot,
      body: {
        scope: "target",
        target_user_id: "U-ONE",
        grants: [{ resource: "gacha_tickets", amount: 3 }],
        reason: "",
        confirmation: "SEND",
        idempotency_key: "33333333-3333-4333-8333-333333333333",
      },
    }),
    (error) => error.code === "invalid_reason",
  );
  for (const invalidReason of ["abc", "x".repeat(201), `${"x".repeat(200)} `]) {
    assert.throws(
      () => prepareGrantCommand({
        actor: "owner-one",
        accountSnapshot,
        body: {
          scope: "target",
          target_user_id: "U-ONE",
          grants: [{ resource: "gacha_tickets", amount: 3 }],
          reason: invalidReason,
          confirmation: "SEND",
          idempotency_key: "33333333-3333-4333-8333-333333333333",
        },
      }),
      (error) => error.code === "invalid_reason",
    );
  }
});

test("selected resource grants freeze 2 to 500 unique players in one signed command", () => {
  const secret = Buffer.alloc(32, 11);
  const accountSnapshot = {
    availability: "ready",
    accounts: [{ user_id: "U-ONE" }, { user_id: "U-TWO" }, { user_id: "U-THREE" }],
  };
  const body = {
    target: { kind: "selected", user_ids: ["U-TWO", "U-ONE"] },
    grant: { type: "gacha_tickets", amount: 4 },
    reason: "多玩家客服补发",
    idempotency_key: "12121212-1212-4212-8212-121212121212",
  };
  const preview = createGrantPreview({
    body,
    accountSnapshot,
    actor: "owner-one",
    sessionId: "session-selected",
    secret,
    now: 1_700_000_000_000,
  });
  assert.equal(preview.scope, "selected");
  assert.equal(preview.target_count, 2);
  assert.deepEqual(preview.target_user_ids, ["U-ONE", "U-TWO"]);
  const command = commandFromGrantPreview({
    body: { preview_token: preview.preview_token, idempotency_key: body.idempotency_key },
    accountSnapshot,
    actor: "owner-one",
    sessionId: "session-selected",
    secret,
    now: 1_700_000_001_000,
  });
  assert.equal(command.scope, "selected");
  assert.equal(command.target_count, 2);
  assert.deepEqual(command.target_user_ids, ["U-ONE", "U-TWO"]);
  assert.throws(
    () => commandFromGrantPreview({
      body: { preview_token: preview.preview_token, idempotency_key: body.idempotency_key, confirmation: "SEND", password: "must-not-be-accepted" },
      accountSnapshot,
      actor: "owner-one",
      sessionId: "session-selected",
      secret,
      now: 1_700_000_001_000,
    }),
    (error) => error.code === "invalid_preview_request",
  );
  assert.throws(
    () => createGrantPreview({
      body: { ...body, target: { kind: "selected", user_ids: ["U-ONE", "U-ONE"] } },
      accountSnapshot,
      actor: "owner-one",
      sessionId: "session-selected",
      secret,
      now: 1_700_000_000_000,
    }),
    (error) => error.code === "duplicate_target",
  );
  assert.throws(
    () => createGrantPreview({
      body: { ...body, target: { kind: "selected", user_ids: ["U-ONE", "U-TWO", "U-THREE"] } },
      accountSnapshot,
      actor: "owner-one",
      sessionId: "session-selected",
      secret,
      now: 1_700_000_000_000,
    }),
    (error) => error.code === "all_scope_required",
  );
  assert.throws(
    () => commandFromGrantPreview({
      body: { preview_token: preview.preview_token, idempotency_key: body.idempotency_key },
      accountSnapshot: { availability: "ready", accounts: [{ user_id: "U-ONE" }, { user_id: "U-TWO" }] },
      actor: "owner-one",
      sessionId: "session-selected",
      secret,
      now: 1_700_000_001_000,
    }),
    (error) => error.status === 409 && error.code === "all_scope_required",
  );
  const largeAccounts = Array.from({ length: 501 }, (_, index) => ({ user_id: `U-${String(index).padStart(3, "0")}` }));
  assert.throws(
    () => createGrantPreview({
      body: { ...body, target: { kind: "selected", user_ids: largeAccounts.map((entry) => entry.user_id) } },
      accountSnapshot: { availability: "ready", accounts: [...largeAccounts, { user_id: "U-EXTRA" }] },
      actor: "owner-one",
      sessionId: "session-selected",
      secret,
      now: 1_700_000_000_000,
    }),
    (error) => error.code === "selected_target_limit",
  );
});

test("signed resource grant previews reject stale, tampered, cross-session and expired contracts", () => {
  const secret = Buffer.alloc(32, 7);
  const accountSnapshot = {
    availability: "ready",
    accounts: [{ user_id: "U-ONE" }, { user_id: "U-TWO" }],
  };
  const body = {
    target: { kind: "all" },
    grant: { type: "gacha_tickets", amount: 3 },
    reason: "全服测试补发",
    idempotency_key: "77777777-7777-4777-8777-777777777777",
  };
  const preview = createGrantPreview({
    body,
    accountSnapshot,
    actor: "owner-one",
    sessionId: "session-one",
    secret,
    now: 1_700_000_000_000,
  });
  assert.equal(preview.target_count, 2);
  for (const invalidBody of [
    { ...body, unexpected: true },
    { ...body, target: { kind: "all", unexpected: true } },
    { ...body, target: { kind: "all", user_id: "U-ONE" } },
    { ...body, grant: { ...body.grant, unexpected: true } },
    { ...body, grant: { ...body.grant, card_id: "rabbit" } },
  ]) {
    assert.throws(
      () => createGrantPreview({
        body: invalidBody,
        accountSnapshot,
        actor: "owner-one",
        sessionId: "session-one",
        secret,
        now: 1_700_000_000_000,
      }),
      (error) => error.code === "invalid_grant_request",
    );
  }
  const command = commandFromGrantPreview({
    body: {
      preview_token: preview.preview_token,
      idempotency_key: body.idempotency_key,
      confirmation: "SEND TO ALL",
      password: "Owner password one 123",
    },
    accountSnapshot,
    actor: "owner-one",
    sessionId: "session-one",
    secret,
    now: 1_700_000_001_000,
  });
  assert.deepEqual(command.target_user_ids, ["U-ONE", "U-TWO"]);
  const targetBody = {
    target: { kind: "user", user_id: "U-ONE" },
    grant: { type: "gacha_tickets", amount: 1 },
    reason: "指定账号补发",
    idempotency_key: "77777777-7777-4777-8777-777777777778",
  };
  const targetPreview = createGrantPreview({ body: targetBody, accountSnapshot, actor: "owner-one", sessionId: "session-one", secret, now: 1_700_000_000_000 });
  const targetCommand = commandFromGrantPreview({
    body: { preview_token: targetPreview.preview_token, idempotency_key: targetBody.idempotency_key },
    accountSnapshot,
    actor: "owner-one",
    sessionId: "session-one",
    secret,
    now: 1_700_000_001_000,
  });
  assert.deepEqual(targetCommand.target_user_ids, ["U-ONE"]);
  assert.throws(
    () => commandFromGrantPreview({
      body: { preview_token: targetPreview.preview_token, idempotency_key: targetBody.idempotency_key, confirmation: "SEND" },
      accountSnapshot,
      actor: "owner-one",
      sessionId: "session-one",
      secret,
      now: 1_700_000_001_000,
    }),
    (error) => error.code === "invalid_preview_request",
  );
  assert.throws(
    () => commandFromGrantPreview({
      body: { preview_token: preview.preview_token, confirmation: "SEND TO ALL", password: "Owner password one 123", unexpected_field: true },
      accountSnapshot,
      actor: "owner-one",
      sessionId: "session-one",
      secret,
      now: 1_700_000_001_000,
    }),
    (error) => error.code === "invalid_preview_request",
  );
  assert.throws(
    () => commandFromGrantPreview({
      body: { preview_token: preview.preview_token, confirmation: "SEND TO ALL", password: "Owner password one 123" },
      accountSnapshot: { availability: "ready", accounts: [{ user_id: "U-ONE" }, { user_id: "U-THREE" }] },
      actor: "owner-one",
      sessionId: "session-one",
      secret,
      now: 1_700_000_001_000,
    }),
    (error) => error.status === 409 && error.code === "preview_stale",
  );
  const tokenParts = preview.preview_token.split(".");
  const tamperedPayload = `${tokenParts[0]}.${tokenParts[1].slice(0, -2)}aa.${tokenParts[2]}`;
  assert.throws(
    () => commandFromGrantPreview({
      body: { preview_token: tamperedPayload, confirmation: "SEND TO ALL", password: "Owner password one 123" },
      accountSnapshot,
      actor: "owner-one",
      sessionId: "session-one",
      secret,
      now: 1_700_000_001_000,
    }),
    (error) => error.code === "invalid_preview_token",
  );
  assert.throws(
    () => commandFromGrantPreview({
      body: { preview_token: preview.preview_token, confirmation: "SEND TO ALL", password: "Owner password one 123" },
      accountSnapshot,
      actor: "owner-one",
      sessionId: "session-two",
      secret,
      now: 1_700_000_001_000,
    }),
    (error) => error.status === 403 && error.code === "preview_session_mismatch",
  );
  assert.throws(
    () => commandFromGrantPreview({
      body: { preview_token: preview.preview_token, confirmation: "SEND TO ALL", password: "Owner password one 123" },
      accountSnapshot,
      actor: "owner-one",
      sessionId: "session-one",
      secret,
      now: 1_700_000_000_000 + GRANT_PREVIEW_TTL_MS + 1,
    }),
    (error) => error.status === 409 && error.code === "preview_expired",
  );
});

test("enqueue reconciles terminal receipts that appear before or after pending publication", async (context) => {
  const directory = await temporaryDirectory(context);
  const accountSnapshot = { availability: "ready", accounts: [{ user_id: "U-ONE" }] };
  for (const [index, hookName] of ["afterPreflight", "afterPendingWrite"].entries()) {
    const commandRoot = path.join(directory, `commands-${index}`);
    await Promise.all(["pending", "processed", "failed"].map((bucket) => fs.mkdir(path.join(commandRoot, bucket), { recursive: true })));
    const id = index === 0
      ? "99999999-9999-4999-8999-999999999991"
      : "99999999-9999-4999-8999-999999999992";
    const command = prepareGrantCommand({
      actor: "owner-one",
      accountSnapshot,
      body: {
        target: { kind: "user", user_id: "U-ONE" },
        grant: { type: "gacha_tickets", amount: 2 },
        reason: "竞态补发验证",
        confirmation: "SEND",
        idempotency_key: id,
      },
    });
    const terminal = { ...command, status: "processed", processed_at_unix: command.created_at_unix + 1 };
    const result = await enqueueGrantCommand(commandRoot, command, {
      [hookName]: async () => {
        await fs.writeFile(path.join(commandRoot, "processed", `${id}.json`), `${JSON.stringify(terminal)}\n`);
      },
    });
    assert.equal(result.command.status, "processed");
    await assert.rejects(
      () => fs.stat(path.join(commandRoot, "pending", `${id}.json`)),
      (error) => error.code === "ENOENT",
    );
    assert.equal((await fs.readdir(path.join(commandRoot, "processed"))).length, 1);
  }

  const conflictRoot = path.join(directory, "commands-conflict");
  await Promise.all(["pending", "processed", "failed"].map((bucket) => fs.mkdir(path.join(conflictRoot, bucket), { recursive: true })));
  const conflictId = "99999999-9999-4999-8999-999999999993";
  const conflictCommand = prepareGrantCommand({
    actor: "owner-one",
    accountSnapshot,
    body: {
      target: { kind: "user", user_id: "U-ONE" },
      grant: { type: "gacha_tickets", amount: 2 },
      reason: "冲突终态验证",
      confirmation: "SEND",
      idempotency_key: conflictId,
    },
  });
  await assert.rejects(
    () => enqueueGrantCommand(conflictRoot, conflictCommand, {
      afterPendingWrite: async () => {
        await Promise.all(["processed", "failed"].map((bucket) => fs.writeFile(
          path.join(conflictRoot, bucket, `${conflictId}.json`),
          `${JSON.stringify({ ...conflictCommand, status: bucket })}\n`,
        )));
      },
    }),
    (error) => error.code === "terminal_state_conflict",
  );
  await assert.rejects(
    () => fs.stat(path.join(conflictRoot, "pending", `${conflictId}.json`)),
    (error) => error.code === "ENOENT",
  );
  const quarantined = (await fs.readdir(path.join(conflictRoot, "pending"))).filter((name) => name.endsWith(".json.disabled"));
  assert.equal(quarantined.length, 1);
  assert.match(await fs.readFile(path.join(conflictRoot, "pending", quarantined[0]), "utf8"), new RegExp(conflictId));

  const preexistingRoot = path.join(directory, "commands-preexisting");
  await Promise.all(["pending", "processed", "failed"].map((bucket) => fs.mkdir(path.join(preexistingRoot, bucket), { recursive: true })));
  const preexistingId = "99999999-9999-4999-8999-999999999994";
  const preexistingCommand = prepareGrantCommand({
    actor: "owner-one",
    accountSnapshot,
    body: {
      target: { kind: "user", user_id: "U-ONE" },
      grant: { type: "gacha_tickets", amount: 2 },
      reason: "预存终态验证",
      confirmation: "SEND",
      idempotency_key: preexistingId,
    },
  });
  await Promise.all([
    fs.writeFile(path.join(preexistingRoot, "pending", `${preexistingId}.json`), `${JSON.stringify(preexistingCommand)}\n`),
    fs.writeFile(path.join(preexistingRoot, "processed", `${preexistingId}.json`), `${JSON.stringify({ ...preexistingCommand, status: "processed" })}\n`),
  ]);
  const preexistingResult = await enqueueGrantCommand(preexistingRoot, preexistingCommand);
  assert.equal(preexistingResult.idempotent, true);
  assert.equal(preexistingResult.command.status, "processed");
  await assert.rejects(
    () => fs.stat(path.join(preexistingRoot, "pending", `${preexistingId}.json`)),
    (error) => error.code === "ENOENT",
  );
});

test("concurrent enqueue rejects a different payload that reuses the same idempotency key", async (context) => {
  const directory = await temporaryDirectory(context);
  const commandRoot = path.join(directory, "admin_commands");
  const accountSnapshot = { availability: "ready", accounts: [{ user_id: "U-ONE" }] };
  const baseBody = {
    target: { kind: "user", user_id: "U-ONE" },
    reason: "并发补发",
    confirmation: "SEND",
    idempotency_key: "66666666-6666-4666-8666-666666666666",
  };
  const first = prepareGrantCommand({
    actor: "owner-one",
    accountSnapshot,
    body: { ...baseBody, grant: { type: "gacha_tickets", amount: 1 } },
  });
  const second = prepareGrantCommand({
    actor: "owner-one",
    accountSnapshot,
    body: { ...baseBody, grant: { type: "gacha_tickets", amount: 2 } },
  });
  const results = await Promise.allSettled([
    enqueueGrantCommand(commandRoot, first),
    enqueueGrantCommand(commandRoot, second),
  ]);
  assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
  const rejected = results.find((result) => result.status === "rejected");
  assert.equal(rejected?.reason?.code, "idempotency_conflict");
  const pending = await fs.readdir(path.join(commandRoot, "pending"));
  assert.deepEqual(pending.filter((name) => name.endsWith(".json")), [`${baseBody.idempotency_key}.json`]);
});

test("resource grant API submits one-account grants once while broad grants retain reauthentication", async (context) => {
  const directory = await temporaryDirectory(context);
  const snapshotPath = path.join(directory, "dashboard_snapshot.json");
  const accountSnapshotPath = path.join(directory, "admin_accounts_snapshot.json");
  const commandRoot = path.join(directory, "admin_commands");
  await fs.writeFile(snapshotPath, JSON.stringify({ generated_at_unix: 1_700_000_000, overview: {}, animals: [] }));
  await fs.writeFile(accountSnapshotPath, JSON.stringify({
    version: 1,
    generated_at_unix: 1_700_000_001,
    accounts: [
      { user_id: "U-ONE", masked_account: "o***e", deck: ["rabbit"], card_levels: { rabbit: 2 }, rank: {}, resources: {} },
      { user_id: "U-THREE", masked_account: "t***e", deck: ["rabbit", "wolf"], card_levels: { rabbit: 1, wolf: 1 }, rank: {}, resources: {} },
      { user_id: "U-TWO", masked_account: "t***o", deck: ["wolf"], card_levels: { wolf: 3 }, rank: {}, resources: {} },
    ],
  }));
  const stateDirectory = path.join(directory, "state");
  const state = await DashboardState.open(stateDirectory);
  await state.initializeOwner("owner-one", "Owner password one 123");
  await state.createUser({ username: "analyst-one", password: "Analyst password one 123", role: "analyst" });
  const app = await createDashboardServer({
    host: "127.0.0.1",
    port: 0,
    snapshotPath,
    accountSnapshotPath,
    commandRoot,
    stateDirectory,
    state,
  });
  context.after(() => app.close());
  const address = await app.listen();
  const baseUrl = `http://127.0.0.1:${address.port}`;

  const ownerLogin = await jsonRequest(baseUrl, "/api/auth/login", {
    method: "POST",
    headers: { Origin: baseUrl, "Content-Type": "application/json" },
    body: JSON.stringify({ username: "owner-one", password: "Owner password one 123" }),
  });
  const ownerCookie = cookiePair(ownerLogin.response);
  const ownerCsrf = ownerLogin.body.csrf_token;
  const analystLogin = await jsonRequest(baseUrl, "/api/auth/login", {
    method: "POST",
    headers: { Origin: baseUrl, "Content-Type": "application/json" },
    body: JSON.stringify({ username: "analyst-one", password: "Analyst password one 123" }),
  });
  const analystCookie = cookiePair(analystLogin.response);
  const analystCsrf = analystLogin.body.csrf_token;

  const accounts = await jsonRequest(baseUrl, "/api/accounts", { headers: { Cookie: analystCookie } });
  assert.equal(accounts.response.status, 200);
  assert.equal(accounts.body.availability, "ready");
  assert.deepEqual(accounts.body.accounts.map((entry) => entry.user_id), ["U-ONE", "U-THREE", "U-TWO"]);

  const requestBody = {
    target: { kind: "user", user_id: "U-ONE" },
    grant: { type: "gacha_tickets", amount: 5 },
    reason: "客服补发",
    idempotency_key: "44444444-4444-4444-8444-444444444444",
  };
  const analystAttempt = await jsonRequest(baseUrl, "/api/resource-grants/preview", {
    method: "POST",
    headers: { Cookie: analystCookie, Origin: baseUrl, "X-CSRF-Token": analystCsrf, "Content-Type": "application/json" },
    body: JSON.stringify(requestBody),
  });
  assert.equal(analystAttempt.response.status, 403);
  assert.equal(analystAttempt.body.error, "owner_required");

  const preview = await jsonRequest(baseUrl, "/api/resource-grants/preview", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify(requestBody),
  });
  assert.equal(preview.response.status, 201, JSON.stringify(preview.body));
  assert.equal(preview.body.preview.target_count, 1);
  assert.equal(preview.body.preview.idempotency_key, requestBody.idempotency_key);
  const submissionBody = {
    preview_token: preview.body.preview.preview_token,
    idempotency_key: requestBody.idempotency_key,
  };

  const redundantSecondConfirmation = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({ ...submissionBody, confirmation: "SEND", password: "Owner password one 123" }),
  });
  assert.equal(redundantSecondConfirmation.response.status, 400);
  assert.equal(redundantSecondConfirmation.body.error, "invalid_preview_request");
  await assert.rejects(() => fs.stat(path.join(commandRoot, "pending", `${requestBody.idempotency_key}.json`)), (error) => error.code === "ENOENT");

  const created = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify(submissionBody),
  });
  assert.equal(created.response.status, 202, JSON.stringify(created.body));
  assert.equal(created.body.command.command_id, requestBody.idempotency_key);
  assert.equal(created.body.command.reason, "客服补发");
  assert.deepEqual(created.body.command.target_user_ids, ["U-ONE"]);
  const queuedRaw = await fs.readFile(path.join(commandRoot, "pending", `${requestBody.idempotency_key}.json`), "utf8");
  assert.match(queuedRaw, /客服补发/);
  assert.doesNotMatch(queuedRaw, /Owner password one 123|owner_password|"password"/);
  await fs.mkdir(path.join(commandRoot, "processed"), { recursive: true });
  await fs.writeFile(
    path.join(commandRoot, "processed", `${requestBody.idempotency_key}.json`),
    `${JSON.stringify({ ...JSON.parse(queuedRaw), status: "processed", processed_at_unix: 1_700_000_002 })}\n`,
  );

  const retry = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify(submissionBody),
  });
  assert.equal(retry.response.status, 200);
  assert.equal(retry.body.idempotent, true);
  assert.equal(retry.body.command.status, "processed");
  assert.equal((await fs.readdir(path.join(commandRoot, "pending"))).filter((name) => name.endsWith(".json")).length, 0);

  const amountConflictPreview = await jsonRequest(baseUrl, "/api/resource-grants/preview", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({ ...requestBody, grant: { type: "gacha_tickets", amount: 6 } }),
  });
  assert.equal(amountConflictPreview.response.status, 201);
  const amountConflict = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({
      ...submissionBody,
      preview_token: amountConflictPreview.body.preview.preview_token,
    }),
  });
  assert.equal(amountConflict.response.status, 409);
  assert.equal(amountConflict.body.error, "idempotency_conflict");
  const targetConflictPreview = await jsonRequest(baseUrl, "/api/resource-grants/preview", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({ ...requestBody, target: { kind: "user", user_id: "U-TWO" } }),
  });
  assert.equal(targetConflictPreview.response.status, 201);
  const targetConflict = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({
      ...submissionBody,
      preview_token: targetConflictPreview.body.preview.preview_token,
    }),
  });
  assert.equal(targetConflict.response.status, 409);
  assert.equal(targetConflict.body.error, "idempotency_conflict");
  assert.equal((await fs.readdir(path.join(commandRoot, "pending"))).filter((name) => name.endsWith(".json")).length, 0);

  const selectedBody = {
    target: { kind: "selected", user_ids: ["U-TWO", "U-ONE"] },
    grant: { type: "gacha_tickets", amount: 7 },
    reason: "多玩家客服补发",
    idempotency_key: "56565656-5656-4656-8656-565656565656",
  };
  const selectedPreview = await jsonRequest(baseUrl, "/api/resource-grants/preview", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify(selectedBody),
  });
  assert.equal(selectedPreview.response.status, 201, JSON.stringify(selectedPreview.body));
  assert.equal(selectedPreview.body.preview.scope, "selected");
  assert.equal(selectedPreview.body.preview.target_count, 2);
  assert.deepEqual(selectedPreview.body.preview.target_user_ids, ["U-ONE", "U-TWO"]);
  const selectedCreated = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({
      preview_token: selectedPreview.body.preview.preview_token,
      idempotency_key: selectedBody.idempotency_key,
    }),
  });
  assert.equal(selectedCreated.response.status, 202, JSON.stringify(selectedCreated.body));
  assert.equal(selectedCreated.body.command.scope, "selected");
  assert.deepEqual(selectedCreated.body.command.target_user_ids, ["U-ONE", "U-TWO"]);
  assert.equal(selectedCreated.body.command.target_count, 2);
  assert.equal((await fs.readdir(path.join(commandRoot, "pending"))).filter((name) => name.endsWith(".json")).length, 1);

  const allBody = {
    target: { kind: "all" },
    grant: { type: "card_copies", card_id: "rabbit", amount: 2 },
    reason: "全服活动补偿",
    idempotency_key: "55555555-5555-4555-8555-555555555555",
  };
  const allPreview = await jsonRequest(baseUrl, "/api/resource-grants/preview", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify(allBody),
  });
  assert.equal(allPreview.response.status, 201);
  assert.equal(allPreview.body.preview.target_count, 3);
  const allWrongConfirmation = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({
      preview_token: allPreview.body.preview.preview_token,
      idempotency_key: allBody.idempotency_key,
      confirmation: "SEND",
      password: "Owner password one 123",
    }),
  });
  assert.equal(allWrongConfirmation.response.status, 400);
  assert.equal(allWrongConfirmation.body.error, "all_confirmation_required");
  const allWrongPassword = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({
      preview_token: allPreview.body.preview.preview_token,
      idempotency_key: allBody.idempotency_key,
      confirmation: "SEND TO ALL",
      password: "wrong owner password",
    }),
  });
  assert.equal(allWrongPassword.response.status, 401);
  assert.equal(allWrongPassword.body.error, "owner_reauthentication_failed");
  const allCreated = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({
      preview_token: allPreview.body.preview.preview_token,
      idempotency_key: allBody.idempotency_key,
      confirmation: "SEND TO ALL",
      password: "Owner password one 123",
    }),
  });
  assert.equal(allCreated.response.status, 202);
  assert.deepEqual(allCreated.body.command.target_user_ids, ["U-ONE", "U-THREE", "U-TWO"]);

  const analystList = await jsonRequest(baseUrl, "/api/resource-grants", { headers: { Cookie: analystCookie } });
  assert.equal(analystList.response.status, 403);
  const ownerList = await jsonRequest(baseUrl, "/api/resource-grants", { headers: { Cookie: ownerCookie } });
  assert.equal(ownerList.response.status, 200);
  assert.equal(ownerList.body.command, null);
  assert.equal(ownerList.body.entries.length, 3);

  const auditFailureBody = {
    target: { kind: "user", user_id: "U-TWO" },
    grant: { type: "gacha_tickets", amount: 1 },
    reason: "审计失败回归",
    idempotency_key: "88888888-8888-4888-8888-888888888888",
  };
  const auditFailurePreview = await jsonRequest(baseUrl, "/api/resource-grants/preview", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify(auditFailureBody),
  });
  assert.equal(auditFailurePreview.response.status, 201);
  const appendAudit = state.appendAudit.bind(state);
  state.appendAudit = async () => {
    throw new Error("simulated grant audit failure");
  };
  const auditFailure = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({
      preview_token: auditFailurePreview.body.preview.preview_token,
      idempotency_key: auditFailureBody.idempotency_key,
    }),
  });
  state.appendAudit = appendAudit;
  assert.equal(auditFailure.response.status, 500);
  await assert.rejects(
    () => fs.stat(path.join(commandRoot, "pending", `${auditFailureBody.idempotency_key}.json`)),
    (error) => error.code === "ENOENT",
  );

  const auditText = JSON.stringify(await state.readAudit(200));
  assert.match(auditText, /grant_enqueue_authorized/);
  assert.match(auditText, /客服补发/);
  assert.match(auditText, /selected:2/);
  assert.doesNotMatch(auditText, /Owner password one 123/);
  assert.doesNotMatch(auditText, /SEND|preview_token/);
  assert.doesNotMatch(auditText, new RegExp(preview.body.preview.preview_token.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
});

test("resource page contract exposes player data and persistent multi-selection controls", async () => {
  const appSource = await fs.readFile(path.join(PROJECT_ROOT, "tools", "admin_dashboard", "public", "app.js"), "utf8");
  const styleSource = await fs.readFile(path.join(PROJECT_ROOT, "tools", "admin_dashboard", "public", "styles.css"), "utf8");
  for (const label of ["玩家名称", "完整玩家 ID", "段位 / Elo", "抽卡券", "阵容卡数", "发放资源", "系统临时名称"]) {
    assert.match(appSource, new RegExp(label.replace("/", "\\/")));
  }
  assert.match(appSource, /selectedGrantUserIds: new Set\(\)/);
  assert.match(appSource, /全选当前结果/);
  assert.match(appSource, /清空选择/);
  assert.match(appSource, /\{ kind: "selected", user_ids: selectedIds \}/);
  assert.match(appSource, /accountDisplayName\(account\)/);
  assert.match(appSource, /temporaryPlayerName/);
  assert.match(appSource, /disabled: selectionInvalid/);
  assert.doesNotMatch(appSource, /name: "target_kind"/);
  assert.match(styleSource, /\.grant-player-table/);
  assert.match(styleSource, /\.grant-workspace/);
  assert.match(styleSource, /grid-template-areas: "players operation"/);
  assert.match(styleSource, /\.grant-operation-form/);
  assert.match(styleSource, /\.grant-primary-fields/);
  assert.match(styleSource, /tbody tr\.is-selected/);
  assert.match(styleSource, /\.grant-checkbox input\[type="checkbox"\]/);
});

test("audit outbox replays once after restart even when JSONL already contains the event id", async (context) => {
  const directory = await temporaryDirectory(context);
  const state = await DashboardState.open(directory);
  await state.initializeOwner("owner-one", "Owner password one 123");
  state._flushAuditOutboxUnsafe = async () => {
    throw new Error("simulated crash after atomic state save");
  };
  const created = await state.createUserAudited({
    username: "analyst-one",
    password: "Analyst password one 123",
    role: "analyst",
  }, { actor: "owner-one", ip: "127.0.0.1" });
  assert.equal(created.audit_pending, true);
  const persisted = JSON.parse(await fs.readFile(state.statePath, "utf8"));
  const outboxEntry = persisted.audit_outbox[created.audit_id];
  assert.equal(outboxEntry.event, "admin_created");
  await fs.appendFile(state.auditPath, `${JSON.stringify(outboxEntry)}\n`, "utf8");

  const reopened = await DashboardState.open(directory);
  assert.deepEqual(reopened.auditStatus(), { pending: 0, integrity_degraded: false, degraded: false });
  assert.equal((await reopened.listUsers()).some((user) => user.username === "analyst-one"), true);
  const lines = (await fs.readFile(reopened.auditPath, "utf8")).trim().split("\n").map((line) => JSON.parse(line));
  assert.equal(lines.filter((entry) => entry.id === created.audit_id).length, 1);
});

test("owner initialization persists a complete non-secret audit outbox record before JSONL projection", async (context) => {
  const directory = await temporaryDirectory(context);
  const state = await DashboardState.open(directory);
  state._flushAuditOutboxUnsafe = async () => {
    throw new Error("simulated owner audit projection failure");
  };
  const initialized = await state.initializeOwnerAudited("owner-one", "Owner password one 123", { source: "local_cli" });
  assert.equal(initialized.audit_pending, true);
  assert.equal((await state.listUsers())[0].role, "owner");
  const persisted = JSON.parse(await fs.readFile(state.statePath, "utf8"));
  const outboxEntry = persisted.audit_outbox[initialized.audit_id];
  assert.equal(outboxEntry.event, "owner_initialized");
  assert.match(outboxEntry.detail, /before=absent;after=role:owner,status:active;source=local_cli/);
  assert.doesNotMatch(JSON.stringify(outboxEntry), /Owner password one 123/);

  const reopened = await DashboardState.open(directory);
  assert.equal((await reopened.listUsers())[0].username, "owner-one");
  assert.deepEqual(reopened.auditStatus(), { pending: 0, integrity_degraded: false, degraded: false });
  const ownerEvents = (await reopened.readAudit(20)).filter((entry) => entry.event === "owner_initialized");
  assert.equal(ownerEvents.length, 1);
  assert.equal(ownerEvents[0].id, initialized.audit_id);
});

test("audit flush preserves a damaged trailing fragment and appends new events as independently valid lines", async (context) => {
  const directory = await temporaryDirectory(context);
  const state = await DashboardState.open(directory);
  await state.initializeOwner("owner-one", "Owner password one 123");
  const flushAuditOutbox = state._flushAuditOutboxUnsafe.bind(state);
  state._flushAuditOutboxUnsafe = async () => {
    throw new Error("simulated pending audit projection");
  };
  const created = await state.createUserAudited({
    username: "analyst-one",
    password: "Analyst password one 123",
    role: "analyst",
  }, { actor: "owner-one", ip: "127.0.0.1" });
  assert.equal(created.audit_pending, true);
  const damagedTail = "{\"id\":\"damaged-tail\"";
  await fs.appendFile(state.auditPath, damagedTail, "utf8");
  state._flushAuditOutboxUnsafe = flushAuditOutbox;
  await state.flushAuditOutbox();

  assert.deepEqual(state.auditStatus(), { pending: 0, integrity_degraded: true, degraded: true });
  const raw = await fs.readFile(state.auditPath, "utf8");
  assert.match(raw, new RegExp(`${damagedTail.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\n`));
  const validLines = raw.split("\n").flatMap((line) => {
    try {
      return line ? [JSON.parse(line)] : [];
    } catch {
      return [];
    }
  });
  assert.equal(validLines.filter((entry) => entry.id === created.audit_id).length, 1);
  const reopened = await DashboardState.open(directory);
  assert.equal(reopened.auditStatus().integrity_degraded, true);
  assert.equal((await reopened.readAudit(50)).filter((entry) => entry.id === created.audit_id).length, 1);
});

test("audit outbox is retained when post-append readback cannot confirm the event id", async (context) => {
  const directory = await temporaryDirectory(context);
  const state = await DashboardState.open(directory);
  await state.initializeOwner("owner-one", "Owner password one 123");
  const inspectAuditFile = state._inspectAuditFile.bind(state);
  let inspections = 0;
  state._inspectAuditFile = async () => {
    const inspection = await inspectAuditFile();
    inspections += 1;
    return inspections >= 2 ? { ...inspection, idCounts: new Map() } : inspection;
  };
  const created = await state.createUserAudited({
    username: "analyst-one",
    password: "Analyst password one 123",
    role: "analyst",
  }, { actor: "owner-one", ip: "127.0.0.1" });
  assert.equal(created.audit_pending, true);
  assert.equal(state.auditStatus().pending, 1);
  const persisted = JSON.parse(await fs.readFile(state.statePath, "utf8"));
  assert.equal(Object.hasOwn(persisted.audit_outbox, created.audit_id), true);

  state._inspectAuditFile = inspectAuditFile;
  await state.flushAuditOutbox();
  assert.equal(state.auditStatus().pending, 0);
  const auditLines = (await fs.readFile(state.auditPath, "utf8")).trim().split("\n").map((line) => JSON.parse(line));
  assert.equal(auditLines.filter((entry) => entry.id === created.audit_id).length, 1);
});

test("dangerous administrator mutations retain complete atomic audit outbox records when JSONL flush fails", async (context) => {
  const directory = await temporaryDirectory(context);
  const snapshotPath = path.join(directory, "dashboard_snapshot.json");
  await fs.writeFile(snapshotPath, JSON.stringify({ generated_at_unix: 1_700_000_000, overview: {}, animals: [] }));
  const stateDirectory = path.join(directory, "state");
  const state = await DashboardState.open(stateDirectory);
  await state.initializeOwner("owner-one", "Owner password one 123");
  await state.createUser({ username: "analyst-one", password: "Analyst password one 123", role: "analyst" });
  const app = await createDashboardServer({ host: "127.0.0.1", port: 0, snapshotPath, stateDirectory, state });
  context.after(() => app.close());
  const address = await app.listen();
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const ownerLogin = await jsonRequest(baseUrl, "/api/auth/login", {
    method: "POST",
    headers: { Origin: baseUrl, "Content-Type": "application/json" },
    body: JSON.stringify({ username: "owner-one", password: "Owner password one 123" }),
  });
  const analystLogin = await jsonRequest(baseUrl, "/api/auth/login", {
    method: "POST",
    headers: { Origin: baseUrl, "Content-Type": "application/json" },
    body: JSON.stringify({ username: "analyst-one", password: "Analyst password one 123" }),
  });
  const ownerCookie = cookiePair(ownerLogin.response);
  const ownerCsrf = ownerLogin.body.csrf_token;
  const analystCookie = cookiePair(analystLogin.response);
  const flushAuditOutbox = state._flushAuditOutboxUnsafe.bind(state);
  state._flushAuditOutboxUnsafe = async () => {
    throw new Error("simulated JSONL flush failure");
  };

  const create = await jsonRequest(baseUrl, "/api/admins", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({ username: "analyst-two", password: "Analyst password two 123", role: "analyst" }),
  });
  assert.equal(create.response.status, 201);
  assert.equal(create.body.audit_pending, true);
  assert.equal((await state.listUsers()).some((user) => user.username === "analyst-two"), true);

  const update = await jsonRequest(baseUrl, "/api/admins/analyst-one", {
    method: "PATCH",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({ status: "disabled" }),
  });
  assert.equal(update.response.status, 200);
  assert.equal(update.body.audit_pending, true);
  assert.equal((await state.listUsers()).find((user) => user.username === "analyst-one")?.status, "disabled");

  const analystTwoLogin = await jsonRequest(baseUrl, "/api/auth/login", {
    method: "POST",
    headers: { Origin: baseUrl, "Content-Type": "application/json" },
    body: JSON.stringify({ username: "analyst-two", password: "Analyst password two 123" }),
  });
  const analystTwoCookie = cookiePair(analystTwoLogin.response);

  const revoke = await jsonRequest(baseUrl, "/api/admins/analyst-two/revoke-sessions", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({}),
  });
  assert.equal(revoke.response.status, 200);
  assert.equal(revoke.body.audit_pending, true);
  const revokedAnalyst = await jsonRequest(baseUrl, "/api/dashboard", { headers: { Cookie: analystTwoCookie } });
  assert.equal(revokedAnalyst.response.status, 401);
  const disabledAnalyst = await jsonRequest(baseUrl, "/api/dashboard", { headers: { Cookie: analystCookie } });
  assert.equal(disabledAnalyst.response.status, 401);

  const persisted = JSON.parse(await fs.readFile(state.statePath, "utf8"));
  const outboxEntries = Object.values(persisted.audit_outbox);
  assert.deepEqual(outboxEntries.map((entry) => entry.event).sort(), ["admin_created", "admin_updated", "login_success", "sessions_revoked"].sort());
  const serializedOutbox = JSON.stringify(outboxEntries);
  assert.match(serializedOutbox, /before=absent;after=role:analyst,status:active/);
  assert.match(serializedOutbox, /before=role:analyst,status:active;after=role:analyst,status:disabled/);
  assert.match(serializedOutbox, /sessions_revoked=1/);
  assert.doesNotMatch(serializedOutbox, /Analyst password|Owner password/);
  assert.equal(state.auditStatus().degraded, true);
  const visiblePendingAudit = (await state.readAudit(200)).filter((entry) => entry.pending);
  assert.equal(visiblePendingAudit.length, 4);
  assert.equal(visiblePendingAudit.every((entry) => entry.id), true);
  assert.equal(visiblePendingAudit.filter((entry) => entry.event !== "login_success").every((entry) => entry.detail), true);

  const readiness = await jsonRequest(baseUrl, "/api/readiness");
  assert.equal(readiness.response.status, 503);
  assert.equal(readiness.body.audit_outbox.ready, false);

  state._flushAuditOutboxUnsafe = flushAuditOutbox;
  await state.flushAuditOutbox();
  assert.deepEqual(state.auditStatus(), { pending: 0, integrity_degraded: false, degraded: false });
  const completed = (await state.readAudit(200)).filter((entry) => ["admin_created", "admin_updated", "sessions_revoked"].includes(entry.event));
  assert.equal(completed.length, 3);
  assert.equal(new Set(completed.map((entry) => entry.id)).size, 3);
});

test("health reports liveness separately from data readiness without claiming an executor heartbeat", async (context) => {
  const directory = await temporaryDirectory(context);
  const snapshotPath = path.join(directory, "dashboard_snapshot.json");
  const accountSnapshotPath = path.join(directory, "admin_accounts_snapshot.json");
  const commandRoot = path.join(directory, "admin_commands");
  await fs.writeFile(snapshotPath, JSON.stringify({ generated_at_unix: 1_700_000_000, overview: {}, animals: [] }));
  const app = await createDashboardServer({
    host: "127.0.0.1",
    port: 0,
    snapshotPath,
    accountSnapshotPath,
    commandRoot,
    stateDirectory: path.join(directory, "state"),
  });
  context.after(() => app.close());
  const address = await app.listen();
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const health = await jsonRequest(baseUrl, "/api/health");
  assert.equal(health.response.status, 200);
  assert.equal(health.body.ok, true);
  assert.equal(health.body.live, true);
  assert.equal(health.body.ready, false);
  assert.equal(health.body.data.fresh, false);
  assert.equal(health.body.command_storage.ready, false);
  assert.equal(health.body.active_owner.ready, false);
  assert.deepEqual(health.body.executor, { observed: false, status: "not_observed" });
  const readiness = await jsonRequest(baseUrl, "/api/readiness");
  assert.equal(readiness.response.status, 503);
  assert.equal(readiness.body.ok, false);
  assert.equal(readiness.body.data.available, false);

  const nowUnix = Math.floor(Date.now() / 1000);
  await fs.writeFile(snapshotPath, JSON.stringify({ generated_at_unix: nowUnix, overview: {}, animals: [] }));
  await fs.writeFile(accountSnapshotPath, JSON.stringify({ generated_at_unix: nowUnix, accounts: [{ user_id: "U-READY" }] }));
  await Promise.all(["pending", "processed", "failed"].map((bucket) => fs.mkdir(path.join(commandRoot, bucket), { recursive: true })));
  await app.state.initializeOwner("owner-one", "Owner password one 123");
  const executorBlocked = await jsonRequest(baseUrl, "/api/readiness");
  assert.equal(executorBlocked.response.status, 503);
  assert.equal(executorBlocked.body.data.available, true);
  assert.equal(executorBlocked.body.data.fresh, true);
  assert.equal(executorBlocked.body.command_storage.ready, true);
  assert.equal(executorBlocked.body.active_owner.ready, true);
  assert.equal(executorBlocked.body.audit_outbox.ready, true);
  assert.deepEqual(executorBlocked.body.executor, { observed: false, status: "not_observed" });
  assert.equal(executorBlocked.body.ready, false);
});

test("server configuration rejects a public cleartext binding", async (context) => {
  const directory = await temporaryDirectory(context);
  const snapshotPath = path.join(directory, "dashboard_snapshot.json");
  await fs.writeFile(snapshotPath, "{}");
  assert.throws(
    () => buildRuntimeConfig({ host: "0.0.0.0", snapshotPath, stateDirectory: path.join(directory, "state") }),
    /requires TLS/,
  );
});

test("server configuration refuses a player account file as its data source", () => {
  assert.throws(
    () => buildRuntimeConfig({ host: "127.0.0.1", snapshotPath: "C:/server/player_accounts.json", stateDirectory: "C:/dashboard-state" }),
    /dashboard_snapshot\.json/,
  );
});
