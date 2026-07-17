const app = document.querySelector("#app");

const state = {
  session: null,
  csrfToken: "",
  dashboard: null,
  users: [],
  audit: [],
};

function element(tag, options = {}) {
  const node = document.createElement(tag);
  if (options.className) node.className = options.className;
  if (options.text !== undefined) node.textContent = options.text;
  if (options.type) node.type = options.type;
  if (options.name) node.name = options.name;
  if (options.value !== undefined) node.value = options.value;
  if (options.placeholder) node.placeholder = options.placeholder;
  if (options.required) node.required = true;
  if (options.autocomplete) node.autocomplete = options.autocomplete;
  if (options.disabled) node.disabled = true;
  return node;
}

function clear(node) {
  node.replaceChildren();
  return node;
}

function formatPercent(value) {
  if (!Number.isFinite(Number(value))) return "—";
  return `${Math.round(Number(value || 0) * 1000) / 10}%`;
}

function formatDate(unixSeconds) {
  const value = Number(unixSeconds || 0);
  if (!value) return "尚无数据";
  return new Intl.DateTimeFormat("zh-CN", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value * 1000));
}

function compactUserId(value) {
  const userId = String(value || "");
  if (userId.length <= 14) return userId;
  return `${userId.slice(0, 7)}…${userId.slice(-5)}`;
}

function analyticsSourceLabel(value) {
  const labels = {
    server_recorded_host_authority_full_human_online: "服务器记录的房主权威对局，仅统计满额真人在线房间。",
  };
  return labels[value] || "服务器脱敏统计快照。";
}

function outcomeLabel(value) {
  const labels = { win: "胜", loss: "负", draw: "平" };
  return labels[value] || "—";
}

function apiErrorMessage(code) {
  const messages = {
    invalid_credentials: "用户名或密码错误。",
    login_rate_limited: "尝试过于频繁，请稍后再试。",
    authentication_required: "登录已过期，请重新登录。",
    origin_rejected: "请求来源校验失败，请从本后台页面重新操作。",
    csrf_rejected: "安全校验已失效，请刷新页面后再试。",
    owner_required: "此操作仅限 Owner。",
    user_exists: "该授权账号已存在。",
    last_owner_protected: "至少必须保留一位启用的 Owner。",
  };
  return messages[code] || "操作未完成，请检查输入后重试。";
}

async function request(url, options = {}) {
  const headers = new Headers(options.headers || {});
  if (options.body !== undefined) headers.set("Content-Type", "application/json");
  if (options.mutation && state.csrfToken) headers.set("X-CSRF-Token", state.csrfToken);
  const response = await fetch(url, {
    ...options,
    headers,
    credentials: "same-origin",
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(payload.error || "request_failed");
    error.code = payload.error || "request_failed";
    error.status = response.status;
    throw error;
  }
  return payload;
}

function showLogin(message = "") {
  clear(app);
  const shell = element("section", { className: "login-shell" });
  shell.append(
    element("p", { className: "eyebrow", text: "JUNGLE LAW · PRIVATE ACCESS" }),
    element("h1", { text: "赛事数据中心" }),
    element("p", { className: "hint", text: "仅 Owner 或由 Owner 授权的分析人员可访问。" }),
  );
  const form = element("form");
  const username = element("input", { name: "username", required: true, autocomplete: "username", placeholder: "管理员用户名" });
  const password = element("input", { name: "password", type: "password", required: true, autocomplete: "current-password", placeholder: "管理员密码" });
  const error = element("p", { className: "error", text: message });
  const submit = element("button", { className: "primary", type: "submit", text: "安全登录" });
  form.append(label("用户名", username), label("密码", password), error, submit);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    submit.disabled = true;
    error.textContent = "";
    try {
      const result = await request("/api/auth/login", {
        method: "POST",
        body: JSON.stringify({ username: username.value, password: password.value }),
      });
      state.session = result.user;
      state.csrfToken = result.csrf_token;
      await showDashboard();
    } catch (requestError) {
      error.textContent = apiErrorMessage(requestError.code);
      password.value = "";
    } finally {
      submit.disabled = false;
    }
  });
  shell.append(form);
  app.append(shell);
}

function label(text, control) {
  const node = element("label", { text });
  node.append(control);
  return node;
}

function panel(title, content, subtitle = "") {
  const section = element("section", { className: "panel" });
  const heading = element("div", { className: "panel-heading" });
  heading.append(element("h2", { text: title }));
  if (subtitle) heading.append(element("span", { className: "muted", text: subtitle }));
  section.append(heading, content);
  return section;
}

