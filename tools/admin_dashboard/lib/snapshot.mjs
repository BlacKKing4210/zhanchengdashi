import fs from "node:fs/promises";
import path from "node:path";

const MAX_SNAPSHOT_BYTES = 8 * 1024 * 1024;
const MAX_LEADERBOARD_ROWS = 500;
const MAX_TOP_DECKS = 100;
const MAX_ANIMAL_ROWS = 500;
const MAX_RECENT_MATCHES = 100;
const MAX_MATCH_PLAYERS = 6;
const CARD_ID_PATTERN = /^[A-Za-z0-9_.:-]{1,64}$/;
const RANK_KEY_PATTERN = /^[a-z0-9_-]{1,24}$/;

function integer(value, fallback = 0, minimum = 0, maximum = 1_000_000_000) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.min(maximum, Math.max(minimum, Math.trunc(parsed)));
}

function optionalInteger(value, minimum = 0, maximum = 1_000_000_000) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return null;
  }
  return Math.min(maximum, Math.max(minimum, Math.trunc(parsed)));
}

function ratio(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.min(1, Math.max(0, parsed)) : fallback;
}

function text(value, maxLength = 64) {
  if (typeof value !== "string") {
    return "";
  }
  return value.replace(/[\u0000-\u001f\u007f]/g, " ").trim().slice(0, maxLength);
}

function safeCardId(value) {
  const id = text(value, 64);
  return CARD_ID_PATTERN.test(id) ? id : "";
}

function safeRankKey(value) {
  const rankKey = text(value, 24).toLowerCase();
  return RANK_KEY_PATTERN.test(rankKey) ? rankKey : "unknown";
}

function safeDeck(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  const deck = [];
  for (const rawCardId of value) {
    const cardId = safeCardId(rawCardId);
    if (cardId && !deck.includes(cardId)) {
      deck.push(cardId);
    }
    if (deck.length >= 8) {
      break;
    }
  }
  return deck;
}

function safeCardLevels(value, deck) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  const result = {};
  for (const cardId of deck) {
    result[cardId] = integer(value[cardId], 1, 1, 99);
  }
  return result;
}

function outcomeCounts(value) {
  const games = integer(value?.games, integer(value?.appearances, 0));
  const wins = integer(value?.wins, 0, 0, games);
  const losses = integer(value?.losses, 0, 0, games);
  const draws = integer(value?.draws, 0, 0, games);
  return { games, wins, losses, draws };
}

function winRate(value, counts) {
  if (counts.games <= 0) {
    return null;
  }
  const defaultRate = counts.wins / counts.games;
  if (value === null || value === undefined || value === "") {
    return defaultRate;
  }
  return ratio(value, defaultRate);
}

export function emptyDashboard(reason = "empty") {
  return {
    availability: reason,
    generated_at_unix: 0,
    overview: {
      matches: 0,
      players: 0,
      active_24h: 0,
      season: "",
      source: "",
    },
    leaderboard: [],
    top_decks: [],
    animals: [],
    recent_matches: [],
  };
}

function sanitizeLeaderboardEntry(value, index) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const deck = safeDeck(value.deck);
  const counts = outcomeCounts(value);
  return {
    rank: integer(value.rank, index + 1, 1, MAX_LEADERBOARD_ROWS),
    user_id: text(value.user_id, 80),
    display_name: text(value.display_name, 48),
    rank_key: safeRankKey(value.rank_key),
    rank_stars: integer(value.rank_stars, 0, 0, 100_000),
    elo: optionalInteger(value.elo, 0, 1_000_000),
    ...counts,
    win_rate: winRate(value.win_rate, counts),
    deck,
    card_levels: safeCardLevels(value.card_levels, deck),
  };
}

function sanitizeTopDeck(value, index) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const deck = safeDeck(value.deck);
  if (deck.length === 0) {
    return null;
  }
  const counts = outcomeCounts(value);
  return {
    rank: integer(value.rank, index + 1, 1, MAX_TOP_DECKS),
    user_id: text(value.user_id, 80),
    display_name: text(value.display_name, 48),
    rank_key: safeRankKey(value.rank_key),
    rank_stars: integer(value.rank_stars, 0, 0, 100_000),
    elo: optionalInteger(value.elo, 0, 1_000_000),
    ...counts,
    win_rate: winRate(value.win_rate, counts),
    deck,
    card_levels: safeCardLevels(value.card_levels, deck),
  };
}

function sanitizeAnimal(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const cardId = safeCardId(value.card_id);
  if (!cardId) {
    return null;
  }
  const counts = outcomeCounts(value);
  return {
    card_id: cardId,
    name: text(value.name, 48) || cardId,
    ...counts,
    win_rate: winRate(value.win_rate, counts),
    pick_rate: Number.isFinite(Number(value.pick_rate)) ? ratio(value.pick_rate, 0) : null,
  };
}

