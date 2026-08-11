# Project Knowledge

This directory is the mandatory source registry and retrieval-evaluation contract for the game workflow.

- Add every authoritative source to `knowledge_manifest.csv`.
- Keep stable source IDs and project-relative paths.
- Add or revise golden queries when project vocabulary, features, or ambiguity changes.
- Run `python tools/game_project_rag.py prepare --project-root <project-root>` after any active source changes.
- Generated indexes, context packs, and receipts are runtime evidence, not formal product sources.
- Never register secrets, credentials, personal data, or unapproved third-party content.
