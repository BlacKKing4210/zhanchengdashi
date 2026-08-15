const app = document.querySelector("#app");
const liveRegion = document.querySelector("#live-region");

const state = {
  session: null,
  csrfToken: "",
  dashboard: null,
  accounts: null,
  grants: [],
  grantsLoaded: false,
  users: [],
  audit: [],
  managementLoaded: false,
  activeTab: "overview",
  animalQuery: "",
  accountQuery: "",
  accountPage: 1,
  grantDraft: null,
  grantPreview: null,
  grantResult: null,
  grantBusy: false,
  loadErrors: {},
};

const ACCOUNT_PAGE_SIZE = 12;
const OWNER_TABS = new Set(["grants", "tasks", "permissions"]);
const TAB_DEFINITIONS = [
  ["overview", "总览"],
  ["animals", "动物平衡"],
  ["accounts", "阵容库"],
  ["grants", "Owner 资源发放"],
  ["tasks", "Owner 任务与审计"],
  ["permissions", "Owner 权限"],
];

function element(tag, options = {}) {
  const node = document.createElement(tag);
  if (options.className) node.className = options.className;
  if (options.text !== undefined) node.textContent = String(options.text);
  for (const key of ["type", "name", "value", "placeholder", "autocomplete", "id", "title", "min", "max", "step"]) {
    if (options[key] !== undefined) node[key] = options[key];
  }
  for (const key of ["required", "disabled", "checked"]) {
    if (options[key]) node[key] = true;
  }
  for (const [key, value] of Object.entries(options.attrs || {})) node.setAttribute(key, String(value));
  for (const [key, value] of Object.entries(options.dataset || {})) node.dataset[key] = String(value);
  return node;
}

function clear(node) {
  node.replaceChildren();
  return node;
}

function announce(message) {
  if (!liveRegion) return;
  liveRegion.textContent = "";
  window.requestAnimationFrame(() => { liveRegion.textContent = message; });
}

function toNumber(value) {
  const result = Number(value);
  return Number.isFinite(result) ? result : null;
}

function formatNumber(value, digits = 0) {
  const number = toNumber(value);
  return number === null ? "—" : number.toLocaleString("zh-CN", { maximumFractionDigits: digits, minimumFractionDigits: digits });
}

function formatPercent(value) {
  const number = toNumber(value);
  return number === null ? "—" : `${(number * 100).toFixed(1)}%`;
}

function formatDate(unixSeconds) {
  const value = toNumber(unixSeconds);
  if (!value) return "尚无数据";
  return new Intl.DateTimeFormat("zh-CN", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value * 1000));
}

function compactUserId(value) {
  const userId = String(value || "");
  if (userId.length <= 18) return userId || "—";
  return `${userId.slice(0, 9)}…${userId.slice(-6)}`;
}

function roleLabel(value) {
  return value === "owner" ? "Owner" : "Analyst";
}

function outcomeLabel(value) {
  return ({ win: "胜", loss: "负", draw: "平" })[value] || "—";
}

function sourceLabel(value) {
  const labels = {
    server_recorded_host_authority_full_human_online: "服务器记录的房主权威对局，仅统计满额真人在线房间。",
  };
  return labels[value] || "服务器生成的脱敏只读统计投影。";
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
    account_snapshot_unavailable: "账号阵容投影当前不可用。",
    invalid_target: "目标账号无效或已不在最新投影中。",
    invalid_grant: "资源类型、数量或卡牌 ID 无效。",
    confirmation_required: "二次确认文本不匹配。",
    reauthentication_failed: "重新认证失败，请核对当前 Owner 密码。",
    owner_reauthentication_failed: "重新认证失败，请核对当前 Owner 密码。",
    grant_reauth_rate_limited: "重新认证尝试过于频繁，请稍后再试。",
    all_confirmation_required: "全服二次确认文本必须准确等于 SEND TO ALL。",
    target_not_found: "指定账号不在最新账号投影中，请刷新后重新预览。",
    no_target_accounts: "最新账号投影中没有可发放目标。",
    invalid_idempotency_key: "幂等键无效，请返回并重新生成预览。",
    invalid_grant_amount: "资源数量无效。",
    invalid_card_id: "卡牌 ID 无效。",
    invalid_reason: "请填写可审计的发放原因。",
    unsupported_resource: "资源类型不受支持。",
    idempotency_conflict: "该幂等键已用于不同指令，请重新预览。",
    command_write_failed: "指令未能安全写入命令目录，请联系运维。",
  };
  return messages[code] || "操作未完成，请检查输入后重试。";
}

async function request(url, options = {}) {
  const headers = new Headers(options.headers || {});
  if (options.body !== undefined) headers.set("Content-Type", "application/json");
  if (options.mutation && state.csrfToken) headers.set("X-CSRF-Token", state.csrfToken);
  const response = await fetch(url, { ...options, headers, credentials: "same-origin" });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(payload.error || "request_failed");
    error.code = payload.error || "request_failed";
    error.status = response.status;
    throw error;
  }
  return payload;
}

function labeledControl(text, control, hint = "") {
  const wrapper = element("label");
  wrapper.append(element("span", { text }));
  wrapper.append(control);
  if (hint) wrapper.append(element("small", { className: "field-hint", text: hint }));
  return wrapper;
}

function panel(title, content, subtitle = "", options = {}) {
  const section = element("section", { className: `panel${options.className ? ` ${options.className}` : ""}` });
  if (options.id) section.id = options.id;
  const heading = element("div", { className: "panel-heading" });
  const headingNode = element(options.headingLevel || "h2", { text: title });
  heading.append(headingNode);
  if (subtitle) heading.append(element("span", { className: "muted", text: subtitle }));
  section.append(heading, content);
  return section;
}

function callout(kind, title, message, role = "status") {
  const node = element("div", { className: `callout callout-${kind}`, attrs: { role } });
  node.append(element("strong", { text: title }), element("p", { text: message }));
  return node;
}

function loadingState(text = "正在加载…") {
  return element("p", { className: "state-message", text, attrs: { role: "status" } });
}

function emptyState(text) {
  return element("p", { className: "state-message empty", text });
}

function errorState(message, retry) {
  const node = callout("danger", "数据加载失败", message, "alert");
  if (retry) {
    const button = element("button", { className: "secondary", type: "button", text: "重试" });
    button.addEventListener("click", retry);
    node.append(button);
  }
  return node;
}

function dataTable(captionText, columns, rows, options = {}) {
  const region = element("div", {
    className: `table-scroll${options.className ? ` ${options.className}` : ""}`,
    attrs: { role: "region", tabindex: "0", "aria-label": captionText },
  });
  const tableNode = document.createElement("table");
  if (options.tableClassName) tableNode.className = options.tableClassName;
  tableNode.append(element("caption", { className: "sr-only", text: captionText }));
  const head = document.createElement("thead");
  const headRow = document.createElement("tr");
  columns.forEach((column) => headRow.append(element("th", {
    className: column.className || "",
    text: column.label,
    attrs: { scope: "col", ...(column.priority ? { "data-priority": column.priority } : {}) },
  })));
  head.append(headRow);
  const body = document.createElement("tbody");
  rows.forEach((values) => {
    const row = document.createElement("tr");
    values.forEach((value, index) => {
      const column = columns[index] || {};
      const cell = element("td", {
        className: column.className || "",
        attrs: { "data-label": column.label, ...(column.priority ? { "data-priority": column.priority } : {}) },
      });
      if (value instanceof Node) cell.append(value);
      else cell.textContent = String(value ?? "—");
      row.append(cell);
    });
    body.append(row);
  });
  tableNode.append(head, body);
  region.append(tableNode);
  return region;
}