function sanitizeRecentPlayer(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return {
    user_id: text(value.user_id, 80),
    display_name: text(value.display_name, 48),
    team_id: integer(value.team_id, 0, 0, 6),
    rank_key: safeRankKey(value.rank_key),
    rank_stars: integer(value.rank_stars, 0, 0, 100_000),
  };
}

function sanitizeTeamOutcomes(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  const outcomes = {};
  for (const [teamId, rawOutcome] of Object.entries(value)) {
    const team = integer(teamId, 0, 1, 6);
    const outcome = text(rawOutcome, 8).toLowerCase();
    if (team && ["win", "loss", "draw"].includes(outcome)) {
      outcomes[team] = outcome;
    }
  }
  return outcomes;
}

function sanitizeRecentMatch(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const matchId = text(value.match_id, 128);
  if (!matchId) {
    return null;
  }
  const rawPlayers = Array.isArray(value.players) ? value.players : [];
  return {
    match_id: matchId,
    map_id: text(value.map_id, 64),
    started_at_unix: integer(value.started_at_unix, 0, 0, 4_102_444_800),
    finalized_at_unix: integer(value.finalized_at_unix, 0, 0, 4_102_444_800),
    state: ["active", "finalized"].includes(text(value.state, 16)) ? text(value.state, 16) : "unknown",
    result_incomplete: Boolean(value.result_incomplete),
    team_outcomes: sanitizeTeamOutcomes(value.team_outcomes),
    players: rawPlayers.slice(0, MAX_MATCH_PLAYERS).map(sanitizeRecentPlayer).filter(Boolean),
  };
}

export function sanitizeDashboardSnapshot(source) {
  if (!source || typeof source !== "object" || Array.isArray(source)) {
    return emptyDashboard("invalid");
  }
  const rawLeaderboard = Array.isArray(source.leaderboard) ? source.leaderboard : [];
  const leaderboard = rawLeaderboard
    .slice(0, MAX_LEADERBOARD_ROWS)
    .map(sanitizeLeaderboardEntry)
    .filter(Boolean);
  const rawTopDecks = Array.isArray(source.top_decks) ? source.top_decks : [];
  const suppliedTopDecks = rawTopDecks
    .slice(0, MAX_TOP_DECKS)
    .map(sanitizeTopDeck)
    .filter(Boolean);
  const topDecks = suppliedTopDecks.length > 0
    ? suppliedTopDecks
    : leaderboard
      .filter((entry) => entry.deck.length > 0)
      .slice(0, 12)
      .map((entry) => ({ ...entry }));
  const animals = (Array.isArray(source.animals) ? source.animals : [])
    .slice(0, MAX_ANIMAL_ROWS)
    .map(sanitizeAnimal)
    .filter(Boolean)
    .sort((left, right) => Number(right.win_rate ?? -1) - Number(left.win_rate ?? -1) || right.games - left.games || left.card_id.localeCompare(right.card_id));
  const recentMatches = (Array.isArray(source.recent_matches) ? source.recent_matches : [])
    .slice(0, MAX_RECENT_MATCHES)
    .map(sanitizeRecentMatch)
    .filter(Boolean);
  const overviewSource = source.overview && typeof source.overview === "object" && !Array.isArray(source.overview)
    ? source.overview
    : {};
  const suppliedMatches = Object.hasOwn(overviewSource, "matches")
    ? overviewSource.matches
    : (source.total_matches ?? source.match_count ?? 0);
  return {
    availability: "ready",
    generated_at_unix: integer(source.generated_at_unix, 0, 0, 4_102_444_800),
    overview: {
      matches: integer(suppliedMatches, 0),
      players: integer(overviewSource.players, leaderboard.length),
      active_24h: integer(overviewSource.active_24h, 0),
      season: text(overviewSource.season, 48),
      source: text(overviewSource.source, 96),
    },
    leaderboard,
    top_decks: topDecks,
    animals,
    recent_matches: recentMatches,
  };
}

export function resolveSnapshotPath(snapshotPath) {
  if (typeof snapshotPath !== "string" || snapshotPath.trim() === "") {
    throw new Error("ZHANCHENG_DASHBOARD_SNAPSHOT_PATH is required");
  }
  const resolved = path.resolve(snapshotPath);
  if (path.basename(resolved).toLowerCase() !== "dashboard_snapshot.json") {
    throw new Error("dashboard snapshot path must end with dashboard_snapshot.json");
  }
  return resolved;
}

export async function readDashboardSnapshot(snapshotPath) {
  const resolved = resolveSnapshotPath(snapshotPath);
  try {
    const metadata = await fs.stat(resolved);
    if (!metadata.isFile() || metadata.size > MAX_SNAPSHOT_BYTES) {
      return emptyDashboard("unavailable");
    }
    const raw = await fs.readFile(resolved, "utf8");
    return sanitizeDashboardSnapshot(JSON.parse(raw));
  } catch (error) {
    if (error && error.code === "ENOENT") {
      return emptyDashboard("empty");
    }
    if (error instanceof SyntaxError) {
      return emptyDashboard("invalid");
    }
    return emptyDashboard("unavailable");
  }
}
