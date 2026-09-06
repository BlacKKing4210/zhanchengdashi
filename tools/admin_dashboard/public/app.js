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
  animalBattleType: "all",
  accountQuery: "",
  grantAccountQuery: "",
  selectedGrantUserIds: new Set(),
  grantFormValues: { grant_type: "gacha_tickets", amount: "1", card_id: "", reason: "" },
  grantDraft: null,
  grantPreview: null,
  grantResult: null,
  grantBusy: false,
  loadErrors: {},
};

const OWNER_TABS = new Set(["grants", "tasks", "permissions"]);
const MAX_SELECTED_GRANT_TARGETS = 500;
const TAB_DEFINITIONS = [
  ["overview", "总览"],
  ["animals", "动物平衡"],
  ["roles", "角色"],
  ["decks", "阵容库"],
  ["grants", "资源发放"],
  ["tasks", "发放记录"],
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

function temporaryPlayerName(value) {
  const suffix = String(value || "").replace(/[^A-Za-z0-9]/g, "").slice(-4).toUpperCase();
  return `新玩家${suffix || "未知"}`;
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
    all_completed_authenticated_battles_by_type: "所有已完成且可归属到已登录账号的战斗均纳入统计，并按战斗类型分别复核。",
  };
  return labels[value] || "服务器生成的脱敏只读统计投影。";
}

function battleTypeLabel(value) {
  return ({
    all: "全部战斗（混合概览）",
    classic_ranked_ai: "经典排位 AI",
    multiplayer_1v1: "多人 1v1",
    multiplayer_2v2: "多人 2v2",
    multiplayer_3v3: "多人 3v3",
    free_for_all_6: "六人乱斗",
    legacy_unknown: "历史未分类",
  })[value] || value || "历史未分类";
}

function analyticsAuthorityLabel(value) {
  return ({
    server_authoritative: "服务器权威",
    authenticated_client_reported: "已登录客户端上报",
    legacy_server_recorded: "历史服务器记录",
  })[value] || "历史记录";
}

function rankLabel(value) {
  return ({ bronze: "青铜", silver: "白银", gold: "黄金", platinum: "铂金", diamond: "钻石", star: "星耀", king: "王者" })[value] || "未定段";
}

function cardNameMap() {
  const result = { gold_mine_card: "金矿", defense_watch_tower: "防御塔" };
  Object.assign(result, state.accounts?.card_names || {});
  normalizeList(state.dashboard?.animals).forEach((animal) => {
    if (animal.card_id && animal.name) result[animal.card_id] = animal.name;
  });
  return result;
}

function cardDisplayName(cardId) {
  return cardNameMap()[cardId] || `未命名卡牌（${cardId}）`;
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
    target_confirmation_required: "指定账号二次确认文本必须准确等于 SEND。",
    invalid_preview_token: "预览凭证无效，请返回并重新生成预览。",
    invalid_preview_request: "提交内容与服务器预览不一致，请返回并重新生成预览。",
    preview_expired: "服务器预览已过期，请返回并重新生成预览。",
    preview_stale: "目标账号集合已变化，请刷新账号投影并重新生成预览。",
    preview_session_mismatch: "预览不属于当前登录会话，请重新登录并生成预览。",
    target_not_found: "指定账号不在最新账号投影中，请刷新后重新预览。",
    selected_targets_required: "多选发放至少需要勾选 2 个玩家。",
    selected_target_limit: "单次最多勾选 500 个玩家。",
    duplicate_target: "玩家选择中存在重复 ID，请刷新后重试。",
    all_scope_required: "当前选择已覆盖全部账号，必须使用全账号强确认流程。",
    no_target_accounts: "最新账号投影中没有可发放目标。",
    invalid_idempotency_key: "幂等键无效，请返回并重新生成预览。",
    invalid_grant_amount: "资源数量无效。",
    invalid_card_id: "卡牌 ID 无效。",
    invalid_reason: "请填写可审计的发放原因。",
    unsupported_resource: "资源类型不受支持。",
    idempotency_conflict: "该幂等键已用于不同指令，请重新预览。",
    terminal_state_conflict: "该指令同时存在冲突的终态回执，已停止提交，请联系运维核对。",
    invalid_terminal_entry: "该指令的终态回执无效，已停止提交，请联系运维核对。",
    command_reconciliation_failed: "指令状态竞态未能安全收敛，已停止提交，请联系运维核对。",
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
    const identity = element("div");
    identity.append(
      element("strong", { text: battleTypeLabel(match.battle_type) }),
      element("span", { className: "rank-id", text: `${match.map_id || "未标记地图"} · ${analyticsAuthorityLabel(match.analytics_authority)}` }),
    );
    summary.append(identity, element("span", { className: "muted", text: formatDate(match.finalized_at_unix || match.started_at_unix) }));
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
  return panel("最近对局", list, "已标记战斗类型、统计权威与终局结果");
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
  const completedTypes = normalizeList(state.dashboard?.battle_types).filter((entry) => Number(entry.matches || 0) > 0);
  const validTypes = new Set(["all", ...completedTypes.map((entry) => entry.battle_type)]);
  if (!validTypes.has(state.animalBattleType)) state.animalBattleType = "all";
  const selectedType = state.animalBattleType;
  const sourceAnimals = selectedType === "all"
    ? state.dashboard?.animals
    : state.dashboard?.animals_by_battle_type?.[selectedType];
  const allAnimals = normalizeList(sourceAnimals).slice().sort((a, b) => {
    const left = toNumber(a.average_placement);
    const right = toNumber(b.average_placement);
    return (left ?? Number.POSITIVE_INFINITY) - (right ?? Number.POSITIVE_INFINITY);
  });

  const typeBar = element("form", { className: "battle-type-filter" });
  const typeSelect = element("select", { attrs: { "aria-label": "选择战斗统计类型" } });
  typeSelect.append(new Option("全部战斗（仅作混合概览）", "all"));
  completedTypes.forEach((entry) => typeSelect.append(new Option(`${battleTypeLabel(entry.battle_type)} · ${formatNumber(entry.matches)} 场`, entry.battle_type)));
  typeSelect.value = selectedType;
  typeSelect.addEventListener("change", () => {
    state.animalBattleType = typeSelect.value;
    state.animalQuery = "";
    renderActiveTab();
  });
  typeBar.append(labeledControl("战斗类型", typeSelect, "平衡结论应优先在单一战斗类型内比较。"));
  pane.append(panel("统计分组", typeBar, battleTypeLabel(selectedType)));
  if (!allAnimals.length) {
    pane.append(panel("动物平均排名", emptyState(`“${battleTypeLabel(selectedType)}”暂无完成对局的动物排名样本。`)));
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
    metric("战斗类型", selectedType === "all" ? "混合" : battleTypeLabel(selectedType), "名次越小表现越好"),
  );
  pane.append(metrics);
  pane.append(callout(
    selectedType === "all" ? "warning" : "info",
    selectedType === "all" ? "混合口径仅供总览" : "单类型平衡复核",
    selectedType === "all"
      ? "不同战斗规模不能直接合并得出调整结论。请选择具体战斗类型，再结合平均名次、标准化得分与置信度提出增强或削弱建议。"
      : `当前仅比较“${battleTypeLabel(selectedType)}”。任何数值调整仍须走配置评审、验证和发布流程，后台不会直接改写游戏配置。`,
  ));
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
  const rankingPanel = panel("动物平均排名", rankingContent, `${battleTypeLabel(selectedType)} · 显示 ${animals.length} / ${allAnimals.length} · 按平均名次升序`, { className: "ranking-panel" });
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
    const availableUserIds = new Set(normalizeList(state.accounts?.accounts).map((account) => String(account.user_id || "")).filter(Boolean));
    state.selectedGrantUserIds = new Set([...state.selectedGrantUserIds].filter((userId) => availableUserIds.has(userId)));
  } catch (error) {
    state.accounts = null;
    state.loadErrors.accounts = apiErrorMessage(error.code);
    throw error;
  }
}