function metric(labelText, value, note = "") {
  const card = element("article", { className: "metric" });
  card.append(element("span", { text: labelText }), element("strong", { text: String(value) }));
  if (note) card.append(element("small", { text: note }));
  return card;
}

function tag(text, kind = "neutral") {
  return element("span", { className: `status-tag status-${kind}`, text });
}

function normalizeList(value) {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object") return Object.entries(value).map(([id, item]) => ({ id, ...(item && typeof item === "object" ? item : { value: item }) }));
  return [];
}

function renderOverview() {
  const dashboard = state.dashboard || {};
  const overview = dashboard.overview || {};
  const pane = createPane("overview", "运营总览");
  const metrics = element("section", { className: "overview-grid", attrs: { "aria-label": "核心指标" } });
  metrics.append(
    metric("已纳入对局", formatNumber(overview.matches)),
    metric("上榜玩家", formatNumber(overview.players)),
    metric("近 24 小时活跃", formatNumber(overview.active_24h)),
    metric("统计赛季", overview.season || "未设定"),
  );
  pane.append(metrics);
  const note = dashboard.availability === "ready"
    ? `快照更新时间：${formatDate(dashboard.generated_at_unix)}。${sourceLabel(overview.source)} 排名与平衡信号用于分析建议，不直接修改游戏配置。`
    : "尚未收到服务器统计快照。后台保持可登录状态，快照到位后再展示统计。";
  pane.append(panel("统计口径", element("p", { className: "muted", text: note }), "只读数据投影"));
  pane.append(renderLeaderboard(), renderRecentMatches());
  return pane;
}

function renderLeaderboard() {
  const entries = normalizeList(state.dashboard?.leaderboard);
  if (!entries.length) return panel("玩家排行榜", emptyState("当前没有可展示的玩家排名。"));
  const columns = ["排名", "玩家", "段位", "Elo", "场次", "胜率"].map((label) => ({ label }));
  const rows = entries.map((entry) => {
    const name = element("span", { className: "rank-name", text: entry.display_name || "未命名玩家" });
    if (entry.user_id) name.append(element("small", { className: "rank-id", text: compactUserId(entry.user_id) }));
    return [
      element("span", { className: "rank-number", text: `#${entry.rank ?? "—"}` }),
      name,
      `${entry.rank_key || "—"} ${entry.rank_stars ?? "—"} 星`,
      formatNumber(entry.elo),
      formatNumber(entry.games),
      element("span", { className: Number(entry.win_rate) >= 0.5 ? "good" : "bad", text: formatPercent(entry.win_rate) }),
    ];
  });
  return panel("玩家排行榜", dataTable("玩家排行榜", columns, rows), "按服务端投影排序");
}

function renderRecentMatches() {
  const matches = normalizeList(state.dashboard?.recent_matches);
  if (!matches.length) return panel("最近对局", emptyState("暂无已记录的完整在线对局。"));
  const list = element("div", { className: "recent-match-list" });
  matches.slice(0, 8).forEach((match) => {
    const entry = element("article", { className: "recent-match" });
    const summary = element("div", { className: "recent-match-title" });
    summary.append(element("strong", { text: match.map_id || "在线对局" }), element("span", { className: "muted", text: formatDate(match.finalized_at_unix || match.started_at_unix) }));
    const players = element("div", { className: "recent-match-players" });
    normalizeList(match.players).forEach((player) => {
      const outcome = match.team_outcomes?.[player.team_id];
      players.append(element("span", {
        className: outcome === "win" ? "good" : outcome === "loss" ? "bad" : "muted",
        text: `${player.display_name || compactUserId(player.user_id) || "玩家"} · ${outcomeLabel(outcome)}`,
      }));
    });
    entry.append(summary, players);
    list.append(entry);
  });
  return panel("最近对局", list, "已冻结阵容与服务器终局结果");
}

function balanceSignalMeta(signal) {
  const normalized = String(signal || "insufficient_data").toLowerCase();
  const mapping = {
    too_strong: ["偏强", "danger"],
    strong: ["偏强", "danger"],
    watch_strong: ["关注偏强", "warning"],
    balanced: ["区间内", "good"],
    healthy: ["区间内", "good"],
    watch_weak: ["关注偏弱", "warning"],
    weak: ["偏弱", "danger"],
    too_weak: ["偏弱", "danger"],
    insufficient_data: ["样本不足", "neutral"],
    insufficient_samples: ["样本不足", "neutral"],
    review_nerf: ["建议削弱复核", "danger"],
    review_buff: ["建议增强复核", "warning"],
    observe: ["继续观察", "good"],
  };
  return mapping[normalized] || [signal || "待判断", "neutral"];
}

function confidenceLabel(value) {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    const sufficient = Boolean(value.sample_sufficient);
    const low = toNumber(value.win_rate_lower);
    const high = toNumber(value.win_rate_upper);
    const interval = low !== null && high !== null ? ` · 胜率区间 ${formatPercent(low)}–${formatPercent(high)}` : "";
    return `${sufficient ? "样本充足" : "样本不足"}${interval}${value.rationale ? ` · ${value.rationale}` : ""}`;
  }
  if (typeof value === "string") return value;
  const number = toNumber(value);
  if (number === null) return "—";
  if (number >= 0.8) return `高 · ${formatPercent(number)}`;
  if (number >= 0.5) return `中 · ${formatPercent(number)}`;
  return `低 · ${formatPercent(number)}`;
}

