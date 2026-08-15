import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { sanitizeAccountSnapshot } from "../../tools/admin_dashboard/lib/account_snapshot.mjs";
import { hashPassword, LoginRateLimiter, verifyPassword } from "../../tools/admin_dashboard/lib/auth.mjs";
import { enqueueGrantCommand, prepareGrantCommand } from "../../tools/admin_dashboard/lib/resource_grants.mjs";
import { sanitizeDashboardSnapshot } from "../../tools/admin_dashboard/lib/snapshot.mjs";
import { DashboardState, SESSION_IDLE_MS } from "../../tools/admin_dashboard/lib/state_store.mjs";
import { buildRuntimeConfig, createDashboardServer } from "../../tools/admin_dashboard/server.mjs";

async function temporaryDirectory(testContext) {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "jungle-dashboard-test-"));
  testContext.after(async () => fs.rm(directory, { recursive: true, force: true }));
  return directory;
}

function cookiePair(response) {
  return String(response.headers.get("set-cookie") ?? "").split(";")[0];
}

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
    overview: { matches: 9, players: 2, active_24h: 1, season: "S1", source: "server_recorded_host_authority_full_human_online", account: "must-not-leak" },
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
    recent_matches: [{
      match_id: "server-match-1",
      map_id: "1v1_crossroads",
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
  assert.equal(snapshot.overview.source, "server_recorded_host_authority_full_human_online");
  assert.equal(snapshot.recent_matches.length, 1);
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
    accounts: [{
      user_id: "U-ONE",
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
    }],
  });
  assert.equal(snapshot.availability, "ready");
  assert.equal(snapshot.accounts.length, 1);
  assert.deepEqual(snapshot.accounts[0].deck, ["rabbit", "wolf"]);
  assert.deepEqual(snapshot.accounts[0].card_levels, { rabbit: 4, wolf: 3, reserve_card: 2 });
  assert.equal(snapshot.accounts[0].resources.gacha_tickets, 19);
  assert.equal(snapshot.accounts[0].resources.card_copies.rabbit, 7);
  const serialized = JSON.stringify(snapshot);
  assert.doesNotMatch(serialized, /fieldmouse|must-not-leak|password_hash|installation_id|session_token/);
});

test("primary resource grant contract freezes explicit targets and retains legacy compatibility", () => {
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
  const legacy = prepareGrantCommand({
    actor: "owner-one",
    accountSnapshot,
    body: {
      scope: "target",
      target_user_id: "U-ONE",
      grants: [{ resource: "gacha_tickets", amount: 3 }],
      idempotency_key: "33333333-3333-4333-8333-333333333333",
    },
  });
  assert.equal(legacy.reason, "legacy_request");
  assert.deepEqual(legacy.target_user_ids, ["U-ONE"]);
});

test("concurrent enqueue rejects a different payload that reuses the same idempotency key", async (context) => {
  const directory = await temporaryDirectory(context);
  const commandRoot = path.join(directory, "admin_commands");
  const accountSnapshot = { availability: "ready", accounts: [{ user_id: "U-ONE" }] };
  const baseBody = {
    target: { kind: "user", user_id: "U-ONE" },
    reason: "并发补发",
    confirmation: "CONFIRM",
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

test("resource grant API requires owner reauthentication and atomically enqueues primary commands", async (context) => {
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
  assert.deepEqual(accounts.body.accounts.map((entry) => entry.user_id), ["U-ONE", "U-TWO"]);

  const requestBody = {
    target: { kind: "user", user_id: "U-ONE" },
    grant: { type: "gacha_tickets", amount: 5 },
    reason: "客服补发",
    confirmation: "CONFIRM",
    password: "Owner password one 123",
    idempotency_key: "44444444-4444-4444-8444-444444444444",
  };
  const analystAttempt = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: analystCookie, Origin: baseUrl, "X-CSRF-Token": analystCsrf, "Content-Type": "application/json" },
    body: JSON.stringify(requestBody),
  });
  assert.equal(analystAttempt.response.status, 403);
  assert.equal(analystAttempt.body.error, "owner_required");

  const wrongPassword = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({ ...requestBody, password: "wrong owner password" }),
  });
  assert.equal(wrongPassword.response.status, 401);
  assert.equal(wrongPassword.body.error, "owner_reauthentication_failed");
  await assert.rejects(() => fs.stat(path.join(commandRoot, "pending", `${requestBody.idempotency_key}.json`)), (error) => error.code === "ENOENT");

  const created = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify(requestBody),
  });
  assert.equal(created.response.status, 202, JSON.stringify(created.body));
  assert.equal(created.body.command.command_id, requestBody.idempotency_key);
  assert.equal(created.body.command.reason, "客服补发");
  assert.deepEqual(created.body.command.target_user_ids, ["U-ONE"]);
  const queuedRaw = await fs.readFile(path.join(commandRoot, "pending", `${requestBody.idempotency_key}.json`), "utf8");
  assert.match(queuedRaw, /客服补发/);
  assert.doesNotMatch(queuedRaw, /Owner password one 123|owner_password|"password"/);

  const retry = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify(requestBody),
  });
  assert.equal(retry.response.status, 200);
  assert.equal(retry.body.idempotent, true);
  assert.equal((await fs.readdir(path.join(commandRoot, "pending"))).filter((name) => name.endsWith(".json")).length, 1);

  const amountConflict = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({ ...requestBody, grant: { type: "gacha_tickets", amount: 6 } }),
  });
  assert.equal(amountConflict.response.status, 409);
  assert.equal(amountConflict.body.error, "idempotency_conflict");
  const targetConflict = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify({ ...requestBody, target: { kind: "user", user_id: "U-TWO" } }),
  });
  assert.equal(targetConflict.response.status, 409);
  assert.equal(targetConflict.body.error, "idempotency_conflict");
  assert.equal((await fs.readdir(path.join(commandRoot, "pending"))).filter((name) => name.endsWith(".json")).length, 1);

  const allBody = {
    target: { kind: "all" },
    grant: { type: "card_copies", card_id: "rabbit", amount: 2 },
    reason: "全服活动补偿",
    confirmation: "SEND TO ALL",
    password: "Owner password one 123",
    idempotency_key: "55555555-5555-4555-8555-555555555555",
  };
  const allCreated = await jsonRequest(baseUrl, "/api/resource-grants", {
    method: "POST",
    headers: { Cookie: ownerCookie, Origin: baseUrl, "X-CSRF-Token": ownerCsrf, "Content-Type": "application/json" },
    body: JSON.stringify(allBody),
  });
  assert.equal(allCreated.response.status, 202);
  assert.deepEqual(allCreated.body.command.target_user_ids, ["U-ONE", "U-TWO"]);

  const analystList = await jsonRequest(baseUrl, "/api/resource-grants", { headers: { Cookie: analystCookie } });
  assert.equal(analystList.response.status, 403);
  const ownerList = await jsonRequest(baseUrl, "/api/resource-grants", { headers: { Cookie: ownerCookie } });
  assert.equal(ownerList.response.status, 200);
  assert.equal(ownerList.body.command, null);
  assert.equal(ownerList.body.entries.length, 2);

  const auditText = JSON.stringify(await state.readAudit(200));
  assert.match(auditText, /grant_enqueue_authorized/);
  assert.match(auditText, /客服补发/);
  assert.doesNotMatch(auditText, /Owner password one 123/);
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
