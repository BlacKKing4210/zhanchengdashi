import fs from "node:fs/promises";
import path from "node:path";

const MAX_SNAPSHOT_BYTES = 64 * 1024 * 1024;
const MAX_ACCOUNTS = 100_000;
const MAX_CARDS = 1_000;
const MAX_MIRRORS_PER_RANK = 15;
const CARD_ID_PATTERN = /^[A-Za-z0-9_.:-]{1,64}$/;
const USER_ID_PATTERN = /^[A-Za-z0-9_.:-]{1,80}$/;
const RANK_KEY_PATTERN = /^[a-z0-9_-]{1,24}$/;
const RANK_ORDER = new Map(["bronze", "silver", "gold", "platinum", "diamond", "star", "king"].map((rank, index) => [rank, index]));

function text(value, maxLength = 64) {
  return typeof value === "string"
    ? value.replace(/[\u0000-\u001f\u007f]/g, " ").trim().slice(0, maxLength)
    : "";
}

function integer(value, fallback = 0, minimum = 0, maximum = 1_000_000_000) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.min(maximum, Math.max(minimum, Math.trunc(parsed))) : fallback;
}

function safeCardId(value) {
  const cardId = text(value, 64);
  return CARD_ID_PATTERN.test(cardId) ? cardId : "";
}

function safeUserId(value) {
  const userId = text(value, 80);
  return USER_ID_PATTERN.test(userId) ? userId : "";
}

function safeRankKey(value) {
  const rankKey = text(value, 24).toLowerCase();
  return RANK_KEY_PATTERN.test(rankKey) ? rankKey : "unknown";
}

function safeMaskedAccount(value) {
  const candidate = text(value, 40);
  return candidate === "device-account" || candidate.includes("*") ? candidate : "masked-account";
}

function safeUsername(value) {
  const candidate = text(value, 16);
  return candidate.length >= 2 ? candidate : "";
}

function safeDeck(value) {
  const result = [];
  if (!Array.isArray(value)) return result;
  for (const rawCardId of value) {
    const cardId = safeCardId(rawCardId);
    if (cardId && !result.includes(cardId)) result.push(cardId);
    if (result.length >= 8) break;
  }
  return result;
}

function safeCardDictionary(value, minimum, maximum) {
  const result = {};
  if (!value || typeof value !== "object" || Array.isArray(value)) return result;
  for (const [rawCardId, rawAmount] of Object.entries(value).slice(0, MAX_CARDS)) {
    const cardId = safeCardId(rawCardId);
    if (cardId) result[cardId] = integer(rawAmount, minimum, minimum, maximum);
  }
  return result;
}

function sanitizeCardNames(value) {
  const result = {};
  if (!value || typeof value !== "object" || Array.isArray(value)) return result;
  for (const [rawCardId, rawName] of Object.entries(value).slice(0, MAX_CARDS)) {
    const cardId = safeCardId(rawCardId);
    const name = text(rawName, 48);
    if (cardId && name) result[cardId] = name;
  }
  return result;
}

function sanitizeMirror(value, rankKey) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const deck = safeDeck(value.deck);
  if (deck.length === 0) return null;
  const allLevels = safeCardDictionary(value.card_levels, 1, 99);
  const cardLevels = Object.fromEntries(deck.map((cardId) => [cardId, allLevels[cardId] ?? 1]));
  return {
    mirror_id: text(value.mirror_id, 80),
    player_id: safeUserId(value.player_id),
    name: text(value.name, 40),
    rank_key: rankKey,
    rank_display: text(value.rank_display, 40),
    stars: integer(value.stars, 0, 0, 100_000),
    elo: integer(value.elo, 0, 0, 1_000_000),
    deck,
    card_levels: cardLevels,
    created_at_unix: integer(value.created_at_unix, 0, 0, 4_102_444_800),
  };
}

function sanitizeRankMirrors(value) {
  const result = {};
  if (!value || typeof value !== "object" || Array.isArray(value)) return result;
  for (const [rawRankKey, rawMirrors] of Object.entries(value)) {
    const rankKey = safeRankKey(rawRankKey);
    if (rankKey === "unknown" || !Array.isArray(rawMirrors)) continue;
    const mirrors = rawMirrors
      .slice(0, MAX_MIRRORS_PER_RANK)
      .map((entry) => sanitizeMirror(entry, rankKey))
      .filter(Boolean);
    if (mirrors.length > 0) result[rankKey] = mirrors;
  }
  return result;
}