function renderAnimals() {
  const pane = createPane("animals", "动物平衡");
  const allAnimals = normalizeList(state.dashboard?.animals).slice().sort((a, b) => {
    const left = toNumber(a.average_placement);
    const right = toNumber(b.average_placement);
    return (left ?? Number.POSITIVE_INFINITY) - (right ?? Number.POSITIVE_INFINITY);
  });
  if (!allAnimals.length) {
    pane.append(panel("动物平均排名", emptyState("暂无完成对局的动物排名样本。")));
    return pane;
  }
  const query = state.animalQuery.trim().toLowerCase();
  const animals = allAnimals.filter((animal) => {
    if (!query) return true;
    return String(animal.name || "").toLowerCase().includes(query) || String(animal.card_id || "").toLowerCase().includes(query);
  });
  const actionable = allAnimals.filter((animal) => ["too_strong", "strong", "watch_strong", "watch_weak", "weak", "too_weak", "review_nerf", "review_buff"].includes(String(animal.balance_signal || "").toLowerCase())).length;
  const metrics = element("section", { className: "overview-grid compact", attrs: { "aria-label": "平衡概览" } });
  metrics.append(
    metric("动物数量", formatNumber(allAnimals.length)),
    metric("需关注", formatNumber(actionable), "以服务端平衡信号为准"),
    metric("最高样本", formatNumber(Math.max(...allAnimals.map((item) => Number(item.placement_samples || 0))))),
    metric("口径", "平均名次", "名次越小表现越好"),
  );
  pane.append(metrics);
  pane.append(callout("info", "调整建议的边界", "此页提供平均名次、标准化名次得分和置信度，帮助策划判断；任何数值调整仍须走配置评审、验证和发布流程，后台不会直接改写游戏配置。"));
  const selector = element("aside", { className: "panel animal-index-panel", attrs: { "aria-labelledby": "animal-index-title" } });
  const selectorHeading = element("div", { className: "panel-heading" });
  selectorHeading.append(
    element("h2", { id: "animal-index-title", text: "动物索引" }),
    element("span", { className: "muted", text: `${animals.length} / ${allAnimals.length}` }),
  );
  const selectorForm = element("form", { className: "animal-filter", attrs: { role: "search" } });
  const search = element("input", { type: "search", value: state.animalQuery, placeholder: "名称或卡牌 ID", attrs: { "aria-label": "筛选动物排名" } });
  const submit = element("button", { className: "secondary", type: "submit", text: "筛选" });
  const reset = element("button", { className: "ghost", type: "button", text: "全部" });
  selectorForm.append(search, submit, reset);
  selectorForm.addEventListener("submit", (event) => {
    event.preventDefault();
    state.animalQuery = search.value.trim();
    renderActiveTab();
  });
  reset.addEventListener("click", () => {
    state.animalQuery = "";
    renderActiveTab();
  });
  const indexGrid = element("div", { className: "animal-index-grid", attrs: { "aria-label": "按动物筛选" } });
  allAnimals.forEach((animal, index) => {
    const animalKey = String(animal.card_id || animal.name || "");
    const selected = Boolean(query) && [String(animal.card_id || "").toLowerCase(), String(animal.name || "").toLowerCase()].includes(query);
    const button = element("button", {
      className: `animal-index-item${selected ? " selected" : ""}`,
      type: "button",
      title: animal.name || animal.card_id || `动物 ${index + 1}`,
      attrs: { "aria-pressed": String(selected) },
    });
    const displayName = String(animal.name || animal.card_id || index + 1);
    button.append(
      element("span", { className: "animal-index-glyph", text: displayName.slice(0, 1), attrs: { "aria-hidden": "true" } }),
      element("span", { className: "animal-index-name", text: displayName }),
    );
    button.addEventListener("click", () => {
      state.animalQuery = selected ? "" : animalKey;
      renderActiveTab();
    });
    indexGrid.append(button);
  });
  selector.append(selectorHeading, selectorForm, indexGrid);

  const columns = [
    { label: "动物", priority: "core" },
    { label: "排名样本", className: "numeric", priority: "secondary" },
    { label: "平均名次", className: "numeric key-metric", priority: "core" },
    { label: "标准化得分", className: "numeric", priority: "secondary" },
    { label: "平均参赛数", className: "numeric", priority: "secondary" },
    { label: "平衡信号", priority: "core" },
    { label: "置信度", priority: "secondary" },
    { label: "胜率 / 登场率", className: "numeric", priority: "secondary" },
  ];
  const rows = animals.map((animal) => {
    const [signalText, signalKind] = balanceSignalMeta(animal.balance_signal);
    const identity = element("span", { className: "rank-name", text: animal.name || animal.card_id || "未命名动物" });
    if (animal.card_id) identity.append(element("small", { className: "rank-id", text: animal.card_id }));
    return [
      identity,
      formatNumber(animal.placement_samples),
      formatNumber(animal.average_placement, 2),
      formatNumber(animal.average_placement_score, 3),
      formatNumber(animal.average_field_size, 2),
      tag(signalText, signalKind),
      confidenceLabel(animal.confidence),
      `${formatPercent(animal.win_rate)} / ${formatPercent(animal.pick_rate)}`,
    ];
  });
  const rankingContent = animals.length
    ? dataTable("动物平均排名与平衡信号", columns, rows, { className: "rank-table-scroll", tableClassName: "rank-table" })
    : emptyState("没有匹配的动物；请清除筛选后重试。");
  const rankingPanel = panel("动物平均排名", rankingContent, `显示 ${animals.length} / ${allAnimals.length} · 按平均名次升序`, { className: "ranking-panel" });
  const rankingsLayout = element("div", { className: "rankings-layout" });
  rankingsLayout.append(selector, rankingPanel);
  pane.append(rankingsLayout);
  const formula = element("div", { className: "formula-card" });
  formula.append(
    element("p", { text: "平均名次 = Σ该动物在有效对局中的最终名次 ÷ 排名样本数。" }),
    element("p", { text: "单局标准化名次得分：参赛数≤1 时为 1，否则为 (参赛数−名次)÷(参赛数−1)；平均得分为各有效样本之和÷排名样本数，越接近 1 越强。" }),
    element("p", { text: "平均参赛数用于说明不同对局规模。平衡信号与置信度由服务端按正式阈值生成，前端不自行重算。" }),
  );
  pane.append(panel("字段与公式", formula, "同口径比较后再提出调整"));
  return pane;
}

async function loadAccounts(force = false) {
  if (state.accounts && !force) return;
  state.loadErrors.accounts = "";
  try {
    state.accounts = await request("/api/accounts");
  } catch (error) {
    state.accounts = null;
    state.loadErrors.accounts = apiErrorMessage(error.code);
    throw error;
  }
}

function accountDisplayName(account) {
  return account.masked_account || compactUserId(account.user_id);
}

function renderResources(resources) {
  const values = [];
  if (resources && typeof resources === "object") {
    for (const [key, value] of Object.entries(resources)) {
      if (value && typeof value === "object" && !Array.isArray(value)) {
        Object.entries(value).slice(0, 7).forEach(([nestedKey, nestedValue]) => values.push([`${key}.${nestedKey}`, nestedValue]));
      } else {
        values.push([key, value]);
      }
    }
  }
  const wrapper = element("div", { className: "resource-chips" });
  if (!values.length) wrapper.append(element("span", { className: "muted", text: "无资源摘要" }));
  values.slice(0, 8).forEach(([key, value]) => wrapper.append(element("span", { className: "card-chip", text: `${key}：${formatNumber(value)}` })));
  return wrapper;
}

function renderDeck(account) {
  const deck = normalizeList(account.deck).map((entry) => typeof entry === "string" ? entry : entry.card_id || entry.id || String(entry.value || "")).filter(Boolean);
  const levels = account.card_levels || {};
  const wrapper = element("div", { className: "card-chips" });
  if (!deck.length) wrapper.append(element("span", { className: "muted", text: "未保存阵容" }));
  deck.forEach((cardId) => {
    const chip = element("span", { className: "card-chip", text: cardId });
    const level = levels[cardId];
    if (level !== undefined) chip.append(element("b", { text: `Lv.${level}` }));
    wrapper.append(chip);
  });
  return wrapper;
}

