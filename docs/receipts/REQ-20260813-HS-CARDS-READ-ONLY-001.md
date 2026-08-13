# REQ-20260813-HS-CARDS-001 Read-Only Receipt

- State: READY for conflict-free L1 research delivery
- Request: collect a current all-card Hearthstone reference dataset for original animal-card design adjustment
- Project RAG gate: `temp/rag/receipts/rag-gate.json` (`READY`, 13/13 golden queries, mean recall 1.0)
- Task RAG receipt: `temp/rag/receipts/tasks/REQ-20260813-HS-CARDS-001.json` (8 cited project chunks)
- Project source used: `config/tables/cards.csv` and `config/schema/config_schema.json`
- Active conflict observed: `REQ-20260813-GROUP-BUFF-UPGRADE-R2` holds `cards.csv`, runtime cards, design, active-scope, and combat-test files
- Conflict decision: this task will not edit any locked project card/config/runtime/design file
- Allowed write set: the final workbook plus this read-only receipt and its completion receipt only
- Control-plane fingerprint: `EDB81F15345FE52FACDEC66FA4E08EB560C8D87D768B3B31EC8CF79C8BC0B084`
- Source snapshot selected: HearthstoneJSON build `248348`
- External discovery: AnySearch primary; original HearthstoneJSON documentation/data and Blizzard card-library/API documentation for validation
- Raw research storage: operating-system temporary directory only; no raw third-party dump or card-art cache will be stored in the game project
- Card-face policy: every card row receives render/art source URLs; only a small representative preview may be embedded so the workbook stays usable and third-party artwork is not mixed into runtime assets
- Acceptance: all-card and collectible subsets reconcile to source counts; localized card attributes/effects are preserved; source URLs are row-visible; workbook sheets render legibly; no project runtime/config change
- Reusable method candidate: none