function emptyState(text) {
  return element("p", { className: "empty", text });
}

function table(headers, rows) {
  const scroll = element("div", { className: "table-scroll" });
  const tableNode = document.createElement("table");
  const head = document.createElement("thead");
  const headRow = document.createElement("tr");
  headers.forEach((header) => headRow.append(element("th", { text: header })));
  head.append(headRow);
  const body = document.createElement("tbody");
  rows.forEach((row) => body.append(row));
  tableNode.append(head, body);
  scroll.append(tableNode);
  return scroll;
}

function metric(labelText, value) {
  const card = element("article", { className: "metric" });
  card.append(element("span", { text: labelText }), element("strong", { text: String(value) }));
  return card;
}

function renderOverview() {
  const dashboard = state.dashboard;
  const section = element("div", { className: "tab-pane" });
  const overview = dashboard.overview;
  const metrics = element("section", { className: "overview-grid" });
  metrics.append(
    metric("已纳入对局", overview.matches),
    metric("上榜玩家", overview.players),
    metric("近 24 小时活跃", overview.active_24h),
    metric("统计赛季", overview.season || "未设定"),
  );
  section.append(metrics);
  const note = dashboard.availability === "ready"
    ? `快照更新时间：${formatDate(dashboard.generated_at_unix)}。${analyticsSourceLabel(overview.source)} 动物胜率表示携带该动物卡组的对局胜率。`
    : "尚未收到服务器统计快照。网站本身可安全运行，数据会在快照到位后自动显示。";
  section.append(panel("统计说明", element("p", { className: "muted", text: note }), "受保护的只读数据投影"));
  section.append(renderRecentMatches());
  return section;
}

function renderRecentMatches() {
  const matches = state.dashboard.recent_matches || [];
  if (matches.length === 0) return panel("最近对局", emptyState("暂无已记录的完整在线对局。"));
  const list = element("div", { className: "recent-match-list" });
  matches.slice(0, 8).forEach((match) => {
    const entry = element("article", { className: "recent-match" });
    const summary = element("div", { className: "recent-match-title" });
    summary.append(
      element("strong", { text: match.map_id || "在线对局" }),
      element("span", { className: "muted", text: formatDate(match.finalized_at_unix || match.started_at_unix) }),
    );
    const players = element("div", { className: "recent-match-players" });
    match.players.forEach((player) => {
      const outcome = match.team_outcomes?.[player.team_id];
      const playerNode = element("span", { className: outcome === "win" ? "good" : outcome === "loss" ? "bad" : "muted" });
      playerNode.textContent = `${player.display_name || compactUserId(player.user_id) || "玩家"} · ${outcomeLabel(outcome)}`;
      players.append(playerNode);
    });
    entry.append(summary, players);
    list.append(entry);
  });
  return panel("最近对局", list, "仅展示已冻结阵容与服务器记录的终局结果");
}

function renderLeaderboard() {
  const entries = state.dashboard.leaderboard;
  if (entries.length === 0) return panel("玩家排行榜", emptyState("当前没有可展示的玩家排名。"));
  const rows = entries.map((entry) => {
    const row = document.createElement("tr");
    const rank = element("td", { className: "rank-number", text: `#${entry.rank}` });
    const name = document.createElement("td");
    name.append(element("span", { className: "rank-name", text: entry.display_name || "未命名玩家" }));
    if (entry.user_id) name.append(element("span", { className: "rank-id", text: compactUserId(entry.user_id) }));
    row.append(rank, name, element("td", { text: `${entry.rank_key} ${entry.rank_stars} 星` }), element("td", { text: entry.elo ?? "—" }), element("td", { text: entry.matches }), element("td", { className: entry.win_rate >= 0.5 ? "good" : "bad", text: formatPercent(entry.win_rate) }));
    return row;
  });
  return panel("玩家排行榜", table(["排名", "玩家", "段位", "Elo", "场次", "胜率"], rows), "按服务端投影排序");
}