function renderRankMirrors(rankMirrors) {
  const mirrors = [];
  if (Array.isArray(rankMirrors)) {
    mirrors.push(...rankMirrors);
  } else if (rankMirrors && typeof rankMirrors === "object") {
    for (const [rankKey, values] of Object.entries(rankMirrors)) {
      if (Array.isArray(values)) values.forEach((value) => mirrors.push({ rank_key: rankKey, ...value }));
    }
  }
  const wrapper = element("div", { className: "mirror-list" });
  if (!mirrors.length) wrapper.append(element("span", { className: "muted", text: "无段位镜像" }));
  mirrors.slice(0, 6).forEach((mirror) => {
    const name = mirror.rank_key || mirror.id || mirror.mode || "段位";
    const detail = mirror.rank_stars ?? mirror.stars ?? mirror.value ?? "—";
    wrapper.append(element("span", { className: "mirror-chip", text: `${name} · ${detail}` }));
  });
  return wrapper;
}

function renderAccounts() {
  const pane = createPane("accounts", "阵容库");
  if (state.loadErrors.accounts) {
    pane.append(errorState(state.loadErrors.accounts, () => switchTab("accounts", { force: true })));
    return pane;
  }
  if (!state.accounts) {
    pane.append(loadingState("正在加载账号阵容投影…"));
    return pane;
  }
  if (state.accounts.availability !== "ready") {
    pane.append(callout("warning", "账号投影未就绪", "后台不会读取权威账号存档；请由阿里云投影任务生成 admin_accounts_snapshot.json 后重试。", "alert"));
    return pane;
  }
  const accounts = normalizeList(state.accounts.accounts);
  const toolbar = element("form", { className: "filter-bar", attrs: { role: "search" } });
  const search = element("input", { type: "search", value: state.accountQuery, placeholder: "搜索脱敏账号或完整 user_id", attrs: { "aria-label": "搜索阵容" } });
  const submit = element("button", { className: "secondary", type: "submit", text: "搜索" });
  const reset = element("button", { className: "ghost", type: "button", text: "清除" });
  toolbar.append(search, submit, reset);
  toolbar.addEventListener("submit", (event) => {
    event.preventDefault();
    state.accountQuery = search.value.trim();
    state.accountPage = 1;
    renderActiveTab();
  });
  reset.addEventListener("click", () => {
    state.accountQuery = "";
    state.accountPage = 1;
    renderActiveTab();
  });
  const query = state.accountQuery.toLowerCase();
  const filtered = accounts.filter((account) => !query || String(account.user_id || "").toLowerCase().includes(query) || String(account.masked_account || "").toLowerCase().includes(query));
  const pageCount = Math.max(1, Math.ceil(filtered.length / ACCOUNT_PAGE_SIZE));
  state.accountPage = Math.min(state.accountPage, pageCount);
  const pageItems = filtered.slice((state.accountPage - 1) * ACCOUNT_PAGE_SIZE, state.accountPage * ACCOUNT_PAGE_SIZE);
  const summary = element("div", { className: "section-summary" });
  summary.append(element("p", { text: `共 ${accounts.length} 个保存账号，筛选后 ${filtered.length} 个。投影时间：${formatDate(state.accounts.generated_at_unix)}。` }), tag("只读投影", "good"));
  pane.append(panel("查找阵容", toolbar, "搜索只在当前投影中执行"), summary);
  if (!pageItems.length) {
    pane.append(panel("保存阵容", emptyState("没有匹配的保存阵容。")));
    return pane;
  }
  const grid = element("div", { className: "accounts-grid" });
  pageItems.forEach((account) => {
    const card = element("article", { className: "account-card" });
    const heading = element("div", { className: "account-card-heading" });
    const title = element("div");
    title.append(element("h2", { text: accountDisplayName(account) }), element("code", { text: account.user_id || "—" }));
    heading.append(title, tag(account.rank?.rank_key || account.rank?.key || "未定段", "neutral"));
    const facts = element("dl", { className: "account-facts" });
    const rankStars = account.rank?.rank_stars ?? account.rank?.stars ?? "—";
    [["段位星", rankStars], ["投影更新", formatDate(account.updated_at_unix)]].forEach(([term, value]) => {
      facts.append(element("dt", { text: term }), element("dd", { text: value }));
    });
    card.append(heading, facts, element("h3", { text: "当前阵容" }), renderDeck(account), element("h3", { text: "段位镜像" }), renderRankMirrors(account.rank_mirrors), element("h3", { text: "资源摘要" }), renderResources(account.resources));
    grid.append(card);
  });
  pane.append(grid);
  const pager = element("nav", { className: "pagination", attrs: { "aria-label": "阵容分页" } });
  const previous = element("button", { className: "secondary", type: "button", text: "上一页", disabled: state.accountPage <= 1 });
  const next = element("button", { className: "secondary", type: "button", text: "下一页", disabled: state.accountPage >= pageCount });
  previous.addEventListener("click", () => { state.accountPage -= 1; renderActiveTab(); focusPageHeading(); });
  next.addEventListener("click", () => { state.accountPage += 1; renderActiveTab(); focusPageHeading(); });
  pager.append(previous, element("span", { text: `第 ${state.accountPage} / ${pageCount} 页` }), next);
  pane.append(pager);
  return pane;
}

