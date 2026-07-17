import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { hashPassword, LoginRateLimiter, verifyPassword } from "../../tools/admin_dashboard/lib/auth.mjs";
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
    animals: [{ card_id: "rabbit", name: "兔子", games: 9, wins: 6, losses: 3, pick_rate: 0.5, private_note: "must-not-leak" }],
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
  assert.match(await landing.text(), /赛事数据中心/);

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
