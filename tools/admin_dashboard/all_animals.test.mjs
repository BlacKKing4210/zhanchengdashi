import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createGrantPreview, commandFromGrantPreview, enqueueGrantCommand, grantPayloadMatches } from "./lib/resource_grants.mjs";

const animalCatalog = Array.from({ length: 60 }, (_, i) => ({ card_id: `species_${i}`, name: `动物${i}` }));
const accountSnapshot = { availability: "ready", accounts: [{ user_id: "U-TEST" }, { user_id: "U-OTHER" }, { user_id: "U-THIRD" }] };
const context = { accountSnapshot, animalCatalog, actor: "qa-owner", sessionId: "isolated-test-session", secret: Buffer.alloc(32, 7) };
const body = { target: { kind: "user", user_id: "U-TEST" }, grant: { type: "all_animals", amount: 1 }, reason: "测试：全部动物各1份", idempotency_key: "11111111-1111-4111-8111-111111111111" };

test("all animals freezes the authoritative 60-species catalog in one single-account command", async (t) => {
  const preview = createGrantPreview({ ...context, body });
  assert.equal(preview.scope, "target");
  assert.equal(preview.target_count, 1);
  assert.equal(preview.grants.length, 60);
  const command = commandFromGrantPreview({ ...context, body: { preview_token: preview.preview_token, idempotency_key: body.idempotency_key } });
  assert.deepEqual(command.target_user_ids, ["U-TEST"]);
  assert.deepEqual(command.grants.map(g => g.card_id), animalCatalog.map(a => a.card_id).sort());
  assert.ok(command.grants.every(g => g.resource === "card_copies" && g.amount === 1));
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "all-animals-test-"));
  t.after(() => fs.rm(directory, { recursive: true, force: true }));
  const first = await enqueueGrantCommand(directory, command);
  const retry = await enqueueGrantCommand(directory, command);
  assert.equal(first.idempotent, false);
  assert.equal(retry.idempotent, true);
  assert.equal(retry.command.grants.length, 60);
  assert.equal((await fs.readdir(path.join(directory, "pending"))).length, 1);
  const changed = structuredClone(command);
  changed.grants[59].amount = 2;
  assert.equal(grantPayloadMatches(command, changed), false, "entries beyond old 20-item cap must participate in idempotency");
  await assert.rejects(enqueueGrantCommand(directory, changed), { code: "idempotency_conflict" });
});

test("all animals fails closed without a valid server catalog and cannot accept client expansion", () => {
  for (const invalidCatalog of [undefined, [], [{ card_id: "" }], [animalCatalog[0], animalCatalog[0]], Array.from({ length: 257 }, (_, i) => ({ card_id: `id_${i}` }))]) {
    assert.throws(() => createGrantPreview({ ...context, animalCatalog: invalidCatalog, body }), { code: "animal_catalog_unavailable" });
  }
  assert.throws(() => createGrantPreview({ ...context, body: { ...body, animalCatalog } }), { code: "invalid_grant_request" });
  assert.throws(() => createGrantPreview({ ...context, body: { ...body, grant: { type: "all_animals", amount: 2 } } }), { code: "invalid_grant_amount" });
});

test("test preset forbids selected/all scope and unknown players", () => {
  for (const target of [{ kind: "all" }, { kind: "selected", user_ids: ["U-TEST", "U-OTHER"] }]) {
    assert.throws(() => createGrantPreview({ ...context, body: { ...body, target } }), { code: "all_animals_single_target_required" });
  }
  assert.throws(() => createGrantPreview({ ...context, body: { ...body, target: { kind: "user", user_id: "U-MISSING" } } }), { code: "target_not_found" });
  const preview = createGrantPreview({ ...context, body });
  assert.throws(() => commandFromGrantPreview({ ...context, sessionId: "another-session", body: { preview_token: preview.preview_token } }), { code: "preview_session_mismatch" });
});