function generateIdempotencyKey() {
  if (window.crypto?.randomUUID) return window.crypto.randomUUID();
  return `grant-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function accountOptions(select) {
  select.append(new Option("选择指定账号", ""));
  normalizeList(state.accounts?.accounts).forEach((account) => select.append(new Option(`${accountDisplayName(account)} · ${compactUserId(account.user_id)}`, account.user_id)));
}

function buildGrantDraft(form) {
  const formData = new FormData(form);
  const kind = String(formData.get("target_kind") || "user");
  const type = String(formData.get("grant_type") || "gacha_tickets");
  const draft = {
    target: { kind },
    grant: { type, amount: Number(formData.get("amount")) },
    reason: String(formData.get("reason") || "").trim(),
  };
  if (kind === "user") draft.target.user_id = String(formData.get("user_id") || "");
  if (type === "card_copies") draft.grant.card_id = String(formData.get("card_id") || "").trim();
  return draft;
}

function validateGrantDraft(draft) {
  const accountCount = normalizeList(state.accounts?.accounts).length;
  if (draft.target.kind === "all" && (state.accounts?.availability !== "ready" || accountCount < 1)) return "全服目标必须基于已就绪且非空的账号投影。";
  if (draft.target.kind === "user" && !draft.target.user_id) return "请选择目标账号。";
  if (!Number.isInteger(draft.grant.amount) || draft.grant.amount < 1 || draft.grant.amount > 100000) return "数量必须是 1–100,000 的整数。";
  if (draft.grant.type === "card_copies" && !draft.grant.card_id) return "发送卡牌副本时必须填写卡牌 ID。";
  if (draft.reason.length < 4 || draft.reason.length > 200) return "原因需为 4–200 个字符。";
  return "";
}

function grantTargetCount(draft) {
  return draft?.target.kind === "all" ? normalizeList(state.accounts?.accounts).length : 1;
}

function grantDescription(draft) {
  if (!draft) return "—";
  const rawGrant = draft.grant || draft.grants?.[0] || {};
  const type = rawGrant.type || rawGrant.resource;
  if (type === "card_copies") return `卡牌 ${rawGrant.card_id || "—"} 副本 × ${formatNumber(rawGrant.amount)}`;
  if (type === "gacha_tickets") return `抽卡券 × ${formatNumber(rawGrant.amount)}`;
  return "—";
}

function renderGrantPreview(pane) {
  if (!state.grantPreview) return;
  const draft = state.grantPreview.draft;
  const targetCount = grantTargetCount(draft);
  const preview = element("section", { className: "panel grant-preview", attrs: { "aria-labelledby": "grant-preview-heading" } });
  preview.append(element("p", { className: "step-label", text: "步骤 2–4 / 4 · 重新认证、二次确认、提交" }), element("h2", { id: "grant-preview-heading", text: "核对不可撤销指令" }));
  preview.append(callout("danger", "提交后不可撤销", "提交只会创建服务器待执行指令，不表示资源已到账。请依据任务状态回执核对执行结果；失败时不要更换幂等键盲目重试。", "alert"));
  const facts = element("dl", { className: "preview-facts" });
  const targetText = draft.target.kind === "all" ? `全部账号（${targetCount} 个）` : `${compactUserId(draft.target.user_id)}（1 个）`;
  [["目标", targetText], ["资源", grantDescription(draft)], ["原因", draft.reason], ["幂等键", state.grantPreview.idempotencyKey]].forEach(([term, value]) => facts.append(element("dt", { text: term }), element("dd", { text: value })));
  preview.append(facts);
  const confirmForm = element("form", { className: "grant-confirm-form" });
  const password = element("input", { type: "password", name: "password", required: true, autocomplete: "current-password", placeholder: "当前 Owner 密码" });
  const expectedConfirmation = draft.target.kind === "all" ? "SEND TO ALL" : "SEND";
  const confirmation = element("input", { name: "confirmation", required: true, autocomplete: "off", placeholder: expectedConfirmation, attrs: { spellcheck: "false" } });
  const error = element("p", { className: "error", attrs: { role: "alert", tabindex: "-1" } });
  const actions = element("div", { className: "form-actions" });
  const back = element("button", { className: "secondary", type: "button", text: "返回修改" });
  const submit = element("button", { className: "danger-solid", type: "submit", text: "提交不可撤销指令" });
  actions.append(back, submit);
  confirmForm.append(
    labeledControl("步骤 2 · 重新认证", password, "密码仅随本次 HTTPS 请求发送，不保存到前端状态或审计日志。"),
    labeledControl("步骤 3 · 输入二次确认文本", confirmation, `请准确输入 ${expectedConfirmation}`),
    error,
    actions,
  );
  back.addEventListener("click", () => { state.grantPreview = null; renderActiveTab(); focusPageHeading(); });
  confirmForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    error.textContent = "";
    if (confirmation.value !== expectedConfirmation) {
      error.textContent = `确认文本必须准确等于 ${expectedConfirmation}。`;
      confirmation.focus();
      return;
    }
    state.grantBusy = true;
    submit.disabled = true;
    back.disabled = true;
    try {
      const payload = await request("/api/resource-grants", {
        method: "POST",
        mutation: true,
        body: JSON.stringify({
          ...draft,
          confirmation: confirmation.value,
          password: password.value,
          idempotency_key: state.grantPreview.idempotencyKey,
        }),
      });
      password.value = "";
      confirmation.value = "";
      state.grantResult = payload.command || payload;
      state.grantPreview = null;
      state.grantDraft = null;
      await loadGrantHistory(true).catch(() => {});
      renderActiveTab();
      announce("资源指令已提交，请核对状态回执。");
      document.querySelector("#grant-receipt")?.focus();
    } catch (requestError) {
      password.value = "";
      error.textContent = apiErrorMessage(requestError.code);
      password.focus();
    } finally {
      state.grantBusy = false;
      submit.disabled = false;
      back.disabled = false;
    }
  });
  preview.append(confirmForm);
  pane.append(preview);
  window.requestAnimationFrame(() => password.focus());
}

function renderGrantReceipt() {
  if (!state.grantResult) return null;
  const command = state.grantResult;
  const wrapper = element("div", { id: "grant-receipt", className: "command-receipt", attrs: { tabindex: "-1", role: "status" } });
  wrapper.append(element("h2", { text: "指令状态回执" }));
  const facts = element("dl", { className: "preview-facts" });
  [
    ["指令 ID", command.command_id || command.id || "—"],
    ["状态", command.status || "queued"],
    ["范围", command.target?.kind === "all" || command.scope === "all" ? "全部账号" : "指定账号"],
    ["资源", grantDescription(command)],
    ["目标数", command.target_count ?? command.targets ?? "—"],
    ["原因", command.reason || "—"],
    ["幂等键", command.idempotency_key || "—"],
    ["创建时间", formatDate(command.created_at_unix)],
  ].forEach(([term, value]) => facts.append(element("dt", { text: term }), element("dd", { text: value })));
  wrapper.append(facts, element("p", { className: "muted", text: "queued / pending 仅代表指令已登记；请到“Owner 任务与审计”查看 applied、failed 或 rejected 等最终状态。" }));
  return wrapper;
}

function renderGrants() {
  const pane = createPane("grants", "Owner 资源发放");
  const receipt = renderGrantReceipt();
  if (receipt) pane.append(receipt);
  const accountCount = normalizeList(state.accounts?.accounts).length;
  if (state.loadErrors.accounts) {
    pane.append(errorState(state.loadErrors.accounts, () => switchTab("grants", { force: true })));
    return pane;
  }
  if (!state.accounts) {
    pane.append(loadingState("正在加载可选账号投影…"));
    return pane;
  }
  const availabilityText = state.accounts.availability === "ready" ? `账号投影已就绪，共 ${accountCount} 个目标。` : "账号投影未就绪，暂不可创建资源指令。";
  pane.append(callout(state.accounts.availability === "ready" ? "info" : "warning", "执行前提", `${availabilityText} 指令由阿里云服务器执行器消费；此后台不直接改写玩家存档。`, state.accounts.availability === "ready" ? "status" : "alert"));
  if (state.grantPreview) {
    renderGrantPreview(pane);
    return pane;
  }
  const form = element("form", { className: "grant-form" });
  form.append(element("p", { className: "step-label", text: "步骤 1 / 4 · 预览" }), element("h2", { text: "创建资源发放预览" }));
  const targetKind = element("select", { name: "target_kind" });
  targetKind.append(new Option("指定账号", "user"), new Option(`全部账号（${accountCount} 个）`, "all"));
  const userId = element("select", { name: "user_id", required: true });
  accountOptions(userId);
  const grantType = element("select", { name: "grant_type" });
  grantType.append(new Option("抽卡券", "gacha_tickets"), new Option("卡牌副本", "card_copies"));
  const amount = element("input", { type: "number", name: "amount", required: true, min: "1", max: "100000", step: "1", value: "1" });
  const cardId = element("input", { name: "card_id", placeholder: "例如 animal_fox", autocomplete: "off" });
  const cardField = labeledControl("卡牌 ID", cardId, "仅“卡牌副本”需要。必须使用正式配置 ID。");
  const reason = element("textarea", { name: "reason", required: true, placeholder: "填写可审计的业务原因（4–200 字）", attrs: { maxlength: "200", rows: "4" } });
  const error = element("p", { className: "error", attrs: { role: "alert", tabindex: "-1" } });
  const preview = element("button", { className: "primary", type: "submit", text: "生成预览" });
  form.append(
    labeledControl("目标范围", targetKind),
    labeledControl("指定账号", userId),
    labeledControl("资源类型", grantType),
    labeledControl("数量", amount),
    cardField,
    labeledControl("发放原因", reason),
    error,
    preview,
  );
  function updateConditionalFields() {
    const all = targetKind.value === "all";
    userId.disabled = all;
    userId.required = !all;
    const cardCopies = grantType.value === "card_copies";
    cardId.disabled = !cardCopies;
    cardId.required = cardCopies;
    cardField.hidden = !cardCopies;
  }
  targetKind.addEventListener("change", updateConditionalFields);
  grantType.addEventListener("change", updateConditionalFields);
  updateConditionalFields();
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const draft = buildGrantDraft(form);
    const message = validateGrantDraft(draft);
    if (message) {
      error.textContent = message;
      error.focus?.();
      return;
    }
    state.grantDraft = draft;
    state.grantPreview = { draft, idempotencyKey: generateIdempotencyKey() };
    renderActiveTab();
    announce(`预览已生成，目标 ${grantTargetCount(draft)} 个账号。`);
  });
  const content = element("div", { className: "grant-layout" });
  content.append(form);
  const guardrails = element("div", { className: "guardrail-list" });
  [
    ["只建指令", "后台只写入受保护命令目录，不直接修改玩家权威存档。"],
    ["幂等保护", "同一预览固定使用一个 idempotency_key，网络重试不得重复发放。"],
    ["全服确认", "全服发放显示快照目标数，并强制输入 SEND TO ALL。"],
    ["状态回执", "提交后必须跟踪执行状态与审计记录，不能把 queued 当成到账。"],
  ].forEach(([title, description]) => {
    const item = element("article", { className: "guardrail" });
    item.append(element("strong", { text: title }), element("p", { text: description }));
    guardrails.append(item);
  });
  content.append(panel("安全护栏", guardrails, "Owner 专属"));
  pane.append(content);
  return pane;
}

async function loadGrantHistory(force = false) {
  if (state.grantsLoaded && !force) return;
  state.loadErrors.grants = "";
  try {
    const payload = await request("/api/resource-grants");
    state.grants = normalizeList(payload.entries);
    state.grantsLoaded = true;
  } catch (error) {
    state.grantsLoaded = false;
    state.loadErrors.grants = apiErrorMessage(error.code);
    throw error;
  }
}

async function loadManagement(force = false) {
  if (state.managementLoaded && !force) return;
  state.loadErrors.management = "";
  try {
    const [usersPayload, auditPayload] = await Promise.all([request("/api/admins"), request("/api/audit?limit=80")]);
    state.users = normalizeList(usersPayload.users);
    state.audit = normalizeList(auditPayload.entries);
    state.managementLoaded = true;
  } catch (error) {
    state.managementLoaded = false;
    state.loadErrors.management = apiErrorMessage(error.code);
    throw error;
  }
}

function renderTasks() {
  const pane = createPane("tasks", "Owner 任务与审计");
  if (state.loadErrors.grants || state.loadErrors.management) {
    pane.append(errorState(state.loadErrors.grants || state.loadErrors.management, () => switchTab("tasks", { force: true })));
    return pane;
  }
  if (!state.grantsLoaded || !state.managementLoaded) {
    pane.append(loadingState("正在加载资源任务与审计记录…"));
    return pane;
  }
  const grants = state.grants;
  const grantColumns = ["指令 ID", "状态", "目标", "资源", "原因", "目标数", "创建者", "创建时间", "错误/备注"].map((label) => ({ label }));
  const grantRows = grants.map((entry) => {
    const status = String(entry.status || "unknown");
    const statusKind = ["applied", "processed", "completed", "success"].includes(status) ? "good" : ["failed", "rejected"].includes(status) ? "danger" : "warning";
    const target = entry.target?.kind === "all" || entry.scope === "all" ? "全部账号" : compactUserId(entry.target?.user_id || entry.user_id || entry.target_user_ids?.[0]);
    return [
      compactUserId(entry.command_id || entry.id),
      tag(status, statusKind),
      target,
      grantDescription(entry),
      entry.reason || "—",
      formatNumber(entry.target_count),
      entry.actor || entry.created_by || "—",
      formatDate(entry.created_at_unix),
      entry.error || entry.detail || "—",
    ];
  });
  pane.append(panel("资源指令任务", grantRows.length ? dataTable("资源指令任务与状态", grantColumns, grantRows) : emptyState("尚无资源发放指令。"), "queued 不等于已到账；以执行器终态为准"));
  const auditList = element("div", { className: "audit-list" });
  if (!state.audit.length) auditList.append(emptyState("尚无权限审计事件。"));
  state.audit.forEach((entry) => {
    const item = element("article", { className: "audit-entry" });
    const rawTime = Number(entry.at || 0);
    const auditTime = rawTime > 100000000000 ? Math.floor(rawTime / 1000) : rawTime;
    item.append(
      element("strong", { text: entry.event || "audit" }),
      document.createTextNode(` · ${entry.actor || "系统"} → ${entry.target || "-"} · ${formatDate(auditTime)}`),
    );
    if (entry.detail) item.append(document.createElement("br"), document.createTextNode(entry.detail));
    auditList.append(item);
  });
  pane.append(panel("权限审计", auditList, "不记录密码、令牌或 Cookie"));
  return pane;
}

function nativeConfirmDialog({ title, description, confirmText = "确认操作", danger = true }) {
  if (typeof HTMLDialogElement === "undefined") return Promise.resolve(window.confirm(`${title}\n\n${description}`));
  return new Promise((resolve) => {
    const returnFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const dialog = element("dialog", { className: "confirm-dialog", attrs: { "aria-labelledby": "confirm-dialog-title", "aria-describedby": "confirm-dialog-description" } });
    const form = element("form", { attrs: { method: "dialog" } });
    form.append(element("h2", { id: "confirm-dialog-title", text: title }), element("p", { id: "confirm-dialog-description", text: description }));
    const actions = element("div", { className: "form-actions" });
    const cancel = element("button", { className: "secondary", type: "button", text: "取消" });
    const confirm = element("button", { className: danger ? "danger-solid" : "primary", type: "button", text: confirmText });
    actions.append(cancel, confirm);
    form.append(actions);
    dialog.append(form);
    document.body.append(dialog);
    const finish = (value) => {
      dialog.close();
      dialog.remove();
      returnFocus?.focus();
      resolve(value);
    };
    cancel.addEventListener("click", () => finish(false));
    confirm.addEventListener("click", () => finish(true));
    dialog.addEventListener("cancel", (event) => { event.preventDefault(); finish(false); });
    dialog.showModal();
    cancel.focus();
  });
}

async function updateUser(username, patch, description) {
  const confirmed = await nativeConfirmDialog({ title: "确认管理员危险操作", description, confirmText: "确认并执行" });
  if (!confirmed) return;
  try {
    await request(`/api/admins/${encodeURIComponent(username)}`, { method: "PATCH", mutation: true, body: JSON.stringify(patch) });
    await loadManagement(true);
    renderActiveTab();
    announce(`管理员 ${username} 已更新。`);
  } catch (error) {
    announce(apiErrorMessage(error.code));
    window.alert(apiErrorMessage(error.code));
  }
}

async function revokeSessions(username) {
  const confirmed = await nativeConfirmDialog({ title: "撤销全部会话？", description: `这会立即使 ${username} 的全部现有登录会话失效，且不可撤销。`, confirmText: "撤销全部会话" });
  if (!confirmed) return;
  try {
    await request(`/api/admins/${encodeURIComponent(username)}/revoke-sessions`, { method: "POST", mutation: true, body: JSON.stringify({}) });
    await loadManagement(true);
    renderActiveTab();
    announce(`${username} 的全部会话已撤销。`);
  } catch (error) {
    window.alert(apiErrorMessage(error.code));
  }
}

function renderPermissions() {
  const pane = createPane("permissions", "Owner 权限");
  if (state.loadErrors.management) {
    pane.append(errorState(state.loadErrors.management, () => switchTab("permissions", { force: true })));
    return pane;
  }
  if (!state.managementLoaded) {
    pane.append(loadingState("正在加载后台授权成员…"));
    return pane;
  }
  const grid = element("div", { className: "management-grid" });
  const createForm = element("form", { className: "manage-create" });
  createForm.append(element("p", { className: "step-label", text: "Owner 专属" }), element("h2", { text: "授权新成员" }), element("p", { className: "hint", text: "不开放自行注册。创建前会显示二次确认，密码不会写入审计。" }));
  const username = element("input", { name: "username", required: true, placeholder: "3–32 位英文、数字或 ._-", autocomplete: "off" });
  const password = element("input", { name: "password", type: "password", required: true, autocomplete: "new-password", placeholder: "至少 12 位密码" });
  const role = element("select", { name: "role" });
  role.append(new Option("Analyst（只读数据）", "analyst"), new Option("Owner（可执行管理与资源指令）", "owner"));
  const error = element("p", { className: "error", attrs: { role: "alert", tabindex: "-1" } });
  const submit = element("button", { className: "primary", type: "submit", text: "预览并创建授权账号" });
  createForm.append(labeledControl("用户名", username), labeledControl("初始密码", password), labeledControl("角色", role), error, submit);
  createForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    error.textContent = "";
    const confirmed = await nativeConfirmDialog({
      title: "确认创建管理员账号？",
      description: `将创建 ${username.value}，角色为 ${roleLabel(role.value)}。该账号将获得后台访问权。`,
      confirmText: "确认创建",
    });
    if (!confirmed) return;
    submit.disabled = true;
    try {
      await request("/api/admins", { method: "POST", mutation: true, body: JSON.stringify({ username: username.value, password: password.value, role: role.value }) });
      password.value = "";
      username.value = "";
      await loadManagement(true);
      renderActiveTab();
      announce("管理员账号已创建。");
    } catch (requestError) {
      password.value = "";
      error.textContent = apiErrorMessage(requestError.code);
    } finally {
      submit.disabled = false;
    }
  });
  grid.append(panel("创建授权", createForm));
  const columns = ["用户名", "角色", "状态", "更新于", "危险操作"].map((label) => ({ label }));
  const rows = state.users.map((user) => {
    const actions = element("div", { className: "actions" });
    const nextStatus = user.status === "active" ? "disabled" : "active";
    const toggle = element("button", { className: user.status === "active" ? "danger" : "secondary", type: "button", text: user.status === "active" ? "停用" : "启用" });
    toggle.addEventListener("click", () => updateUser(user.username, { status: nextStatus }, `${user.username} 将被设为 ${nextStatus}。停用会阻止其继续登录。`));
    const nextRole = user.role === "owner" ? "analyst" : "owner";
    const changeRole = element("button", { className: "secondary", type: "button", text: user.role === "owner" ? "降为 Analyst" : "升为 Owner" });
    changeRole.addEventListener("click", () => updateUser(user.username, { role: nextRole }, `${user.username} 的角色将改为 ${roleLabel(nextRole)}，权限范围会立即变化。`));
    const revoke = element("button", { className: "secondary", type: "button", text: "撤销会话" });
    revoke.addEventListener("click", () => revokeSessions(user.username));
    actions.append(toggle, changeRole, revoke);
    const updated = Number(user.updated_at || 0) > 100000000000 ? Number(user.updated_at) / 1000 : user.updated_at;
    return [user.username, roleLabel(user.role), tag(user.status, user.status === "active" ? "good" : "warning"), formatDate(updated), actions];
  });
  grid.append(panel("已授权成员", rows.length ? dataTable("后台授权成员", columns, rows) : emptyState("尚未授权其他成员。")));
  pane.append(callout("warning", "最小权限原则", "Analyst 仅可查看总览、动物平衡和阵容库；资源发放、任务审计和权限管理只向 Owner 显示，并由服务端再次校验。"), grid);
  return pane;
}

function createPane(name, title) {
  const pane = element("section", {
    className: "tab-pane",
    id: `panel-${name}`,
    attrs: { role: "tabpanel", tabindex: "-1", "aria-labelledby": `tab-${name}` },
  });
  const heading = element("header", { className: "view-heading" });
  heading.append(
    element("p", { className: "eyebrow", text: OWNER_TABS.has(name) ? "OWNER CONTROL" : "LIVE OPS MODULE" }),
    element("h1", { className: "page-title", text: title, attrs: { tabindex: "-1" } }),
  );
  pane.append(heading);
  return pane;
}

function focusPageHeading() {
  window.requestAnimationFrame(() => document.querySelector("#tab-content .page-title")?.focus());
}

function renderActiveTab() {
  const content = document.querySelector("#tab-content");
  if (!content) return;
  clear(content);
  let pane;
  if (state.activeTab === "overview") pane = renderOverview();
  if (state.activeTab === "animals") pane = renderAnimals();
  if (state.activeTab === "accounts") pane = renderAccounts();
  if (state.activeTab === "grants") pane = renderGrants();
  if (state.activeTab === "tasks") pane = renderTasks();
  if (state.activeTab === "permissions") pane = renderPermissions();
  content.append(pane || renderOverview());
  document.querySelectorAll('[role="tab"]').forEach((button) => {
    const selected = button.dataset.tab === state.activeTab;
    button.classList.toggle("active", selected);
    button.setAttribute("aria-selected", String(selected));
    button.tabIndex = selected ? 0 : -1;
  });
}

async function switchTab(name, options = {}) {
  if (OWNER_TABS.has(name) && state.session?.role !== "owner") return;
  state.activeTab = name;
  renderActiveTab();
  try {
    if (name === "accounts" || name === "grants") await loadAccounts(Boolean(options.force));
    if (name === "tasks") await Promise.all([loadGrantHistory(Boolean(options.force)), loadManagement(Boolean(options.force))]);
    if (name === "permissions") await loadManagement(Boolean(options.force));
  } catch {
    // The loaders record a scoped error state rendered below.
  }
  renderActiveTab();
  if (options.focus !== false) focusPageHeading();
  announce(`${TAB_DEFINITIONS.find(([key]) => key === name)?.[1] || name}已打开。`);
}

function createTabs() {
  const tabs = element("nav", { className: "tabs", attrs: { role: "tablist", "aria-label": "运营后台主导航" } });
  const definitions = TAB_DEFINITIONS.filter(([name]) => !OWNER_TABS.has(name) || state.session?.role === "owner");
  definitions.forEach(([name, labelText], index) => {
    const selected = name === state.activeTab;
    const button = element("button", {
      id: `tab-${name}`,
      className: `nav-button${selected ? " active" : ""}`,
      type: "button",
      text: labelText,
      dataset: { tab: name },
      attrs: { role: "tab", "aria-controls": `panel-${name}`, "aria-selected": String(selected), tabindex: selected ? "0" : "-1" },
    });
    button.addEventListener("click", () => switchTab(name));
    button.addEventListener("keydown", (event) => {
      const keys = ["ArrowLeft", "ArrowRight", "Home", "End"];
      if (!keys.includes(event.key)) return;
      event.preventDefault();
      const all = Array.from(tabs.querySelectorAll('[role="tab"]'));
      let nextIndex = index;
      if (event.key === "ArrowLeft") nextIndex = (index - 1 + all.length) % all.length;
      if (event.key === "ArrowRight") nextIndex = (index + 1) % all.length;
      if (event.key === "Home") nextIndex = 0;
      if (event.key === "End") nextIndex = all.length - 1;
      const next = all[nextIndex];
      next.focus();
      switchTab(next.dataset.tab, { focus: false });
    });
    tabs.append(button);
  });
  return tabs;
}

function showLogin(message = "") {
  clear(app);
  const shell = element("section", { className: "login-shell", attrs: { "aria-labelledby": "login-title" } });
  shell.append(element("p", { className: "eyebrow", text: "JUNGLE LAW · PRIVATE ACCESS" }), element("h1", { id: "login-title", text: "运营数据后台" }), element("p", { className: "hint", text: "仅 Owner 或由 Owner 授权的分析人员可访问。" }));
  const form = element("form");
  const username = element("input", { name: "username", required: true, autocomplete: "username", placeholder: "管理员用户名" });
  const password = element("input", { name: "password", type: "password", required: true, autocomplete: "current-password", placeholder: "管理员密码" });
  const error = element("p", { className: "error", text: message, attrs: { role: "alert", "aria-live": "assertive" } });
  const submit = element("button", { className: "primary", type: "submit", text: "安全登录" });
  form.append(labeledControl("用户名", username), labeledControl("密码", password), error, submit);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    submit.disabled = true;
    error.textContent = "";
    try {
      const result = await request("/api/auth/login", { method: "POST", body: JSON.stringify({ username: username.value, password: password.value }) });
      password.value = "";
      state.session = result.user;
      state.csrfToken = result.csrf_token;
      state.activeTab = "overview";
      await showDashboard();
      announce("登录成功。");
    } catch (requestError) {
      error.textContent = apiErrorMessage(requestError.code);
      password.value = "";
      password.focus();
    } finally {
      submit.disabled = false;
    }
  });
  shell.append(form);
  app.append(shell);
  window.requestAnimationFrame(() => username.focus());
}

async function refreshDashboard() {
  const button = document.querySelector("#refresh-dashboard");
  const originalLabel = button?.textContent || "刷新数据";
  if (button) {
    button.disabled = true;
    button.textContent = "刷新中…";
    button.setAttribute("aria-busy", "true");
  }
  try {
    state.dashboard = await request("/api/dashboard");
    state.accounts = null;
    state.grants = [];
    state.grantsLoaded = false;
    state.users = [];
    state.audit = [];
    state.managementLoaded = false;
    state.loadErrors = {};
    await switchTab(state.activeTab, { force: true, focus: false });
    announce("数据已刷新。");
  } catch (error) {
    if (error.status === 401) {
      clearSensitiveState();
      showLogin("登录已失效，请重新登录。");
      return;
    }
    announce(apiErrorMessage(error.code));
  } finally {
    if (button) {
      button.disabled = false;
      button.textContent = originalLabel;
      button.removeAttribute("aria-busy");
    }
  }
}

function clearSensitiveState() {
  state.session = null;
  state.csrfToken = "";
  state.dashboard = null;
  state.accounts = null;
  state.grants = [];
  state.grantsLoaded = false;
  state.users = [];
  state.audit = [];
  state.managementLoaded = false;
  state.animalQuery = "";
  state.grantDraft = null;
  state.grantPreview = null;
  state.grantResult = null;
  state.loadErrors = {};
}

async function logoutCurrentUser() {
  try {
    await request("/api/auth/logout", { method: "POST", mutation: true, body: JSON.stringify({}) });
  } catch {
    // The local cookie may already have expired; clear rendered sensitive data either way.
  }
  clearSensitiveState();
  showLogin();
  announce("已退出登录。");
}

async function showDashboard() {
  try {
    state.dashboard = await request("/api/dashboard");
  } catch (error) {
    if (error.status === 401) clearSensitiveState();
    showLogin(error.status === 401 ? "登录已失效，请重新登录。" : apiErrorMessage(error.code));
    return;
  }
  clear(app);
  const shell = element("section", { className: "dashboard" });
  const masthead = element("header", { className: "masthead" });
  const mastheadInner = element("div", { className: "masthead-inner" });
  const title = element("div", { className: "masthead-brand" });
  title.append(
    element("span", { className: "brand-mark", text: "JL", attrs: { "aria-hidden": "true" } }),
    element("div", { className: "brand-copy" }),
  );
  title.lastElementChild.append(
    element("p", { className: "eyebrow", text: "JUNGLE LAW · LIVE OPS" }),
    element("strong", { className: "product-title", text: "运营数据后台" }),
    element("span", { className: "product-subtitle", text: "统计 · 平衡 · 阵容 · 指令" }),
  );
  const account = element("div", { className: "account-actions" });
  account.append(element("span", { className: "account-chip", text: `${state.session.username} · ${roleLabel(state.session.role)}` }));
  const refresh = element("button", { id: "refresh-dashboard", className: "secondary", type: "button", text: "刷新数据" });
  const logout = element("button", { className: "secondary", type: "button", text: "退出登录" });
  refresh.addEventListener("click", refreshDashboard);
  logout.addEventListener("click", logoutCurrentUser);
  account.append(refresh, logout);
  mastheadInner.append(title, createTabs(), account);
  masthead.append(mastheadInner);
  const content = element("div", { id: "tab-content" });
  const body = element("div", { className: "dashboard-body" });
  body.append(content);
  shell.append(masthead, body);
  app.append(shell);
  renderActiveTab();
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