function accountDisplayName(account) {
  const username = String(account?.username || "").trim();
  return username || temporaryPlayerName(account?.user_id);
}

function accountUsesTemporaryName(account) {
  return !String(account?.username || "").trim();
}

function accountMatchesQuery(account, query) {
  return !query
    || accountDisplayName(account).toLowerCase().includes(query)
    || String(account.user_id || "").toLowerCase().includes(query)
    || String(account.masked_account || "").toLowerCase().includes(query);
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
    const chip = element("span", { className: "card-chip", text: cardDisplayName(cardId), title: cardId });
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

function sortedAccounts() {
  const rankOrder = new Map(["bronze", "silver", "gold", "platinum", "diamond", "star", "king"].map((rank, index) => [rank, index]));
  return normalizeList(state.accounts?.accounts).slice().sort((left, right) => {
    const leftRank = rankOrder.get(left.rank?.rank_key) ?? -1;
    const rightRank = rankOrder.get(right.rank?.rank_key) ?? -1;
    return rightRank - leftRank
      || Number(right.rank?.rank_stars || 0) - Number(left.rank?.rank_stars || 0)
      || Number(right.rank?.elo || 0) - Number(left.rank?.elo || 0)
      || String(left.user_id || "").localeCompare(String(right.user_id || ""));
  });
}

function filteredAccounts() {
  const query = state.accountQuery.trim().toLowerCase();
  return sortedAccounts().filter((account) => accountMatchesQuery(account, query));
}

function accountSearchToolbar(labelText) {
  const toolbar = element("form", { className: "filter-bar", attrs: { role: "search" } });
  const search = element("input", { type: "search", value: state.accountQuery, placeholder: "搜索玩家名称、完整玩家 ID 或脱敏账号", attrs: { "aria-label": labelText } });
  const submit = element("button", { className: "secondary", type: "submit", text: "搜索" });
  const reset = element("button", { className: "ghost", type: "button", text: "清除" });
  toolbar.append(search, submit, reset);
  toolbar.addEventListener("submit", (event) => {
    event.preventDefault();
    state.accountQuery = search.value.trim();
    renderActiveTab();
  });
  reset.addEventListener("click", () => {
    state.accountQuery = "";
    renderActiveTab();
  });
  return toolbar;
}

function accountIdentity(account) {
  const identity = element("span", { className: "rank-name", text: accountDisplayName(account) });
  const prefix = accountUsesTemporaryName(account) ? "系统临时名称" : "完整玩家 ID";
  identity.append(element("small", { className: "rank-id", text: `${prefix} · ${account.user_id || "—"}` }));
  return identity;
}

function directGrantButton(account) {
  if (state.session?.role !== "owner") return element("span", { className: "muted", text: "只读" });
  const button = element("button", { className: "primary compact-action", type: "button", text: "发放资源" });
  button.addEventListener("click", () => {
    state.selectedGrantUserIds = new Set([account.user_id]);
    state.grantAccountQuery = "";
    state.grantFormValues = { grant_type: "gacha_tickets", amount: "1", card_id: "", reason: "" };
    state.grantDraft = null;
    state.grantPreview = null;
    state.grantResult = null;
    switchTab("grants");
  });
  return button;
}

function renderRoles() {
  const pane = createPane("roles", "角色");
  if (state.loadErrors.accounts) {
    pane.append(errorState(state.loadErrors.accounts, () => switchTab("roles", { force: true })));
    return pane;
  }
  if (!state.accounts) {
    pane.append(loadingState("正在加载全部账号…"));
    return pane;
  }
  if (state.accounts.availability !== "ready") {
    pane.append(callout("warning", "账号投影未就绪", "后台不会读取权威账号存档；请等待阿里云游戏服生成脱敏账号投影。", "alert"));
    return pane;
  }
  const accounts = sortedAccounts();
  const filtered = filteredAccounts();
  const summary = element("div", { className: "section-summary" });
  summary.append(element("p", { text: `全部 ${accounts.length} 个账号，当前显示 ${filtered.length} 个。投影时间：${formatDate(state.accounts.generated_at_unix)}。` }), tag("完整脱敏账号投影", "good"));
  pane.append(panel("查找角色", accountSearchToolbar("搜索全部角色账号"), "所有账号均在同一列表中展示"), summary);
  if (!filtered.length) {
    pane.append(panel("全部角色", emptyState("没有匹配的账号。")));
    return pane;
  }
  const columns = ["#", "玩家名称 / ID", "存储段位", "Elo", "抽卡券", "更新时间", "操作"].map((label) => ({ label }));
  const rows = filtered.map((account) => {
    const storageIndex = accounts.findIndex((entry) => entry.user_id === account.user_id) + 1;
    return [
      element("span", { className: "rank-number", text: `#${storageIndex}` }),
      accountIdentity(account),
      `${rankLabel(account.rank?.rank_key)} ${formatNumber(account.rank?.rank_stars)} 星`,
      formatNumber(account.rank?.elo),
      formatNumber(account.resources?.gacha_tickets),
      formatDate(account.updated_at_unix),
      directGrantButton(account),
    ];
  });
  pane.append(panel("全部角色", dataTable("全部角色账号", columns, rows, { className: "all-accounts-table", tableClassName: "rank-table" }), "按存储段位、星数和 Elo 排序"));
  return pane;
}

function renderDecks() {
  const pane = createPane("decks", "阵容库");
  if (state.loadErrors.accounts) {
    pane.append(errorState(state.loadErrors.accounts, () => switchTab("decks", { force: true })));
    return pane;
  }
  if (!state.accounts) {
    pane.append(loadingState("正在加载保存阵容…"));
    return pane;
  }
  if (state.accounts.availability !== "ready") {
    pane.append(callout("warning", "阵容投影未就绪", "请等待阿里云游戏服生成完整保存阵容投影。", "alert"));
    return pane;
  }
  const allAccounts = sortedAccounts();
  const accounts = allAccounts.filter((account) => normalizeList(account.deck).length > 0);
  const query = state.accountQuery.trim().toLowerCase();
  const filtered = accounts.filter((account) => accountMatchesQuery(account, query));
  pane.append(
    panel("查找阵容", accountSearchToolbar("搜索保存阵容"), "卡牌以配置中的中文名显示"),
    callout("info", "排行口径", `共 ${accounts.length} 套已保存阵容（账号总数 ${allAccounts.length}）；按存储段位、星数和 Elo 从高到低排列，不按近期胜率重排。`),
  );
  const columns = ["存储排名", "角色账号", "存储段位", "阵容卡牌", "段位镜像", "保存时间"].map((label) => ({ label }));
  const rows = filtered.map((account) => {
    const storageIndex = accounts.findIndex((entry) => entry.user_id === account.user_id) + 1;
    return [
      element("span", { className: "rank-number", text: `#${storageIndex}` }),
      accountIdentity(account),
      `${rankLabel(account.rank?.rank_key)} ${formatNumber(account.rank?.rank_stars)} 星 · Elo ${formatNumber(account.rank?.elo)}`,
      renderDeck(account),
      renderRankMirrors(account.rank_mirrors),
      formatDate(account.updated_at_unix),
    ];
  });
  pane.append(panel("保存阵容列表", rows.length ? dataTable("按存储段位排行的全部阵容", columns, rows, { className: "deck-list-table" }) : emptyState("没有匹配的保存阵容。"), `显示 ${filtered.length} / ${accounts.length}`));
  return pane;
}

function generateIdempotencyKey() {
  if (window.crypto?.randomUUID) return window.crypto.randomUUID();
  return `grant-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function grantFilteredAccounts() {
  const query = state.grantAccountQuery.trim().toLowerCase();
  return sortedAccounts().filter((account) => accountMatchesQuery(account, query));
}

function selectedGrantIds() {
  const availableUserIds = new Set(normalizeList(state.accounts?.accounts).map((account) => String(account.user_id || "")).filter(Boolean));
  return [...state.selectedGrantUserIds].filter((userId) => availableUserIds.has(userId)).sort();
}

function grantSelectionToolbar(accounts, filtered) {
  const toolbar = element("div", { className: "grant-player-toolbar" });
  const searchForm = element("form", { className: "grant-player-search", attrs: { role: "search" } });
  const search = element("input", {
    type: "search",
    value: state.grantAccountQuery,
    placeholder: "搜索玩家名称、完整玩家 ID 或脱敏账号",
    attrs: { "aria-label": "搜索资源发放玩家" },
  });
  const searchButton = element("button", { className: "secondary", type: "submit", text: "搜索" });
  const resetSearch = element("button", { className: "ghost", type: "button", text: "清除搜索" });
  searchForm.append(search, searchButton, resetSearch);
  searchForm.addEventListener("submit", (event) => {
    event.preventDefault();
    state.grantAccountQuery = search.value.trim();
    renderActiveTab();
  });
  resetSearch.addEventListener("click", () => {
    state.grantAccountQuery = "";
    renderActiveTab();
  });

  const selectedIds = selectedGrantIds();
  const actions = element("div", { className: "grant-selection-actions" });
  const selectVisible = element("button", {
    className: "secondary",
    type: "button",
    text: "全选当前结果",
    disabled: filtered.length === 0 || filtered.every((account) => state.selectedGrantUserIds.has(account.user_id)),
  });
  const clearSelection = element("button", {
    className: "ghost",
    type: "button",
    text: "清空选择",
    disabled: selectedIds.length === 0,
  });
  selectVisible.addEventListener("click", () => {
    filtered.forEach((account) => state.selectedGrantUserIds.add(account.user_id));
    announce(`已选择 ${selectedGrantIds().length} 个玩家。`);
    renderActiveTab();
  });
  clearSelection.addEventListener("click", () => {
    state.selectedGrantUserIds.clear();
    announce("已清空玩家选择。");
    renderActiveTab();
  });
  actions.append(
    element("strong", {
      className: "grant-selection-summary",
      text: `已选择 ${selectedIds.length} / 全部 ${accounts.length}`,
      attrs: { role: "status", "aria-live": "polite" },
    }),
    selectVisible,
    clearSelection,
  );
  toolbar.append(searchForm, actions);
  return toolbar;
}

function grantPlayerTable(accounts, filtered) {
  if (!filtered.length) return emptyState("没有匹配的玩家；已勾选的其他玩家仍会保留。请清除搜索后查看。", "玩家选择为空");
  const region = element("div", {
    className: "table-scroll grant-player-table-scroll",
    attrs: { role: "region", tabindex: "0", "aria-label": "资源发放玩家明细与选择" },
  });
  const tableNode = element("table", { className: "grant-player-table" });
  tableNode.append(element("caption", { className: "sr-only", text: "资源发放玩家明细；可勾选一个或多个玩家" }));
  const head = document.createElement("thead");
  const headRow = document.createElement("tr");
  const selectedVisibleCount = filtered.filter((account) => state.selectedGrantUserIds.has(account.user_id)).length;
  const selectAll = element("input", {
    type: "checkbox",
    checked: selectedVisibleCount === filtered.length,
    attrs: { "aria-label": "选择或取消当前搜索结果中的全部玩家" },
  });
  selectAll.indeterminate = selectedVisibleCount > 0 && selectedVisibleCount < filtered.length;
  selectAll.addEventListener("change", () => {
    filtered.forEach((account) => {
      if (selectAll.checked) state.selectedGrantUserIds.add(account.user_id);
      else state.selectedGrantUserIds.delete(account.user_id);
    });
    announce(`已选择 ${selectedGrantIds().length} 个玩家。`);
    renderActiveTab();
  });
  const selectionHeader = element("th", { attrs: { scope: "col" } });
  const selectionHeaderLabel = element("label", { className: "grant-checkbox grant-checkbox-header" });
  selectionHeaderLabel.append(selectAll, element("span", { text: "选择" }));
  selectionHeader.append(selectionHeaderLabel);
  headRow.append(selectionHeader);
  ["玩家名称", "完整玩家 ID", "段位 / Elo", "抽卡券", "阵容卡数"].forEach((label) => {
    headRow.append(element("th", { text: label, attrs: { scope: "col" } }));
  });
  head.append(headRow);
  const body = document.createElement("tbody");
  filtered.forEach((account) => {
    const selected = state.selectedGrantUserIds.has(account.user_id);
    const row = element("tr", { className: selected ? "is-selected" : "" });
    const checkbox = element("input", {
      type: "checkbox",
      checked: selected,
      attrs: { "aria-label": `选择玩家 ${accountDisplayName(account)} ${account.user_id}` },
    });
    checkbox.addEventListener("change", () => {
      if (checkbox.checked) state.selectedGrantUserIds.add(account.user_id);
      else state.selectedGrantUserIds.delete(account.user_id);
      announce(`已选择 ${selectedGrantIds().length} 个玩家。`);
      renderActiveTab();
    });
    const checkboxLabel = element("label", { className: "grant-checkbox" });
    checkboxLabel.append(checkbox, element("span", { className: "sr-only", text: `玩家 ${accountDisplayName(account)} ${account.user_id}` }));
    const playerName = element("span", { className: "grant-player-name", text: accountDisplayName(account) });
    playerName.append(element("small", {
      className: "rank-id",
      text: accountUsesTemporaryName(account) ? "系统临时名称" : (account.masked_account || "已设置用户名"),
    }));
    const values = [
      checkboxLabel,
      playerName,
      element("code", { className: "full-user-id", text: account.user_id || "—" }),
      `${rankLabel(account.rank?.rank_key)} ${formatNumber(account.rank?.rank_stars)} 星 · Elo ${formatNumber(account.rank?.elo)}`,
      formatNumber(account.resources?.gacha_tickets),
      formatNumber(normalizeList(account.deck).length),
    ];
    const labels = ["选择", "玩家名称", "完整玩家 ID", "段位 / Elo", "抽卡券", "阵容卡数"];
    values.forEach((value, index) => {
      const cell = element("td", { attrs: { "data-label": labels[index] } });
      if (value instanceof Node) cell.append(value);
      else cell.textContent = String(value);
      row.append(cell);
    });
    body.append(row);
  });
  tableNode.append(head, body);
  region.append(tableNode);
  return region;
}

function buildGrantDraft(form) {
  const formData = new FormData(form);
  const type = String(formData.get("grant_type") || "gacha_tickets");
  const selectedIds = selectedGrantIds();
  const accountCount = new Set(normalizeList(state.accounts?.accounts).map((account) => account.user_id).filter(Boolean)).size;
  const target = selectedIds.length > 0 && selectedIds.length === accountCount
    ? { kind: "all" }
    : selectedIds.length === 1
      ? { kind: "user", user_id: selectedIds[0] }
      : { kind: "selected", user_ids: selectedIds };
  const draft = {
    target,
    grant: { type, amount: Number(formData.get("amount")) },
    reason: String(formData.get("reason") || "").trim(),
  };
  if (type === "card_copies") draft.grant.card_id = String(formData.get("card_id") || "").trim();
  return draft;
}

function validateGrantDraft(draft) {
  const accountCount = normalizeList(state.accounts?.accounts).length;
  const targetCount = draft.target.kind === "user" ? 1 : normalizeList(draft.target.user_ids).length;
  if (state.accounts?.availability !== "ready" || accountCount < 1) return "玩家目标必须基于已就绪且非空的账号投影。";
  if (state.selectedGrantUserIds.size < 1 || (draft.target.kind === "selected" && targetCount < 2)) return "请先勾选至少一个玩家。";
  if (draft.target.kind === "selected" && targetCount > MAX_SELECTED_GRANT_TARGETS) return `多选发放单次最多选择 ${MAX_SELECTED_GRANT_TARGETS} 个玩家；如需全服发放，请选择全部账号并走强确认。`;
  if (draft.target.kind === "all" && (state.accounts?.availability !== "ready" || accountCount < 1)) return "全服目标必须基于已就绪且非空的账号投影。";
  if (draft.target.kind === "user" && !draft.target.user_id) return "请选择目标账号。";
  if (!Number.isInteger(draft.grant.amount) || draft.grant.amount < 1 || draft.grant.amount > 100000) return "数量必须是 1–100,000 的整数。";
  if (draft.grant.type === "card_copies" && !draft.grant.card_id) return "发送卡牌副本时必须填写卡牌 ID。";
  if (draft.reason.length < 4 || draft.reason.length > 200) return "原因需为 4–200 个字符。";
  return "";
}

function grantDescription(draft) {
  if (!draft) return "—";
  if (draft.grant?.type === "all_animals") return "全部动物各 1 份";
  if (draft.grants?.length > 1) {
    const grants = draft.grants;
    if (grants.every((grant) => grant.resource === "card_copies" && grant.amount === grants[0].amount)) {
      return `${formatNumber(grants.length)} 种卡牌 · 每种 ${formatNumber(grants[0].amount)} 份`;
    }
    return `${formatNumber(grants.length)} 项资源`;
  }
  const rawGrant = draft.grant || draft.grants?.[0] || {};
  const type = rawGrant.type || rawGrant.resource;
  if (type === "card_copies") return `${cardDisplayName(rawGrant.card_id)}副本 × ${formatNumber(rawGrant.amount)}`;
  if (type === "gacha_tickets") return `抽卡券 × ${formatNumber(rawGrant.amount)}`;
  return "—";
}

function grantStatusMeta(statusValue) {
  const status = String(statusValue || "pending").toLowerCase();
  if (["processed", "applied", "completed", "success"].includes(status)) return { label: "发放成功", kind: "good", terminal: true };
  if (["failed", "rejected"].includes(status)) return { label: "发放失败", kind: "danger", terminal: true };
  return { label: "处理中", kind: "warning", terminal: false };
}

async function waitForGrantTerminal(commandId, attempts = 10) {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const payload = await request("/api/resource-grants");
    state.grants = normalizeList(payload.entries);
    state.grantsLoaded = true;
    const entry = state.grants.find((item) => String(item.command_id || item.id) === String(commandId));
    if (entry && grantStatusMeta(entry.status).terminal) return entry;
    if (attempt + 1 < attempts) await new Promise((resolve) => window.setTimeout(resolve, 500));
  }
  return state.grants.find((item) => String(item.command_id || item.id) === String(commandId)) || null;
}

async function submitScopedGrant(contract, idempotencyKey) {
  if (!["target", "selected"].includes(contract.scope)) throw Object.assign(new Error("scoped preview required"), { code: "invalid_preview_request" });
  const payload = await request("/api/resource-grants", {
    method: "POST",
    mutation: true,
    body: JSON.stringify({ preview_token: contract.preview_token, idempotency_key: idempotencyKey }),
  });
  const command = payload.command || payload;
  return await waitForGrantTerminal(command.command_id || command.id).catch(() => null) || command;
}

function renderGrantPreview(pane) {
  if (!state.grantPreview) return;
  const draft = state.grantPreview.draft;
  const targetCount = state.grantPreview.targetCount;
  const preview = element("section", { className: "panel grant-preview", attrs: { "aria-labelledby": "grant-preview-heading" } });
  preview.append(element("p", { className: "step-label", text: "步骤 2–4 / 4 · 重新认证、二次确认、提交" }), element("h2", { id: "grant-preview-heading", text: "核对不可撤销指令" }));
  preview.append(callout("danger", "提交后不可撤销", "提交只会创建服务器待执行指令，不表示资源已到账。请依据任务状态回执核对执行结果；失败时不要更换幂等键盲目重试。", "alert"));
  const facts = element("dl", { className: "preview-facts" });
  const targetText = `全部账号（${targetCount} 个）`;
  [["目标", targetText], ["资源", grantDescription(draft)], ["原因", draft.reason], ["幂等键", state.grantPreview.idempotencyKey], ["预览有效至", formatDate(state.grantPreview.expiresAt)]].forEach(([term, value]) => facts.append(element("dt", { text: term }), element("dd", { text: value })));
  preview.append(facts);
  const confirmForm = element("form", { className: "grant-confirm-form" });
  const password = element("input", { type: "password", name: "password", required: true, autocomplete: "current-password", placeholder: "当前 Owner 密码" });
  const expectedConfirmation = "SEND TO ALL";
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
          confirmation: confirmation.value,
          password: password.value,
          idempotency_key: state.grantPreview.idempotencyKey,
          preview_token: state.grantPreview.previewToken,
        }),
      });
      password.value = "";
      confirmation.value = "";
      const command = payload.command || payload;
      state.grantResult = await waitForGrantTerminal(command.command_id || command.id).catch(() => null) || command;
      state.grantPreview = null;
      state.grantDraft = null;
      state.selectedGrantUserIds.clear();
      state.grantFormValues = { grant_type: "gacha_tickets", amount: "1", card_id: "", reason: "" };
      renderActiveTab();
      announce(grantStatusMeta(state.grantResult.status).label);
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
  const meta = grantStatusMeta(command.status);
  wrapper.classList.add(`receipt-${meta.kind}`);
  const target = command.scope === "all"
    ? `全部 ${formatNumber(command.target_count)} 个账号`
    : command.scope === "selected"
      ? `已选 ${formatNumber(command.target_count)} 个账号`
      : compactUserId(command.target_user_ids?.[0] || command.target?.user_id);
  wrapper.append(
    element("h2", { text: meta.label }),
    element("p", { text: `${target} · ${grantDescription(command)}` }),
    element("small", { className: "muted", text: `指令 ${compactUserId(command.command_id || command.id)}${meta.terminal ? " · 已收到终态回执" : " · 执行器仍在处理，可稍后刷新"}` }),
  );
  return wrapper;
}

function renderGrants() {
  const pane = createPane("grants", "资源发放");
  const receipt = renderGrantReceipt();
  if (receipt) pane.append(receipt);
  if (state.loadErrors.accounts) {
    pane.append(errorState(state.loadErrors.accounts, () => switchTab("grants", { force: true })));
    return pane;
  }
  if (!state.accounts) {
    pane.append(loadingState("正在加载可选账号投影…"));
    return pane;
  }
  const accounts = sortedAccounts();
  const accountCount = accounts.length;
  const availabilityText = state.accounts.availability === "ready" ? `账号投影已就绪，共 ${accountCount} 个目标。` : "账号投影未就绪，暂不可创建资源指令。";
  pane.append(callout(state.accounts.availability === "ready" ? "info" : "warning", "执行前提", `${availabilityText} 指令由阿里云服务器执行器消费；此后台不直接改写玩家存档。`, state.accounts.availability === "ready" ? "status" : "alert"));
  if (state.accounts.availability !== "ready" || accountCount < 1) return pane;
  if (state.grantPreview) {
    renderGrantPreview(pane);
    return pane;
  }

  const filtered = grantFilteredAccounts();
  const playerContent = element("div", { className: "grant-player-panel" });
  playerContent.append(
    grantSelectionToolbar(accounts, filtered),
    grantPlayerTable(accounts, filtered),
  );
  const playerSection = panel(
    "选择玩家",
    playerContent,
    `显示玩家名称、完整玩家 ID 与核心运营数据 · 当前显示 ${filtered.length} / ${accountCount}`,
    { className: "grant-player-section" },
  );

  const selectedIds = selectedGrantIds();
  let selectionNotice = null;
  if (selectedIds.length === accountCount) {
    selectionNotice = callout("warning", "已选择全部账号", "提交后进入全服强确认：需重新输入 Owner 密码与 SEND TO ALL。", "alert");
  } else if (selectedIds.length > MAX_SELECTED_GRANT_TARGETS) {
    selectionNotice = callout("danger", "选择数量超限", `多选发放最多 ${MAX_SELECTED_GRANT_TARGETS} 人；请缩小选择，或选择全部账号后走全服强确认。`, "alert");
  }

  const form = element("form", { className: "grant-form grant-operation-form", attrs: { "aria-labelledby": "grant-form-heading" } });
  const selectionInvalid = selectedIds.length === 0 || (selectedIds.length > MAX_SELECTED_GRANT_TARGETS && selectedIds.length !== accountCount);
  const selectionStatus = element("p", {
    id: "grant-selection-status",
    className: `grant-operation-summary${selectionInvalid ? " is-invalid" : ""}`,
    text: selectedIds.length === 0
      ? "尚未选择玩家，请在左侧玩家表勾选目标。"
      : `已选择 ${selectedIds.length} 人${selectedIds.length === accountCount ? " · 全服强确认" : " · 一次提交"}`,
    attrs: { role: "status", "aria-live": "polite" },
  });
  form.append(
    element("p", { className: "step-label", text: "首屏操作区 · 单个 / 多选一次提交" }),
    element("h2", { id: "grant-form-heading", text: "发放资源" }),
    selectionStatus,
  );
  const allAnimalsButton = element("button", {
    className: "primary grant-submit-button",
    type: "button",
    text: "一键发放全部动物（各1份）",
    disabled: selectedIds.length !== 1 || state.grantBusy,
  });
  form.append(allAnimalsButton, element("p", {
    className: "grant-operation-note",
    text: "测试快捷指令：仅选 1 名玩家即可点击；每种动物增加 1 份，不改等级、阵容或抽卡券。",
  }));
  if (selectionNotice) form.append(selectionNotice);
  const grantType = element("select", { name: "grant_type" });
  grantType.append(new Option("抽卡券", "gacha_tickets"), new Option("卡牌副本", "card_copies"));
  grantType.value = state.grantFormValues.grant_type || "gacha_tickets";
  const amount = element("input", { type: "number", name: "amount", required: true, min: "1", max: "100000", step: "1", value: state.grantFormValues.amount || "1" });
  const cardId = element("input", { name: "card_id", value: state.grantFormValues.card_id || "", placeholder: "例如 animal_fox", autocomplete: "off" });
  const cardField = labeledControl("卡牌 ID", cardId, "仅“卡牌副本”需要。必须使用正式配置 ID。");
  const reason = element("textarea", { name: "reason", required: true, value: state.grantFormValues.reason || "", placeholder: "填写可审计的业务原因（4–200 字）", attrs: { maxlength: "200", rows: "4" } });
  reason.value = state.grantFormValues.reason || "";
  const error = element("p", { className: "error", attrs: { role: "alert", tabindex: "-1" } });
  const submitButtonText = selectedIds.length === 0
    ? "请先选择玩家"
    : selectedIds.length === accountCount
      ? `继续全服发放资源（${selectedIds.length} 人）`
      : selectedIds.length > MAX_SELECTED_GRANT_TARGETS
        ? "已选玩家超过上限"
        : `向已选 ${selectedIds.length} 人发放资源`;
  const submitButton = element("button", {
    className: "primary grant-submit-button",
    type: "submit",
    text: submitButtonText,
    disabled: selectionInvalid || state.grantBusy,
    attrs: { "aria-describedby": "grant-selection-status" },
  });
  const primaryFields = element("div", { className: "grant-primary-fields" });
  primaryFields.append(
    labeledControl("资源类型", grantType),
    labeledControl("数量", amount),
  );
  form.append(
    primaryFields,
    cardField,
    submitButton,
    labeledControl("发放原因", reason),
    error,
    element("p", { className: "grant-operation-note", text: "后台只创建一条幂等指令；处理成功后才显示到账。" }),
  );
  function captureFormValues() {
    state.grantFormValues = {
      grant_type: grantType.value,
      amount: amount.value,
      card_id: cardId.value,
      reason: reason.value,
    };
  }
  function updateConditionalFields() {
    const cardCopies = grantType.value === "card_copies";
    cardId.disabled = !cardCopies;
    cardId.required = cardCopies;
    cardField.hidden = !cardCopies;
    captureFormValues();
  }
  grantType.addEventListener("change", updateConditionalFields);
  form.addEventListener("input", captureFormValues);
  updateConditionalFields();
  allAnimalsButton.addEventListener("click", async () => {
    if (state.grantBusy || selectedIds.length !== 1) return;
    const userId = selectedIds[0];
    // Keep the key across ambiguous network failures and page rerenders.
    if (state.allAnimalsAttempt?.userId !== userId) {
      state.allAnimalsAttempt = { userId, key: generateIdempotencyKey() };
    }
    const key = state.allAnimalsAttempt.key;
    state.grantBusy = true;
    allAnimalsButton.disabled = true;
    submitButton.disabled = true;
    allAnimalsButton.textContent = "正在发放全部动物…";
    error.textContent = "";
    try {
      const payload = await request("/api/resource-grants/preview", {
        method: "POST", mutation: true,
        body: JSON.stringify({
          target: { kind: "user", user_id: userId },
          grant: { type: "all_animals", amount: 1 },
          reason: "测试：一键发放全部动物各1份",
          idempotency_key: key,
        }),
      });
      const contract = payload.preview;
      if (!contract?.preview_token || contract.idempotency_key !== key
        || contract.scope !== "target" || contract.target_count !== 1
        || contract.target_user_ids?.[0] !== userId) {
        throw Object.assign(new Error("invalid preview response"), { code: "invalid_preview_token" });
      }
      state.grantResult = await submitScopedGrant(contract, key);
      // Pending is still the same command. Do not generate a new grant on retry.
      if (grantStatusMeta(state.grantResult.status).terminal) state.allAnimalsAttempt = null;
      state.selectedGrantUserIds.clear();
      state.grantBusy = false;
      renderActiveTab();
      announce(grantStatusMeta(state.grantResult.status).label);
      document.querySelector("#grant-receipt")?.focus();
    } catch (requestError) {
      error.textContent = requestError.code === "animal_catalog_unavailable"
        ? "动物目录尚未就绪，未创建指令。请刷新数据后重试。"
        : `${apiErrorMessage(requestError.code)} 重试会沿用同一指令，不会重复到账。`;
      error.focus();
    } finally {
      state.grantBusy = false;
      allAnimalsButton.disabled = selectedIds.length !== 1;
      allAnimalsButton.textContent = "一键发放全部动物（各1份）";
      submitButton.disabled = selectionInvalid;
    }
  });
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (state.grantBusy) return;
    error.textContent = "";
    captureFormValues();
    const draft = buildGrantDraft(form);
    const message = validateGrantDraft(draft);
    if (message) {
      error.textContent = message;
      error.focus?.();
      return;
    }
    const idempotencyKey = generateIdempotencyKey();
    state.grantBusy = true;
    submitButton.disabled = true;
    allAnimalsButton.disabled = true;
    try {
      const payload = await request("/api/resource-grants/preview", {
        method: "POST",
        mutation: true,
        body: JSON.stringify({ ...draft, idempotency_key: idempotencyKey }),
      });
      const contract = payload.preview;
      if (!contract?.preview_token || contract.idempotency_key !== idempotencyKey) {
        throw Object.assign(new Error("invalid preview response"), { code: "invalid_preview_token" });
      }
      const expectedScope = draft.target.kind === "user" ? "target" : draft.target.kind;
      if (contract.scope !== expectedScope || Number(contract.target_count) !== selectedIds.length) {
        throw Object.assign(new Error("preview target mismatch"), { code: "invalid_preview_token" });
      }
      state.grantDraft = draft;
      if (["user", "selected"].includes(draft.target.kind)) {
        state.grantBusy = true;
        state.grantResult = await submitScopedGrant(contract, idempotencyKey);
        state.grantDraft = null;
        state.selectedGrantUserIds.clear();
        state.grantFormValues = { grant_type: "gacha_tickets", amount: "1", card_id: "", reason: "" };
        renderActiveTab();
        announce(grantStatusMeta(state.grantResult.status).label);
        document.querySelector("#grant-receipt")?.focus();
      } else {
        state.grantPreview = {
          draft,
          idempotencyKey,
          previewToken: contract.preview_token,
          expiresAt: contract.expires_at_unix,
          targetCount: contract.target_count,
        };
        renderActiveTab();
        announce(`全账号预览已生成，冻结目标 ${contract.target_count} 个账号。`);
      }
    } catch (requestError) {
      error.textContent = apiErrorMessage(requestError.code);
      error.focus?.();
    } finally {
      state.grantBusy = false;
      submitButton.disabled = false;
      allAnimalsButton.disabled = selectedIds.length !== 1;
    }
  });
  const workspace = element("div", { className: "grant-workspace" });
  workspace.append(form, playerSection);
  pane.append(workspace);
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
  const grants = state.grants.slice(0, 30);
  const grantColumns = ["状态", "目标", "资源", "原因", "完成/创建时间", "备注"].map((label) => ({ label }));
  const grantRows = grants.map((entry) => {
    const meta = grantStatusMeta(entry.status);
    const target = entry.target?.kind === "all" || entry.scope === "all"
      ? `全部账号（${formatNumber(entry.target_count)}）`
      : entry.scope === "selected"
        ? `已选账号（${formatNumber(entry.target_count)}）`
        : compactUserId(entry.target?.user_id || entry.user_id || entry.target_user_ids?.[0]);
    return [
      tag(meta.label, meta.kind),
      target,
      grantDescription(entry),
      entry.reason || "—",
      formatDate(entry.processed_at_unix || entry.created_at_unix),
      entry.error || `指令 ${compactUserId(entry.command_id || entry.id)}`,
    ];
  });
  pane.append(panel("资源发放记录", grantRows.length ? dataTable("资源发放终态与处理中记录", grantColumns, grantRows) : emptyState("尚无资源发放记录。"), "同一指令仅显示一条；未完成时显示处理中"));
  const auditList = element("div", { className: "audit-list" });
  if (!state.audit.length) auditList.append(emptyState("尚无权限审计事件。"));
  state.audit.forEach((entry) => {
    const item = element("article", { className: "audit-entry" });
    const rawTime = Number(entry.at || 0);
    const auditTime = rawTime > 100000000000 ? Math.floor(rawTime / 1000) : rawTime;
    item.append(
      element("strong", { text: `${entry.event || "audit"}${entry.pending ? "（outbox 待重放）" : ""}` }),
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
    const outcome = await request(`/api/admins/${encodeURIComponent(username)}`, { method: "PATCH", mutation: true, body: JSON.stringify(patch) });
    await loadManagement(true);
    renderActiveTab();
    const message = outcome.audit_pending
      ? `管理员 ${username} 已更新；完整审计已进入持久 outbox，但日志投影待重放，系统当前未就绪。`
      : `管理员 ${username} 已更新。`;
    announce(message);
    if (outcome.audit_pending) window.alert(message);
  } catch (error) {
    announce(apiErrorMessage(error.code));
    window.alert(apiErrorMessage(error.code));
  }
}

async function revokeSessions(username) {
  const confirmed = await nativeConfirmDialog({ title: "撤销全部会话？", description: `这会立即使 ${username} 的全部现有登录会话失效，且不可撤销。`, confirmText: "撤销全部会话" });
  if (!confirmed) return;
  try {
    const outcome = await request(`/api/admins/${encodeURIComponent(username)}/revoke-sessions`, { method: "POST", mutation: true, body: JSON.stringify({}) });
    await loadManagement(true);
    renderActiveTab();
    const message = outcome.audit_pending
      ? `${username} 的全部会话已撤销；完整审计已进入持久 outbox，但日志投影待重放，系统当前未就绪。`
      : `${username} 的全部会话已撤销。`;
    announce(message);
    if (outcome.audit_pending) window.alert(message);
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
      const outcome = await request("/api/admins", { method: "POST", mutation: true, body: JSON.stringify({ username: username.value, password: password.value, role: role.value }) });
      password.value = "";
      username.value = "";
      await loadManagement(true);
      renderActiveTab();
      const message = outcome.audit_pending
        ? "管理员账号已创建；完整审计已进入持久 outbox，但日志投影待重放，系统当前未就绪。"
        : "管理员账号已创建。";
      announce(message);
      if (outcome.audit_pending) window.alert(message);
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
  if (state.activeTab === "roles") pane = renderRoles();
  if (state.activeTab === "decks") pane = renderDecks();
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
    if (["roles", "decks", "grants"].includes(name)) await loadAccounts(Boolean(options.force));
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
  state.animalBattleType = "all";
  state.accountQuery = "";
  state.grantAccountQuery = "";
  state.selectedGrantUserIds = new Set();
  state.grantFormValues = { grant_type: "gacha_tickets", amount: "1", card_id: "", reason: "" };
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