function sanitizeAccount(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const userId = safeUserId(value.user_id);
  if (!userId) return null;
  const deck = safeDeck(value.deck);
  const cardLevels = safeCardDictionary(value.card_levels, 1, 99);
  const rank = value.rank && typeof value.rank === "object" && !Array.isArray(value.rank) ? value.rank : {};
  const resources = value.resources && typeof value.resources === "object" && !Array.isArray(value.resources) ? value.resources : {};
  return {
    user_id: userId,
    username: safeUsername(value.username),
    masked_account: safeMaskedAccount(value.masked_account),
    created_at_unix: integer(value.created_at_unix, 0, 0, 4_102_444_800),
    updated_at_unix: integer(value.updated_at_unix, 0, 0, 4_102_444_800),
    profile_revision: integer(value.profile_revision, 1, 1, Number.MAX_SAFE_INTEGER),
    deck,
    card_levels: cardLevels,
    rank: {
      rank_key: safeRankKey(rank.rank_key),
      rank_stars: integer(rank.rank_stars, 0, 0, 100_000),
      elo: integer(rank.elo, 0, 0, 1_000_000),
    },
    rank_mirrors: sanitizeRankMirrors(value.rank_mirrors),
    resources: {
      gacha_tickets: integer(resources.gacha_tickets, 0, 0, 1_000_000_000),
      card_copies: safeCardDictionary(resources.card_copies, 0, 1_000_000_000),
    },
  };
}

export function emptyAccountSnapshot(reason = "empty") {
  return { availability: reason, generated_at_unix: 0, card_names: {}, accounts: [] };
}

export function sanitizeAccountSnapshot(source) {
  if (!source || typeof source !== "object" || Array.isArray(source)) return emptyAccountSnapshot("invalid");
  const rawAccounts = Array.isArray(source.accounts) ? source.accounts : [];
  if (rawAccounts.length > MAX_ACCOUNTS) return emptyAccountSnapshot("too_large");
  const seen = new Set();
  const accounts = [];
  for (const rawAccount of rawAccounts) {
    const account = sanitizeAccount(rawAccount);
    if (!account || seen.has(account.user_id)) continue;
    seen.add(account.user_id);
    accounts.push(account);
  }
  accounts.sort((left, right) => {
    const leftRank = RANK_ORDER.get(left.rank.rank_key) ?? -1;
    const rightRank = RANK_ORDER.get(right.rank.rank_key) ?? -1;
    return rightRank - leftRank
      || right.rank.rank_stars - left.rank.rank_stars
      || right.rank.elo - left.rank.elo
      || left.user_id.localeCompare(right.user_id);
  });
  return {
    availability: "ready",
    generated_at_unix: integer(source.generated_at_unix, 0, 0, 4_102_444_800),
    card_names: sanitizeCardNames(source.card_names),
    accounts,
  };
}

export function resolveAccountSnapshotPath(snapshotPath) {
  if (typeof snapshotPath !== "string" || snapshotPath.trim() === "") {
    throw new Error("ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH is required");
  }
  const resolved = path.resolve(snapshotPath);
  if (path.basename(resolved).toLowerCase() !== "admin_accounts_snapshot.json") {
    throw new Error("account snapshot path must end with admin_accounts_snapshot.json");
  }
  return resolved;
}

export async function readAccountSnapshot(snapshotPath) {
  const resolved = resolveAccountSnapshotPath(snapshotPath);
  try {
    const metadata = await fs.stat(resolved);
    if (!metadata.isFile() || metadata.size > MAX_SNAPSHOT_BYTES) return emptyAccountSnapshot("unavailable");
    return sanitizeAccountSnapshot(JSON.parse(await fs.readFile(resolved, "utf8")));
  } catch (error) {
    if (error && error.code === "ENOENT") return emptyAccountSnapshot("empty");
    if (error instanceof SyntaxError) return emptyAccountSnapshot("invalid");
    return emptyAccountSnapshot("unavailable");
  }
}