function renderDecks() {
  const decks = state.dashboard.top_decks;
  if (decks.length === 0) return panel("头部玩家卡组", emptyState("暂无已记录的头部卡组。"));
  const grid = element("div", { className: "decks-grid" });
  decks.forEach((deck) => {
    const card = element("article", { className: "deck-card" });
    const title = element("div", { className: "deck-title" });
    title.append(element("strong", { text: `#${deck.rank} ${deck.display_name || deck.user_id || "玩家"}` }), element("span", { text: formatPercent(deck.win_rate), className: deck.win_rate >= 0.5 ? "good" : "bad" }));
    const meta = element("p", { className: "deck-meta", text: `${deck.rank_key} · ${deck.rank_stars} 星 · ${deck.matches} 场` });
    const chips = element("div", { className: "card-chips" });
    deck.deck.forEach((cardId) => {
      const chip = element("span", { className: "card-chip", text: cardId });
      chip.append(element("b", { text: `Lv.${deck.card_levels[cardId] || 1}` }));
      chips.append(chip);
    });
    card.append(title, meta, chips);
    grid.append(card);
  });
  return panel("头部玩家卡组", grid, "显示开局卡组与卡牌等级快照");
}

function renderAnimals() {
  const animals = state.dashboard.animals;
  if (animals.length === 0) return panel("动物胜率", emptyState("暂无完成对局的动物统计样本。"));
  const rows = animals.map((animal) => {
    const row = document.createElement("tr");
    row.append(
      element("td", { text: animal.name }),
      element("td", { className: "muted", text: animal.card_id }),
      element("td", { text: animal.games }),
      element("td", { text: animal.wins }),
      element("td", { text: animal.losses }),
      element("td", { className: animal.games > 0 && animal.win_rate >= 0.5 ? "good" : "bad", text: animal.games > 0 ? formatPercent(animal.win_rate) : "暂无数据" }),
      element("td", { text: formatPercent(animal.pick_rate) }),
    );
    return row;
  });
  return panel("动物胜率", table(["动物", "卡牌 ID", "样本", "胜", "负", "胜率", "登场率"], rows), "同一动物按携带它的已完成对局统计");
}

async function loadManagement() {
  const [usersPayload, auditPayload] = await Promise.all([
    request("/api/admins"),
    request("/api/audit?limit=40"),
  ]);
  state.users = usersPayload.users || [];
  state.audit = auditPayload.entries || [];
}

function renderManagement() {
  const pane = element("div", { className: "tab-pane" });
  const grid = element("div", { className: "management-grid" });
  const createForm = element("form", { className: "manage-create" });
  createForm.append(
    element("h2", { text: "授权新成员" }),
    element("p", { className: "hint", text: "不会开放自行注册；仅 Owner 可以创建或撤销访问权。" }),
  );
  const username = element("input", { name: "username", required: true, placeholder: "3–32 位英文、数字或 ._-" });
  const password = element("input", { name: "password", type: "password", required: true, autocomplete: "new-password", placeholder: "至少 12 位密码" });
  const role = element("select", { name: "role" });
  role.append(new Option("Analyst（只读数据）", "analyst"), new Option("Owner（可授权管理）", "owner"));
  const createError = element("p", { className: "error" });
  const submit = element("button", { className: "primary", type: "submit", text: "创建授权账号" });
  createForm.append(label("用户名", username), label("初始密码", password), label("角色", role), createError, submit);
  createForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    submit.disabled = true;
    createError.textContent = "";
    try {
      await request("/api/admins", {
        method: "POST",
        mutation: true,
        body: JSON.stringify({ username: username.value, password: password.value, role: role.value }),
      });
      password.value = "";
      username.value = "";
      await loadManagement();
      renderTab("management");
    } catch (requestError) {
      createError.textContent = apiErrorMessage(requestError.code);
    } finally {
      submit.disabled = false;
    }
  });
  grid.append(panel("权限管理", createForm));

  const userRows = state.users.map((user) => {
    const row = document.createElement("tr");
    const actions = element("td", { className: "actions" });
    const toggle = element("button", { className: user.status === "active" ? "danger" : "secondary", text: user.status === "active" ? "停用" : "启用" });
    toggle.addEventListener("click", () => updateUser(user.username, { status: user.status === "active" ? "disabled" : "active" }));
    const changeRole = element("button", { className: "secondary", text: user.role === "owner" ? "改为 Analyst" : "改为 Owner" });
    changeRole.addEventListener("click", () => updateUser(user.username, { role: user.role === "owner" ? "analyst" : "owner" }));
    const revoke = element("button", { className: "secondary", text: "撤销会话" });
    revoke.addEventListener("click", () => revokeSessions(user.username));
    actions.append(toggle, changeRole, revoke);
    row.append(element("td", { text: user.username }), element("td", { text: user.role }), element("td", { text: user.status }), element("td", { text: formatDate(Math.floor(user.updated_at / 1000)) }), actions);
    return row;
  });
  grid.append(panel("已授权成员", userRows.length ? table(["用户名", "角色", "状态", "更新于", "操作"], userRows) : emptyState("尚未授权其他成员。")));
  pane.append(grid);

  const auditList = element("div", { className: "audit-list" });
  if (state.audit.length === 0) {
    auditList.append(emptyState("尚无可展示的审计事件。"));
  } else {
    state.audit.forEach((entry) => {
      const item = element("article", { className: "audit-entry" });
      item.append(element("strong", { text: entry.event }), document.createTextNode(` · ${entry.actor || "系统"} → ${entry.target || "-"} · ${formatDate(Math.floor(entry.at / 1000))}`));
      if (entry.detail) item.append(document.createElement("br"), document.createTextNode(entry.detail));
      auditList.append(item);
    });
  }
  pane.append(panel("权限审计", auditList, "不记录密码、令牌或 Cookie"));
  return pane;
}

async function updateUser(username, patch) {
  try {
    await request(`/api/admins/${encodeURIComponent(username)}`, { method: "PATCH", mutation: true, body: JSON.stringify(patch) });
    await loadManagement();
    renderTab("management");
  } catch (requestError) {
    window.alert(apiErrorMessage(requestError.code));
  }
}

async function revokeSessions(username) {
  try {
    await request(`/api/admins/${encodeURIComponent(username)}/revoke-sessions`, { method: "POST", mutation: true, body: JSON.stringify({}) });
    await loadManagement();
    renderTab("management");
  } catch (requestError) {
    window.alert(apiErrorMessage(requestError.code));
  }
}

function renderTab(name) {
  const main = document.querySelector("#tab-content");
  if (!main) return;
  clear(main);
  if (name === "overview") main.append(renderOverview());
  if (name === "ranking") main.append(renderLeaderboard());
  if (name === "decks") main.append(renderDecks());
  if (name === "animals") main.append(renderAnimals());
  if (name === "management") main.append(renderManagement());
  document.querySelectorAll(".nav-button").forEach((button) => button.classList.toggle("active", button.dataset.tab === name));
}

async function showDashboard() {
  try {
    state.dashboard = await request("/api/dashboard");
  } catch (requestError) {
    if (requestError.status === 401) {
      state.session = null;
      state.csrfToken = "";
      showLogin("登录已失效，请重新登录。");
      return;
    }
    showLogin(apiErrorMessage(requestError.code));
    return;
  }
  clear(app);
  const shell = element("section", { className: "dashboard" });
  const masthead = element("header", { className: "masthead" });
  const title = element("div");
  title.append(element("p", { className: "eyebrow", text: "JUNGLE LAW · SEASON INTELLIGENCE" }), element("h1", { text: "赛事数据中心" }), element("p", { text: "私有赛事排行、头部卡组与动物表现统计" }));
  const account = element("div", { className: "account-actions" });
  account.append(element("span", { className: "account-chip", text: `${state.session.username} · ${state.session.role}` }));
  const logout = element("button", { className: "secondary", text: "退出登录" });
  logout.addEventListener("click", logoutCurrentUser);
  account.append(logout);
  masthead.append(title, account);
  shell.append(masthead);

  const tabs = element("nav", { className: "tabs" });
  const tabDefinitions = [
    ["overview", "总览"],
    ["ranking", "玩家榜单"],
    ["decks", "头部卡组"],
    ["animals", "动物胜率"],
  ];
  if (state.session.role === "owner") tabDefinitions.push(["management", "授权管理"]);
  tabDefinitions.forEach(([name, labelText], index) => {
    const button = element("button", { className: `nav-button${index === 0 ? " active" : ""}`, text: labelText });
    button.dataset.tab = name;
    button.addEventListener("click", async () => {
      if (name === "management") {
        try {
          await loadManagement();
        } catch (requestError) {
          window.alert(apiErrorMessage(requestError.code));
          return;
        }
      }
      renderTab(name);
    });
    tabs.append(button);
  });
  const content = element("div");
  content.id = "tab-content";
  shell.append(tabs, content);
  app.append(shell);
  renderTab("overview");
}

async function logoutCurrentUser() {
  try {
    await request("/api/auth/logout", { method: "POST", mutation: true, body: JSON.stringify({}) });
  } catch {
    // The local cookie may already have expired; render login either way.
  }
  state.session = null;
  state.csrfToken = "";
  state.dashboard = null;
  showLogin();
}

async function boot() {
  try {
    const session = await request("/api/session");
    state.session = session.user;
    state.csrfToken = session.csrf_token;
    await showDashboard();
  } catch {
    showLogin();
  }
}

void boot();
